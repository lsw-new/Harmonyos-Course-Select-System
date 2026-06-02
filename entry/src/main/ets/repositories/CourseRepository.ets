// 课程、课表、选课

import { BaseRepository } from './BaseRepository';
import { Course, ScheduleItem, SelectionCourse, SelectionRoundInfo } from '../models/Course';
import { AdminCourseItem, AdminCourseCategory, AdminCourseStatus } from '../models/Admin';
import { Notice } from '../models/Notice';
import { mockCourses, mockSchedule } from '../mock/mockCourses';
import { mockNotices } from '../mock/mockNotices';
import { LocalDataStore } from '../common/storage/LocalDataStore';
import { AppDatabase } from '../common/storage/AppDatabase';
import { SessionStorage } from '../common/storage/SessionStorage';
import { NoticeStore } from '../common/services/NoticeStore';
import { SelectionAdminRepository } from './SelectionAdminRepository';
import { AdminRepository } from './AdminRepository';
import { AppConfig } from '../app/AppConfig';
import { RemoteApi, RemoteCourse, RemoteNotice } from '../common/remote/RemoteApi';

const CREDIT_LIMIT: number = 28; // 学分上限：选课事务据此校验，超出则拒绝
const KEY_SELECTED_IDS = 'local.selectedCourseIds.v1';
const KEY_IMPORTED_SCHEDULE = 'local.importedSchedule.v1';
const CONTROL_CHAR_PATTERN: RegExp = new RegExp('[\\u0000-\\u001f\\u007f]');

export class CourseRepository extends BaseRepository {
  private static _instance?: CourseRepository;
  static get(): CourseRepository {
    if (!CourseRepository._instance) {
      CourseRepository._instance = new CourseRepository();
    }
    return CourseRepository._instance;
  }

  // 学生已选课程的 id 集合（管理端课程 id）。课程主数据全部来自管理端目录。
  private memberIds: string[] = [];
  private isMemberLoaded: boolean = false;
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

  // ============ 已选成员关系（仅存 id，课程主数据以管理端为准） ============

  // RDB 就绪且已登录学生时，成员关系走 selections 表（按 studentId）；否则回退 Preferences 全局集合。
  private useRdbSelections(): boolean {
    return AppDatabase.isReady() && this.currentStudentId().length > 0;
  }

  private currentStudentId(): string {
    const student = SessionStorage.get().getStudent();
    return student ? student.studentId : '';
  }

  // ============ Track B 远程数据源（AppConfig.useRemote=true 且已登录时启用，读失败回退本地） ============

  private useRemote(): boolean {
    return AppConfig.useRemote && this.currentStudentId().length > 0;
  }

  private remoteToAdminCourse(r: RemoteCourse): AdminCourseItem {
    const item: AdminCourseItem = {
      id: r.id,
      code: r.code,
      name: r.name,
      teacher: r.teacher,
      category: r.category as AdminCourseCategory,
      credit: r.credit,
      timeText: r.timeText,
      capacity: r.capacity,
      selectedCount: r.selectedCount,
      status: r.status as AdminCourseStatus
    };
    return item;
  }

  private async remoteSelectionCourses(query?: string, category?: string): Promise<SelectionCourse[]> {
    const openRemote = await RemoteApi.listOpenCourses();
    const mineRemote = await RemoteApi.mySelections(this.currentStudentId());
    const mineIds: string[] = mineRemote.map((c) => c.id);
    const base: SelectionCourse[] = openRemote.map((r) => {
      const course = this.toStudentCourse(this.remoteToAdminCourse(r));
      const isSelected = mineIds.indexOf(course.id) >= 0;
      const sc: SelectionCourse = { course: course, status: isSelected ? 'selected' : 'available', conflictWith: undefined };
      return sc;
    });
    let items = this.decorateStatuses(base);
    if (query && query.length > 0) {
      const q = query.toLowerCase();
      items = items.filter((s) =>
        s.course.name.toLowerCase().includes(q) ||
        s.course.teacher.toLowerCase().includes(q) ||
        s.course.code.toLowerCase().includes(q));
    }
    if (category && category !== '全部') {
      items = items.filter((s) => s.course.category === category);
    }
    return this.delayCopy<SelectionCourse[]>(items);
  }

  private async remoteSelectionRound(): Promise<SelectionRoundInfo> {
    const round = await RemoteApi.activeRound();
    const mineRemote = await RemoteApi.mySelections(this.currentStudentId());
    let selectedCredits = 0;
    mineRemote.forEach((c) => { selectedCredits += c.credit; });
    if (!round) {
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
      roundName: round.name,
      startTime: round.startTime,
      endTime: round.endTime,
      remainingSeconds: this.computeRemainingSeconds(round.endTime),
      selectedCredits: selectedCredits,
      creditLimit: round.creditLimit,
      inProgress: true
    };
    return this.delayCopy<SelectionRoundInfo>(info);
  }

