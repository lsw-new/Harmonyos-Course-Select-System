// 课程、课表、选课

import { BaseRepository } from './BaseRepository';
import { Course, ScheduleItem, SelectionCourse, SelectionRoundInfo, SelectionStatus } from '../models/Course';
import { Notice } from '../models/Notice';
import { mockCourses, mockSchedule, mockSelectionCourses, mockSelectionRound } from '../mock/mockCourses';
import { mockNotices } from '../mock/mockNotices';
import { LocalDataStore } from '../common/storage/LocalDataStore';

const KEY_SELECTION_COURSES = 'local.selectionCourses.v1';
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

  async getSchedule(term?: string, week?: number): Promise<ScheduleItem[]> {
    let items = mockSchedule;
    if (term) {
      items = items.filter((s) => s.term === term);
    }
    if (week) {
      items = items.filter((s) => s.weeks.indexOf(week) >= 0);
    }
    return this.delayCopy<ScheduleItem[]>(items);
  }

  async getTodayCourses(weekday: number): Promise<ScheduleItem[]> {
    const items = mockSchedule.filter((s) => s.weekday === weekday);
    return this.delayCopy<ScheduleItem[]>(items);
  }

  async getCourseDetail(courseId: string): Promise<Course> {
    const course = mockCourses.find((c) => c.id === courseId);
    if (!course) {
      return this.reject('课程不存在', 'notFound');
    }
    return this.delayCopy<Course>(course);
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
    let items = mockNotices;
    if (category && category !== '全部') {
      items = items.filter((n) => n.category === category);
    }
    return this.delayCopy<Notice[]>(items);
  }

  async getNoticeDetail(id: string): Promise<Notice> {
    const item = mockNotices.find((n) => n.id === id);
    if (!item) {
      return this.reject('通知不存在', 'notFound');
    }
    return this.delayCopy<Notice>(item);
  }

  async markNoticeRead(id: string): Promise<boolean> {
    const item = mockNotices.find((n) => n.id === id);
    if (item) {
      item.isRead = true;
    }
    return this.delay<boolean>(true);
  }
}
