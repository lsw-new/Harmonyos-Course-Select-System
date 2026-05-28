// 课程、课表、选课

import { BaseRepository } from './BaseRepository';
import { Course, ScheduleItem, SelectionCourse, SelectionRoundInfo, SelectionStatus } from '../models/Course';
import { Notice } from '../models/Notice';
import { mockCourses, mockSchedule, mockSelectionCourses, mockSelectionRound } from '../mock/mockCourses';
import { mockNotices } from '../mock/mockNotices';

export class CourseRepository extends BaseRepository {
  private static _instance?: CourseRepository;
  static get(): CourseRepository {
    if (!CourseRepository._instance) {
      CourseRepository._instance = new CourseRepository();
    }
    return CourseRepository._instance;
  }

  private selections: SelectionCourse[] = JSON.parse(JSON.stringify(mockSelectionCourses)) as SelectionCourse[];

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
    let items = this.selections;
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
    const target = this.selections.find((s) => s.course.id === courseId);
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
    target.status = 'selected';
    return this.delay<boolean>(true);
  }

  async dropCourse(courseId: string): Promise<boolean> {
    const target = this.selections.find((s) => s.course.id === courseId);
    if (!target) {
      return this.reject('课程不存在', 'notFound');
    }
    if (target.status !== 'selected') {
      return this.reject('该课程未被选中');
    }
    target.status = 'available' as SelectionStatus;
    return this.delay<boolean>(true);
  }

  async getMySelectedCourses(): Promise<SelectionCourse[]> {
    const items = this.selections.filter((s) => s.status === 'selected');
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
