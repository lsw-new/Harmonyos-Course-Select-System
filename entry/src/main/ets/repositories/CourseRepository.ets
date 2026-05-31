// 课程、课表、选课

import { BaseRepository } from './BaseRepository';
import { Course, ScheduleItem, SelectionCourse, SelectionRoundInfo, SelectionStatus } from '../models/Course';
import { AdminCourseItem } from '../models/Admin';
import { Notice } from '../models/Notice';
import { mockCourses, mockSchedule, mockSelectionCourses } from '../mock/mockCourses';
import { mockNotices } from '../mock/mockNotices';
import { LocalDataStore } from '../common/storage/LocalDataStore';
import { NoticeStore } from '../common/services/NoticeStore';
import { SelectionAdminRepository } from './SelectionAdminRepository';
import { AdminRepository } from './AdminRepository';

const CREDIT_LIMIT: number = 28; // 学分上限：选课事务据此校验，超出则拒绝
const KEY_SELECTION_COURSES = 'local.selectionCourses.v1';
const KEY_IMPORTED_SCHEDULE = 'local.importedSchedule.v1';
const SELECTION_STATUSES: string[] = ['available', 'selected', 'full', 'conflict'];
const CONTROL_CHAR_PATTERN: RegExp = /[\r\n\u0000-\u001f\u007f]/;

export class CourseRepository extends BaseRepository {
  private static _instance?: CourseRepository;
  static get(): CourseRepository {
    if (!CourseRepository._instance) {
      CourseRepository._instance = new CourseRepository();
    }
    return CourseRepository._instance;
  }

  private selections: SelectionCourse[] = JSON.parse(JSON.stringify(mockSelectionCourses)) as SelectionCourse[];
  private isSelectionLoaded: boolean = false;
  // 导入课表：非空时覆盖 mockSchedule，作为 Schedule/Home/Today 的数据源。
  private importedSchedule: ScheduleItem[] = [];
  private isImportedLoaded: boolean = false;

  private isFiniteNumber(value: number): boolean {
    return typeof value === 'number' && value === value && value !== Infinity && value !== -Infinity;
  }

  private isCleanText(value: string, min: number, max: number): boolean {
    if (typeof value !== 'string') {
      return false;
    }
    const text = value.trim();
    return text.length >= min && text.length <= max && !CONTROL_CHAR_PATTERN.test(text);
  }

  private isAllowedSelectionStatus(value: string): boolean {
    return SELECTION_STATUSES.indexOf(value) >= 0;
  }

  private isValidStoredCourse(course: Course): boolean {
    if (!course || typeof course !== 'object') {
      return false;
    }
    if (!this.isCleanText(course.id, 1, 64) || !this.isCleanText(course.code, 1, 32) || !this.isCleanText(course.name, 1, 80)) {
      return false;
    }
    if (!this.isCleanText(course.teacher, 1, 32) || !this.isCleanText(course.college, 1, 80) || !this.isCleanText(course.classroom, 1, 80)) {
      return false;
    }
    if (!this.isCleanText(course.category, 1, 32) || !this.isCleanText(course.teachingClassNo, 1, 64) || !this.isCleanText(course.weeks, 1, 80)) {
      return false;
    }
    if (!this.isFiniteNumber(course.credit) || course.credit <= 0 || course.credit > 30) {
      return false;
    }
    if (!this.isFiniteNumber(course.periodStart) || !this.isFiniteNumber(course.periodEnd) || !this.isFiniteNumber(course.weekday)) {
      return false;
    }
    if (Math.floor(course.periodStart) !== course.periodStart || Math.floor(course.periodEnd) !== course.periodEnd || Math.floor(course.weekday) !== course.weekday) {
      return false;
    }
    if (course.periodStart < 1 || course.periodEnd < course.periodStart || course.periodEnd > 12 || course.weekday < 1 || course.weekday > 7) {
      return false;
    }
    if (course.capacity !== undefined && (!this.isFiniteNumber(course.capacity) || Math.floor(course.capacity) !== course.capacity || course.capacity < 0 || course.capacity > 10000)) {
      return false;
    }
    if (course.selectedCount !== undefined && (!this.isFiniteNumber(course.selectedCount) || Math.floor(course.selectedCount) !== course.selectedCount || course.selectedCount < 0)) {
      return false;
    }
    if (course.capacity !== undefined && course.selectedCount !== undefined && course.selectedCount > course.capacity) {
      return false;
    }
    return true;
  }

