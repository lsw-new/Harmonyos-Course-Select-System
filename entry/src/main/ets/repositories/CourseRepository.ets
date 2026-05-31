// 课程、课表、选课

import { BaseRepository } from './BaseRepository';
import { Course, ScheduleItem, SelectionCourse, SelectionRoundInfo, SelectionStatus } from '../models/Course';
import { Notice } from '../models/Notice';
import { mockCourses, mockSchedule, mockSelectionCourses, mockSelectionRound } from '../mock/mockCourses';
import { mockNotices } from '../mock/mockNotices';
import { LocalDataStore } from '../common/storage/LocalDataStore';
import { NoticeStore } from '../common/services/NoticeStore';

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

  private async getSelections(): Promise<SelectionCourse[]> {
    if (!this.isSelectionLoaded) {
      const stored = await LocalDataStore.loadArray<SelectionCourse>(KEY_SELECTION_COURSES, mockSelectionCourses);
      const sanitized = this.sanitizeSelections(stored);
      this.selections = sanitized.length > 0 ? sanitized : JSON.parse(JSON.stringify(mockSelectionCourses)) as SelectionCourse[];
      this.isSelectionLoaded = true;
    }
    return this.selections;
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
      return this.delayCopy<Course>(course);
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

  async getSelectionRound(): Promise<SelectionRoundInfo> {
    return this.delayCopy<SelectionRoundInfo>(mockSelectionRound);
  }

  async getSelectionCourses(query?: string, category?: string): Promise<SelectionCourse[]> {
    let items = await this.getSelections();
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
    const selections = await this.getSelections();
    const target = selections.find((s) => s.course.id === courseId);
    if (!target) {
      return this.reject('课程不存在', 'notFound');
    }
    if (target.status === 'full') {
      return this.reject('课程容量已满');
    }
    if (target.status === 'conflict') {
      return this.reject(`时间冲突：${target.conflictWith ?? ''}`);
    }
    if (target.status === 'selected') {
      return this.reject('已选课程');
    }
    const next = selections.map((item) => {
      if (item.course.id !== courseId) {
        return item;
      }
      const updated: SelectionCourse = {
        course: item.course,
        status: 'selected',
        conflictWith: item.conflictWith
      };
      return updated;
    });
    await this.saveSelections(next);
    return this.delay<boolean>(true);
  }

  async dropCourse(courseId: string): Promise<boolean> {
    const selections = await this.getSelections();
    const target = selections.find((s) => s.course.id === courseId);
    if (!target) {
      return this.reject('课程不存在', 'notFound');
    }
    if (target.status !== 'selected') {
      return this.reject('该课程未被选中');
    }
    const next = selections.map((item) => {
      if (item.course.id !== courseId) {
        return item;
      }
      const updated: SelectionCourse = {
        course: item.course,
        status: 'available' as SelectionStatus,
        conflictWith: item.conflictWith
      };
      return updated;
    });
    await this.saveSelections(next);
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