  private async getMemberIds(): Promise<string[]> {
    if (this.useRdbSelections()) {
      return this.loadMemberIdsFromRdb();
    }
    if (!this.isMemberLoaded) {
      const stored = await LocalDataStore.loadArray<string>(KEY_SELECTED_IDS, []);
      this.memberIds = stored.filter((id) => typeof id === 'string' && id.length > 0);
      this.isMemberLoaded = true;
    }
    return this.memberIds;
  }

  private async saveMemberIds(ids: string[]): Promise<void> {
    this.memberIds = ids;
    this.isMemberLoaded = true;
    await LocalDataStore.saveArray<string>(KEY_SELECTED_IDS, ids);
  }

  private async loadMemberIdsFromRdb(): Promise<string[]> {
    const resultSet = await AppDatabase.query(
      `SELECT course_id FROM selections WHERE student_id = ${AppDatabase.sqlText(this.currentStudentId())}`
    );
    const ids: string[] = [];
    try {
      const idx = resultSet.getColumnIndex('course_id');
      while (resultSet.goToNextRow()) {
        ids.push(resultSet.getString(idx));
      }
    } finally {
      resultSet.close();
    }
    return ids;
  }

  // 确保学生档案行存在（selections.student_id 外键），INSERT OR IGNORE 避免删除既有被引用行。
  private async ensureStudentProfile(): Promise<void> {
    const student = SessionStorage.get().getStudent();
    if (!student) {
      return;
    }
    await AppDatabase.execute(
      `INSERT OR IGNORE INTO student_profiles (student_id, name, college, major, class_name, grade, status, created_at, updated_at)
       VALUES (${AppDatabase.sqlText(student.studentId)}, ${AppDatabase.sqlText(student.name)}, ${AppDatabase.sqlText(student.college)}, ${AppDatabase.sqlText(student.major)}, ${AppDatabase.sqlText(student.className)}, ${AppDatabase.sqlText(student.grade)}, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)`
    );
  }

  // 选课：RDB 模式插入 selections 行（round_id 置 NULL 规避轮次外键）；否则写 Preferences 集合。
  private async addMember(courseId: string): Promise<void> {
    if (this.useRdbSelections()) {
      await this.ensureStudentProfile();
      const sid = this.currentStudentId();
      await AppDatabase.execute(
        `INSERT OR IGNORE INTO selections (id, student_id, course_id, round_id, status, created_at)
         VALUES (${AppDatabase.sqlText('sel-' + sid + '-' + courseId)}, ${AppDatabase.sqlText(sid)}, ${AppDatabase.sqlText(courseId)}, NULL, 'selected', CURRENT_TIMESTAMP)`
      );
      return;
    }
    const ids = await this.getMemberIds();
    await this.saveMemberIds([courseId].concat(ids));
  }

  // 退课：RDB 模式删除 selections 行；否则从 Preferences 集合移除。
  private async removeMember(courseId: string): Promise<void> {
    if (this.useRdbSelections()) {
      await AppDatabase.execute(
        `DELETE FROM selections WHERE student_id = ${AppDatabase.sqlText(this.currentStudentId())} AND course_id = ${AppDatabase.sqlText(courseId)}`
      );
      return;
    }
    const ids = await this.getMemberIds();
    await this.saveMemberIds(ids.filter((id) => id !== courseId));
  }

  // ============ 管理端课程目录 → 学生课程映射（单一事实来源） ============

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

  private weekdayFromCn(c: string): number {
    switch (c) {
      case '一': return 1;
      case '二': return 2;
      case '三': return 3;
      case '四': return 4;
      case '五': return 5;
      case '六': return 6;
      case '日': return 7;
      case '天': return 7;
      default: return 0;
    }
  }

  // 解析 "周一 1-2 节" → [weekday, periodStart, periodEnd]；无法解析返回 []
  private parseTimeText(timeText: string): number[] {
    const m: RegExpExecArray | null = /周(.)\s*(\d+)\s*-\s*(\d+)\s*节/.exec(timeText);
    if (m === null) {
      return [];
    }
    const wd = this.weekdayFromCn(m[1]);
    if (wd === 0) {
      return [];
    }
    return [wd, parseInt(m[2], 10), parseInt(m[3], 10)];
  }