  private sanitizeSelections(items: SelectionCourse[]): SelectionCourse[] {
    const ids: string[] = [];
    const sanitized: SelectionCourse[] = [];
    items.forEach((item) => {
      if (!item || typeof item !== 'object' || !this.isValidStoredCourse(item.course) || !this.isAllowedSelectionStatus(item.status)) {
        return;
      }
      const id = item.course.id.trim();
      if (ids.indexOf(id) >= 0) {
        return;
      }
      ids.push(id);
      const course: Course = {
        id,
        code: item.course.code.trim(),
        teachingClassNo: item.course.teachingClassNo.trim(),
        name: item.course.name.trim(),
        category: item.course.category.trim(),
        credit: item.course.credit,
        teacher: item.course.teacher.trim(),
        college: item.course.college.trim(),
        campus: item.course.campus,
        classroom: item.course.classroom.trim(),
        weeks: item.course.weeks.trim(),
        periodStart: item.course.periodStart,
        periodEnd: item.course.periodEnd,
        weekday: item.course.weekday,
        capacity: item.course.capacity,
        selectedCount: item.course.selectedCount,
        description: item.course.description,
        assessment: item.course.assessment
      };
      const selection: SelectionCourse = {
        course,
        status: item.status as SelectionStatus,
        conflictWith: item.conflictWith
      };
      sanitized.push(selection);
    });
    return sanitized;
  }

  // 学生本地选课记录（成员关系 + 课表结构字段），仅作底座，课程属性以管理端为准
  private async loadSelections(): Promise<SelectionCourse[]> {
    if (!this.isSelectionLoaded) {
      const stored = await LocalDataStore.loadArray<SelectionCourse>(KEY_SELECTION_COURSES, mockSelectionCourses);
      const sanitized = this.sanitizeSelections(stored);
      this.selections = sanitized.length > 0 ? sanitized : JSON.parse(JSON.stringify(mockSelectionCourses)) as SelectionCourse[];
      this.isSelectionLoaded = true;
    }
    return this.selections;
  }

  // 选课读取：以管理端课程为单一事实来源，按课程代码叠加 名称/教师/学分/容量/已选/类型
  private async getSelections(): Promise<SelectionCourse[]> {
    const base = await this.loadSelections();
    const adminCourses = await AdminRepository.get().getCourses();
    return this.overlayAdmin(base, adminCourses);
  }

  private mapCategory(category: string): string {
    if (category === 'required') {
      return '必修';
    }
    if (category === 'elective') {
      return '选修';
    }
    if (category === 'public') {
      return '公选';
    }
    if (category === 'practice') {
      return '实践';
    }
    return category;
  }

  private overlayAdmin(base: SelectionCourse[], adminCourses: AdminCourseItem[]): SelectionCourse[] {
    return base.map((item) => {
      const code = item.course.code.trim().toLowerCase();
      const admin = adminCourses.find((ac) => ac.code.trim().toLowerCase() === code);
      if (!admin) {
        return item;
      }
      const merged: Course = {
        id: item.course.id,
        code: item.course.code,
        teachingClassNo: item.course.teachingClassNo,
        name: admin.name,
        category: this.mapCategory(admin.category),
        credit: admin.credit,
        teacher: admin.teacher,
        college: item.course.college,
        campus: item.course.campus,
        classroom: item.course.classroom,
        weeks: item.course.weeks,
        periodStart: item.course.periodStart,
        periodEnd: item.course.periodEnd,
        weekday: item.course.weekday,
        capacity: admin.capacity,
        selectedCount: admin.selectedCount,
        description: item.course.description,
        assessment: item.course.assessment
      };
      const overlaid: SelectionCourse = { course: merged, status: item.status, conflictWith: item.conflictWith };
      return overlaid;
    });
  }

  private async saveSelections(next: SelectionCourse[]): Promise<void> {
    const sanitized = this.sanitizeSelections(next);
    this.selections = sanitized;
    this.isSelectionLoaded = true;
    await LocalDataStore.saveArray<SelectionCourse>(KEY_SELECTION_COURSES, sanitized);
  }

  private isValidScheduleItem(s: ScheduleItem): boolean {
    if (!s || typeof s !== 'object') {
      return false;
    }
    if (!this.isCleanText(s.id, 1, 64) || !this.isCleanText(s.courseName, 1, 80) || !this.isCleanText(s.teacher, 1, 40)) {
      return false;
    }
    if (!this.isFiniteNumber(s.weekday) || s.weekday < 1 || s.weekday > 7) {
      return false;
    }
    if (!this.isFiniteNumber(s.periodStart) || !this.isFiniteNumber(s.periodEnd)) {
      return false;
    }
    if (Math.floor(s.periodStart) !== s.periodStart || Math.floor(s.periodEnd) !== s.periodEnd) {
      return false;
    }
    if (s.periodStart < 1 || s.periodEnd < s.periodStart || s.periodEnd > 12) {
      return false;
    }
    if (!Array.isArray(s.weeks) || s.weeks.length === 0) {
      return false;
    }
    return true;
  }

  // 当前生效课表：有导入课表则用导入，否则回退到内置 mockSchedule。
  private async getActiveSchedule(): Promise<ScheduleItem[]> {
    if (!this.isImportedLoaded) {
      const stored = await LocalDataStore.loadArray<ScheduleItem>(KEY_IMPORTED_SCHEDULE, []);
      this.importedSchedule = stored.filter((s) => this.isValidScheduleItem(s));
      this.isImportedLoaded = true;
    }
    return this.importedSchedule.length > 0 ? this.importedSchedule : mockSchedule;
  }

  async saveImportedSchedule(items: ScheduleItem[]): Promise<number> {
    const valid = items.filter((s) => this.isValidScheduleItem(s));
    this.importedSchedule = valid;
    this.isImportedLoaded = true;
    await LocalDataStore.saveArray<ScheduleItem>(KEY_IMPORTED_SCHEDULE, valid);
    return valid.length;
  }

  async clearImportedSchedule(): Promise<void> {
    this.importedSchedule = [];
    this.isImportedLoaded = true;
    await LocalDataStore.saveArray<ScheduleItem>(KEY_IMPORTED_SCHEDULE, []);
  }

  async hasImportedSchedule(): Promise<boolean> {
    await this.getActiveSchedule();
    return this.importedSchedule.length > 0;
  }

  async getSchedule(term?: string, week?: number): Promise<ScheduleItem[]> {
    let items = await this.getActiveSchedule();
    if (term) {
      items = items.filter((s) => s.term === term);
    }
    if (week) {
      items = items.filter((s) => s.weeks.indexOf(week) >= 0);
    }
    return this.delayCopy<ScheduleItem[]>(items);
  }

  async getTodayCourses(weekday: number): Promise<ScheduleItem[]> {
    const all = await this.getActiveSchedule();
    const items = all.filter((s) => s.weekday === weekday);
    return this.delayCopy<ScheduleItem[]>(items);
  }

  async getCourseDetail(courseId: string): Promise<Course> {
    const course = mockCourses.find((c) => c.id === courseId);
    if (course) {
      // 详情同样以管理端课程为准（名称/教师/学分/容量/已选）
      const wrapped: SelectionCourse = { course: course, status: 'available', conflictWith: undefined };
      const adminCourses = await AdminRepository.get().getCourses();
      const overlaid = this.overlayAdmin([wrapped], adminCourses);
      return this.delayCopy<Course>(overlaid[0].course);
    }
    // 导入课表的课程没有独立课程库记录：用课表行兜底构造详情（仅含课表中的真实字段）。
    const schedule = await this.getActiveSchedule();
    const matches = schedule.filter((s) => s.courseId === courseId);
    if (matches.length > 0) {
      const first = matches[0];
      const weekTexts = matches.map((s: ScheduleItem) => s.weekText);
      const derived: Course = {
        id: courseId,
        code: courseId,
        teachingClassNo: '—',
        name: first.courseName,
        category: first.courseType,
        credit: 0,
        teacher: first.teacher,
        college: first.campus ?? '—',
        campus: first.campus,
        classroom: first.classroom,
        weeks: weekTexts.join(' / '),
        periodStart: first.periodStart,
        periodEnd: first.periodEnd,
        weekday: first.weekday,
        description: `本课程信息来自导入课表（${first.term}）。上课时间：周${first.weekday} 第 ${first.periodStart}-${first.periodEnd} 节。`
      };
      return this.delayCopy<Course>(derived);
    }
    return this.reject('课程不存在', 'notFound');
  }

  // ============ 选课事务（轮次 / 容量 / 学分 / 冲突 校验） ============