  // 管理端课程 → 学生课程：排课结构字段优先取同 code 的内置课程，其次解析 timeText
  private toStudentCourse(a: AdminCourseItem): Course {
    const code = a.code.trim().toLowerCase();
    const rich = mockCourses.find((m) => m.code.trim().toLowerCase() === code);
    const parsed = this.parseTimeText(a.timeText);
    const hasParsed = parsed.length === 3;
    const weekday = hasParsed ? parsed[0] : (rich ? rich.weekday : 0);
    const periodStart = hasParsed ? parsed[1] : (rich ? rich.periodStart : 0);
    const periodEnd = hasParsed ? parsed[2] : (rich ? rich.periodEnd : 0);
    const course: Course = {
      id: a.id,
      code: a.code,
      teachingClassNo: rich ? rich.teachingClassNo : '—',
      name: a.name,
      category: this.mapCategory(a.category),
      credit: a.credit,
      teacher: a.teacher,
      college: rich ? rich.college : '—',
      campus: rich ? rich.campus : undefined,
      classroom: rich ? rich.classroom : (a.timeText.trim().length > 0 ? a.timeText.trim() : '待定'),
      weeks: rich ? rich.weeks : (weekday > 0 ? '1-16 周' : '—'),
      periodStart: periodStart,
      periodEnd: periodEnd,
      weekday: weekday,
      capacity: a.capacity,
      selectedCount: a.selectedCount,
      description: rich ? rich.description : undefined,
      assessment: rich ? rich.assessment : undefined
    };
    return course;
  }

  // 学生可选目录：管理端 status='open' 的课程
  private async getOpenCatalog(): Promise<Course[]> {
    const adminCourses = await AdminRepository.get().getCourses();
    const open: Course[] = [];
    for (let i = 0; i < adminCourses.length; i++) {
      if (adminCourses[i].status === 'open') {
        open.push(this.toStudentCourse(adminCourses[i]));
      }
    }
    return open;
  }