  // 解析课程周次文本（形如 "1-16 周" / "2-15 周" / "1,3,5 周"）为周次数组
  private parseCourseWeeks(weeksStr: string): number[] {
    const out: number[] = [];
    const cleaned = weeksStr.replace(/[^0-9,\-]/g, '');
    const tokens = cleaned.split(',');
    for (let t = 0; t < tokens.length; t++) {
      const tok = tokens[t];
      if (tok.length === 0) {
        continue;
      }
      const dash = tok.indexOf('-');
      if (dash > 0) {
        const a = parseInt(tok.substring(0, dash), 10);
        const b = parseInt(tok.substring(dash + 1), 10);
        if (!Number.isNaN(a) && !Number.isNaN(b)) {
          for (let w = a; w <= b; w++) {
            if (out.indexOf(w) < 0) {
              out.push(w);
            }
          }
        }
      } else {
        const w = parseInt(tok, 10);
        if (!Number.isNaN(w) && out.indexOf(w) < 0) {
          out.push(w);
        }
      }
    }
    return out;
  }

  // 两门课是否时间冲突：同一星期、节次区间重叠、且周次有交集
  private coursesConflict(a: Course, b: Course): boolean {
    if (a.weekday < 1 || b.weekday < 1) {
      return false; // 未排课（如集中实践）不参与冲突判定
    }
    if (a.weekday !== b.weekday) {
      return false;
    }
    if (a.periodStart > b.periodEnd || b.periodStart > a.periodEnd) {
      return false;
    }
    const wa = this.parseCourseWeeks(a.weeks);
    const wb = this.parseCourseWeeks(b.weeks);
    for (let i = 0; i < wa.length; i++) {
      if (wb.indexOf(wa[i]) >= 0) {
        return true;
      }
    }
    return false;
  }

  // 展示态：已选保持 selected；其余按容量/冲突派生 full / conflict / available
  private decorateStatuses(selections: SelectionCourse[]): SelectionCourse[] {
    const selected = selections.filter((s) => s.status === 'selected');
    return selections.map((item) => {
      if (item.status === 'selected') {
        const sel: SelectionCourse = { course: item.course, status: 'selected', conflictWith: undefined };
        return sel;
      }
      const cap = item.course.capacity;
      const cnt = item.course.selectedCount;
      if (cap !== undefined && cnt !== undefined && cnt >= cap) {
        const full: SelectionCourse = { course: item.course, status: 'full', conflictWith: undefined };
        return full;
      }
      let conflictName: string = '';
      for (let i = 0; i < selected.length; i++) {
        if (this.coursesConflict(item.course, selected[i].course)) {
          conflictName = selected[i].course.name;
          break;
        }
      }
      if (conflictName.length > 0) {
        const conf: SelectionCourse = { course: item.course, status: 'conflict', conflictWith: `与「${conflictName}」时间冲突` };
        return conf;
      }
      const avail: SelectionCourse = { course: item.course, status: 'available', conflictWith: undefined };
      return avail;
    });
  }

  private computeRemainingSeconds(endTime: string): number {
    const end = Date.parse(endTime.replace(' ', 'T'));
    if (Number.isNaN(end)) {
      return 0;
    }
    const diff = Math.floor((end - Date.now()) / 1000);
    return diff > 0 ? diff : 0;
  }

  // 选课轮次：与管理端「进行中」轮次共享同一事实来源
  async getSelectionRound(): Promise<SelectionRoundInfo> {
    const active = await SelectionAdminRepository.get().getActiveRound();
    const selections = await this.getSelections();
    let selectedCredits = 0;
    for (let i = 0; i < selections.length; i++) {
      if (selections[i].status === 'selected') {
        selectedCredits += selections[i].course.credit;
      }
    }
    if (!active) {
      const closed: SelectionRoundInfo = {
        roundName: '当前无进行中的选课轮次',
        startTime: '—',
        endTime: '—',
        remainingSeconds: 0,
        selectedCredits: selectedCredits,
        creditLimit: CREDIT_LIMIT,
        inProgress: false
      };
      return this.delayCopy<SelectionRoundInfo>(closed);
    }
    const info: SelectionRoundInfo = {
      roundName: active.name,
      startTime: active.startTime,
      endTime: active.endTime,
      remainingSeconds: this.computeRemainingSeconds(active.endTime),
      selectedCredits: selectedCredits,
      creditLimit: CREDIT_LIMIT,
      inProgress: true
    };
    return this.delayCopy<SelectionRoundInfo>(info);
  }

  async getSelectionCourses(query?: string, category?: string): Promise<SelectionCourse[]> {
    let items = this.decorateStatuses(await this.getSelections());
    if (query && query.length > 0) {
      const q = query.toLowerCase();
      items = items.filter((s) =>
        s.course.name.toLowerCase().includes(q) ||
        s.course.teacher.toLowerCase().includes(q) ||
        s.course.code.toLowerCase().includes(q)
      );
    }
    if (category && category !== '全部') {
      items = items.filter((s) => s.course.category === category);
    }
    return this.delayCopy<SelectionCourse[]>(items);
  }

  async selectCourse(courseId: string): Promise<boolean> {
    // 轮次门禁：管理端无进行中轮次时不能选课
    const active = await SelectionAdminRepository.get().getActiveRound();
    if (!active) {
      return this.reject('当前不在选课时间，暂不能选课');
    }
    const selections = await this.getSelections();
    const target = selections.find((s) => s.course.id === courseId);
    if (!target) {
      return this.reject('课程不存在', 'notFound');
    }
    if (target.status === 'selected') {
      return this.reject('已选该课程');
    }
    const cap = target.course.capacity;
    const cnt = target.course.selectedCount;
    if (cap !== undefined && cnt !== undefined && cnt >= cap) {
      return this.reject('课程容量已满');
    }
    // 学分上限与时间冲突：基于当前已选课程
    let selectedCredits = 0;
    const selected: SelectionCourse[] = [];
    for (let i = 0; i < selections.length; i++) {
      if (selections[i].status === 'selected') {
        selectedCredits += selections[i].course.credit;
        selected.push(selections[i]);
      }
    }
    if (selectedCredits + target.course.credit > CREDIT_LIMIT) {
      return this.reject(`超过学分上限（${CREDIT_LIMIT} 学分）`);
    }
    for (let i = 0; i < selected.length; i++) {
      if (this.coursesConflict(target.course, selected[i].course)) {
        return this.reject(`与「${selected[i].course.name}」时间冲突`);
      }
    }
    // 持久化成员关系（底座保留原始课表字段），选课人数回写管理端单一事实来源
    const base = await this.loadSelections();
    const next = base.map((item) => {
      if (item.course.id !== courseId) {
        return item;
      }
      const sel: SelectionCourse = { course: item.course, status: 'selected', conflictWith: item.conflictWith };
      return sel;
    });
    await this.saveSelections(next);
    await AdminRepository.get().adjustEnrollment(target.course.code, 1);
    return this.delay<boolean>(true);
  }

  async dropCourse(courseId: string): Promise<boolean> {
    const base = await this.loadSelections();
    const target = base.find((s) => s.course.id === courseId);
    if (!target) {
      return this.reject('课程不存在', 'notFound');
    }
    if (target.status !== 'selected') {
      return this.reject('该课程未被选中');
    }
    const next = base.map((item) => {
      if (item.course.id !== courseId) {
        return item;
      }
      const avail: SelectionCourse = { course: item.course, status: 'available', conflictWith: item.conflictWith };
      return avail;
    });
    await this.saveSelections(next);
    // 退课：名额回退到管理端单一事实来源
    await AdminRepository.get().adjustEnrollment(target.course.code, -1);
    return this.delay<boolean>(true);
  }

  async getMySelectedCourses(): Promise<SelectionCourse[]> {
    const selections = await this.getSelections();
    const items = selections.filter((s) => s.status === 'selected');
    return this.delayCopy<SelectionCourse[]>(items);
  }

  // 通知
  async getNotices(category?: string): Promise<Notice[]> {
    let items = await NoticeStore.list(mockNotices, category);
    if (category && category !== '全部') {
      items = items.filter((n) => n.category === category);
    }
    return this.delayCopy<Notice[]>(items);
  }

  async getNoticeDetail(id: string): Promise<Notice> {
    const item = await NoticeStore.detail(mockNotices, id);
    if (!item) {
      return this.reject('通知不存在', 'notFound');
    }
    return this.delayCopy<Notice>(item);
  }

  async markNoticeRead(id: string): Promise<boolean> {
    await NoticeStore.markRead(id);
    return this.delay<boolean>(true);
  }
}