  // 完整目录（含已关闭）：用于「我的已选」与课程详情
  private async getFullCatalog(): Promise<Course[]> {
    const adminCourses = await AdminRepository.get().getCourses();
    return adminCourses.map((a) => this.toStudentCourse(a));
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
    // 课程详情以管理端目录为单一事实来源
    const catalog = await this.getFullCatalog();
    const found = catalog.find((c) => c.id === courseId);
    if (found) {
      return this.delayCopy<Course>(found);
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
    if (this.useRemote()) {
      try {
        return await this.remoteSelectionRound();
      } catch (e) {
        // 远程失败回退本地
      }
    }
    const active = await SelectionAdminRepository.get().getActiveRound();
    const catalog = await this.getFullCatalog();
    const memberIds = await this.getMemberIds();
    let selectedCredits = 0;
    for (let i = 0; i < catalog.length; i++) {
      if (memberIds.indexOf(catalog[i].id) >= 0) {
        selectedCredits += catalog[i].credit;
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
    if (this.useRemote()) {
      try {
        return await this.remoteSelectionCourses(query, category);
      } catch (e) {
        // 远程失败回退本地
      }
    }
    const catalog = await this.getOpenCatalog();
    const memberIds = await this.getMemberIds();
    const base: SelectionCourse[] = catalog.map((c) => {
      const isSelected = memberIds.indexOf(c.id) >= 0;
      const sc: SelectionCourse = { course: c, status: isSelected ? 'selected' : 'available', conflictWith: undefined };
      return sc;
    });
    let items = this.decorateStatuses(base);
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
    if (this.useRemote()) {
      try {
        await RemoteApi.select(this.currentStudentId(), courseId);
        return this.delay<boolean>(true);
      } catch (e) {
        return this.reject((e instanceof Error) ? e.message : String(e));
      }
    }
    // 轮次门禁：管理端无进行中轮次时不能选课
    const active = await SelectionAdminRepository.get().getActiveRound();
    if (!active) {
      return this.reject('当前不在选课时间，暂不能选课');
    }
    const catalog = await this.getOpenCatalog();
    const target = catalog.find((c) => c.id === courseId);
    if (!target) {
      return this.reject('课程不存在或未开放选课', 'notFound');
    }
    const memberIds = await this.getMemberIds();
    if (memberIds.indexOf(courseId) >= 0) {
      return this.reject('已选该课程');
    }
    const cap = target.capacity;
    const cnt = target.selectedCount;
    if (cap !== undefined && cnt !== undefined && cnt >= cap) {
      return this.reject('课程容量已满');
    }
    // 学分上限与时间冲突：基于当前已选课程
    const selected: Course[] = [];
    let selectedCredits = 0;
    for (let i = 0; i < catalog.length; i++) {
      if (memberIds.indexOf(catalog[i].id) >= 0) {
        selected.push(catalog[i]);
        selectedCredits += catalog[i].credit;
      }
    }
    if (selectedCredits + target.credit > CREDIT_LIMIT) {
      return this.reject(`超过学分上限（${CREDIT_LIMIT} 学分）`);
    }
    for (let i = 0; i < selected.length; i++) {
      if (this.coursesConflict(target, selected[i])) {
        return this.reject(`与「${selected[i].name}」时间冲突`);
      }
    }
    await this.addMember(courseId);
    // 选课人数回写管理端单一事实来源
    await AdminRepository.get().adjustEnrollment(target.code, 1);
    return this.delay<boolean>(true);
  }

  async dropCourse(courseId: string): Promise<boolean> {
    if (this.useRemote()) {
      try {
        await RemoteApi.drop(this.currentStudentId(), courseId);
        return this.delay<boolean>(true);
      } catch (e) {
        return this.reject((e instanceof Error) ? e.message : String(e));
      }
    }
    const memberIds = await this.getMemberIds();
    if (memberIds.indexOf(courseId) < 0) {
      return this.reject('该课程未被选中');
    }
    await this.removeMember(courseId);
    // 退课：名额回退到管理端单一事实来源
    const catalog = await this.getFullCatalog();
    const target = catalog.find((c) => c.id === courseId);
    if (target) {
      await AdminRepository.get().adjustEnrollment(target.code, -1);
    }
    return this.delay<boolean>(true);
  }

  async getMySelectedCourses(): Promise<SelectionCourse[]> {
    if (this.useRemote()) {
      try {
        const mineRemote = await RemoteApi.mySelections(this.currentStudentId());
        const remoteItems: SelectionCourse[] = mineRemote.map((r) => {
          const sc: SelectionCourse = { course: this.toStudentCourse(this.remoteToAdminCourse(r)), status: 'selected', conflictWith: undefined };
          return sc;
        });
        return this.delayCopy<SelectionCourse[]>(remoteItems);
      } catch (e) {
        // 远程失败回退本地
      }
    }
    const catalog = await this.getFullCatalog();
    const memberIds = await this.getMemberIds();
    const items: SelectionCourse[] = [];
    for (let i = 0; i < catalog.length; i++) {
      if (memberIds.indexOf(catalog[i].id) >= 0) {
        const sc: SelectionCourse = { course: catalog[i], status: 'selected', conflictWith: undefined };
        items.push(sc);
      }
    }
    return this.delayCopy<SelectionCourse[]>(items);
  }

  // 通知
  private remoteToNotice(n: RemoteNotice): Notice {
    const item: Notice = {
      id: n.id,
      title: n.title,
      publisher: n.publisher,
      publishedAt: n.publishedAt,
      summary: n.summary,
      content: n.content,
      isRead: n.isRead,
      category: n.category,
      attachments: []
    };
    return item;
  }

  async getNotices(category?: string): Promise<Notice[]> {
    if (this.useRemote()) {
      try {
        const remote = await RemoteApi.listNotices(this.currentStudentId(), category);
        const remoteItems: Notice[] = remote.map((n) => this.remoteToNotice(n));
        return this.delayCopy<Notice[]>(remoteItems);
      } catch (e) {
        // 远程失败回退本地
      }
    }
    let items = await NoticeStore.list(mockNotices, category);
    if (category && category !== '全部') {
      items = items.filter((n) => n.category === category);
    }
    return this.delayCopy<Notice[]>(items);
  }

  async getNoticeDetail(id: string): Promise<Notice> {
    if (this.useRemote()) {
      try {
        const remote = await RemoteApi.noticeDetail(this.currentStudentId(), id);
        return this.delayCopy<Notice>(this.remoteToNotice(remote));
      } catch (e) {
        // 远程失败回退本地
      }
    }
    const item = await NoticeStore.detail(mockNotices, id);
    if (!item) {
      return this.reject('通知不存在', 'notFound');
    }
    return this.delayCopy<Notice>(item);
  }

  async markNoticeRead(id: string): Promise<boolean> {
    if (this.useRemote()) {
      try {
        await RemoteApi.markNoticeRead(this.currentStudentId(), id);
        return this.delay<boolean>(true);
      } catch (e) {
        return this.reject((e instanceof Error) ? e.message : String(e));
      }
    }
    await NoticeStore.markRead(id);
    return this.delay<boolean>(true);
  }
}
