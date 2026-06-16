// 课程域纯逻辑（无状态、不依赖会话/RDB/网络）：管理端课程↔学生课程映射、周次解析、
// 时间冲突判定、课表行校验与格式化、选课状态装饰、远程 DTO→模型映射。
// 从 CourseRepository 平移而来（行为不变），便于复用与单测；有状态的取数/持久化仍在 CourseRepository。

import { Course, ScheduleItem, SelectionCourse } from '../models/Course';
import { AdminCourseItem, AdminCourseCategory, AdminCourseStatus } from '../models/Admin';
import { Notice } from '../models/Notice';
import { mockCourses } from '../mock/mockCourses';
import { RemoteCourse, RemoteNotice, RemoteScheduleItem } from '../common/remote/RemoteApi';

const CONTROL_CHAR_PATTERN: RegExp = new RegExp('[\\u0000-\\u001f\\u007f]');

// 景德镇艺术职业大学真实上课时间表（索引 0 占位，节次 1-10）。
// 表 1：单数教学楼（香樟苑教1/3/5、上茶苑教7/9、长芗苑教11/13、芭蕉苑教15/17/19/21）+ 体育馆/田径场；
// 表 2：双数教学楼（香樟苑教2/4、上茶苑教6/8、长芗苑教10/12、芭蕉苑教14/16/18/20）。
const REAL_T1_START: string[] = ['', '08:00', '08:55', '10:25', '11:20', '14:00', '14:55', '16:25', '17:20', '19:20', '20:15'];
const REAL_T1_END: string[] = ['', '08:45', '09:40', '11:10', '12:05', '14:45', '15:40', '17:10', '18:05', '20:05', '21:00'];
const REAL_T2_START: string[] = ['', '08:20', '09:15', '10:35', '11:30', '14:20', '15:15', '16:35', '17:30', '19:20', '20:15'];
const REAL_T2_END: string[] = ['', '09:05', '10:00', '11:20', '12:15', '15:05', '16:00', '17:20', '18:15', '20:05', '21:00'];
const BUILDING_NO_PATTERN: RegExp = new RegExp('教\\s*(\\d+)\\s*栋');

export class CourseLogic {
  static isFiniteNumber(value: number): boolean {
    return typeof value === 'number' && value === value && value !== Infinity && value !== -Infinity;
  }

  static isCleanText(value: string, min: number, max: number): boolean {
    if (typeof value !== 'string') {
      return false;
    }
    const text = value.trim();
    return text.length >= min && text.length <= max && !CONTROL_CHAR_PATTERN.test(text);
  }

  static remoteToAdminCourse(r: RemoteCourse): AdminCourseItem {
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
      status: r.status as AdminCourseStatus,
      targetGrade: r.targetGrade
    };
    return item;
  }

  static mapCategory(category: string): string {
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

  static weekdayFromCn(c: string): number {
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
  static parseTimeText(timeText: string): number[] {
    const m: RegExpExecArray | null = /周(.)\s*(\d+)\s*-\s*(\d+)\s*节/.exec(timeText);
    if (m === null) {
      return [];
    }
    const wd = CourseLogic.weekdayFromCn(m[1]);
    if (wd === 0) {
      return [];
    }
    return [wd, parseInt(m[2], 10), parseInt(m[3], 10)];
  }

  // 管理端课程 → 学生课程：排课结构字段优先取同 code 的内置课程，其次解析 timeText
  static toStudentCourse(a: AdminCourseItem): Course {
    const code = a.code.trim().toLowerCase();
    const rich = mockCourses.find((m) => m.code.trim().toLowerCase() === code);
    const parsed = CourseLogic.parseTimeText(a.timeText);
    const hasParsed = parsed.length === 3;
    const weekday = hasParsed ? parsed[0] : (rich ? rich.weekday : 0);
    const periodStart = hasParsed ? parsed[1] : (rich ? rich.periodStart : 0);
    const periodEnd = hasParsed ? parsed[2] : (rich ? rich.periodEnd : 0);
    const course: Course = {
      id: a.id,
      code: a.code,
      teachingClassNo: rich ? rich.teachingClassNo : '—',
      name: a.name,
      category: CourseLogic.mapCategory(a.category),
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

  // 远程班级课表项 → 本地 ScheduleItem（type 收敛为联合类型，weeks 复制为新数组）
  static remoteToScheduleItem(r: RemoteScheduleItem): ScheduleItem {
    const item: ScheduleItem = {
      id: r.id,
      term: r.term,
      type: r.type === 'practice' ? 'practice' : 'normal',
      courseId: r.courseId,
      courseName: r.courseName,
      teacher: r.teacher,
      weekday: r.weekday,
      periodStart: r.periodStart,
      periodEnd: r.periodEnd,
      startTime: r.startTime,
      endTime: r.endTime,
      classroom: r.classroom,
      campus: r.campus,
      weeks: r.weeks.slice(),
      weekText: r.weekText,
      courseType: r.courseType
    };
    return item;
  }

  static isValidScheduleItem(s: ScheduleItem): boolean {
    if (!s || typeof s !== 'object') {
      return false;
    }
    if (!CourseLogic.isCleanText(s.id, 1, 64) || !CourseLogic.isCleanText(s.courseName, 1, 80) || !CourseLogic.isCleanText(s.teacher, 1, 40)) {
      return false;
    }
    if (!CourseLogic.isFiniteNumber(s.weekday) || s.weekday < 1 || s.weekday > 7) {
      return false;
    }
    if (!CourseLogic.isFiniteNumber(s.periodStart) || !CourseLogic.isFiniteNumber(s.periodEnd)) {
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

  // 节次 → 上课/下课时间（与导入课表口径一致；索引 0 占位，节次从 1 起）
  static sectionStartTime(section: number): string {
    const t: string[] = ['', '08:00', '08:55', '10:00', '10:55', '14:00', '14:55', '16:00', '16:55', '19:00', '19:55', '21:00', '21:55'];
    return (section >= 1 && section < t.length) ? t[section] : '';
  }

  static sectionEndTime(section: number): string {
    const t: string[] = ['', '08:45', '09:35', '10:45', '11:35', '14:45', '15:35', '16:45', '17:35', '19:45', '20:35', '21:45', '22:35'];
    return (section >= 1 && section < t.length) ? t[section] : '';
  }

  // 教室所属时间表：双数栋走表 2，单数栋/体育馆/田径场/无法识别走表 1
  static timetableOf(classroom: string): number {
    const m: RegExpExecArray | null = BUILDING_NO_PATTERN.exec(classroom);
    if (m !== null) {
      const n = parseInt(m[1], 10);
      if (!Number.isNaN(n) && n % 2 === 0) {
        return 2;
      }
    }
    return 1;
  }

  // 真实上课/下课时间（按教室栋号区分时间表）；节次超出 1-10 返回空串
  static realStartTime(period: number, classroom: string): string {
    const t = CourseLogic.timetableOf(classroom) === 2 ? REAL_T2_START : REAL_T1_START;
    return (period >= 1 && period < t.length) ? t[period] : '';
  }

  static realEndTime(period: number, classroom: string): string {
    const t = CourseLogic.timetableOf(classroom) === 2 ? REAL_T2_END : REAL_T1_END;
    return (period >= 1 && period < t.length) ? t[period] : '';
  }

  // 课表行展示时间段 "08:00-09:40"；节次不在真实时间表内时回退原始 startTime
  static lessonTimeText(s: ScheduleItem): string {
    const a = CourseLogic.realStartTime(s.periodStart, s.classroom);
    const b = CourseLogic.realEndTime(s.periodEnd, s.classroom);
    if (a.length === 0 || b.length === 0) {
      return s.startTime;
    }
    return `${a}-${b}`;
  }

  // "HH:mm" → 当日分钟数；非法返回 -1
  static minutesOf(hhmm: string): number {
    const parts = hhmm.split(':');
    if (parts.length !== 2) {
      return -1;
    }
    const h = parseInt(parts[0], 10);
    const m = parseInt(parts[1], 10);
    if (Number.isNaN(h) || Number.isNaN(m)) {
      return -1;
    }
    return h * 60 + m;
  }

  // 课程进行状态：按当前时刻（当日分钟数）判定 upcoming / ongoing / finished；
  // 时间无法解析时按 upcoming 处理（不误标灰）
  static lessonStatus(s: ScheduleItem, nowMinutes: number): string {
    const start = CourseLogic.minutesOf(CourseLogic.realStartTime(s.periodStart, s.classroom));
    const end = CourseLogic.minutesOf(CourseLogic.realEndTime(s.periodEnd, s.classroom));
    if (start < 0 || end < 0) {
      return 'upcoming';
    }
    if (nowMinutes >= end) {
      return 'finished';
    }
    if (nowMinutes >= start) {
      return 'ongoing';
    }
    return 'upcoming';
  }

  // 按真实上课时间升序排序（同一开始时间按起始节次）；返回新数组不改原数组
  static sortByLessonTime(items: ScheduleItem[]): ScheduleItem[] {
    return items.slice().sort((a: ScheduleItem, b: ScheduleItem) => {
      const sa = CourseLogic.minutesOf(CourseLogic.realStartTime(a.periodStart, a.classroom));
      const sb = CourseLogic.minutesOf(CourseLogic.realStartTime(b.periodStart, b.classroom));
      if (sa !== sb) {
        return sa - sb;
      }
      return a.periodStart - b.periodStart;
    });
  }

  // 已选课程 → 课表行：仅转换含有效星期/节次/周次的课程（集中实践等无排课信息的跳过）
  static selectedCourseToScheduleItem(c: Course): ScheduleItem | undefined {
    if (c.weekday < 1 || c.weekday > 7 || c.periodStart < 1 || c.periodEnd < c.periodStart) {
      return undefined;
    }
    const weeks = CourseLogic.parseCourseWeeks(c.weeks);
    if (weeks.length === 0) {
      return undefined;
    }
    const item: ScheduleItem = {
      id: 'sel-' + c.id,
      term: '2025-2026-2',
      type: 'normal',
      courseId: c.id,
      courseName: c.name,
      teacher: c.teacher,
      weekday: c.weekday,
      periodStart: c.periodStart,
      periodEnd: c.periodEnd,
      startTime: CourseLogic.sectionStartTime(c.periodStart),
      endTime: CourseLogic.sectionEndTime(c.periodEnd),
      classroom: c.classroom,
      campus: c.campus,
      weeks: weeks,
      weekText: c.weeks,
      courseType: c.category
    };
    return item;
  }

  // 解析课程周次文本（形如 "1-16 周" / "2-15 周" / "1,3,5 周"）为周次数组
  static parseCourseWeeks(weeksStr: string): number[] {
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

  // 课程与课表行是否时间冲突：同一星期、节次区间重叠、且周次有交集（集中实践等未排课课程不参与）
  static courseConflictsWithScheduleItem(c: Course, s: ScheduleItem): boolean {
    if (c.weekday < 1 || s.weekday < 1 || c.weekday !== s.weekday) {
      return false;
    }
    if (c.periodStart > s.periodEnd || s.periodStart > c.periodEnd) {
      return false;
    }
    const wc = CourseLogic.parseCourseWeeks(c.weeks);
    for (let i = 0; i < wc.length; i++) {
      if (s.weeks.indexOf(wc[i]) >= 0) {
        return true;
      }
    }
    return false;
  }

  // 两门课是否时间冲突：同一星期、节次区间重叠、且周次有交集
  static coursesConflict(a: Course, b: Course): boolean {
    if (a.weekday < 1 || b.weekday < 1) {
      return false; // 未排课（如集中实践）不参与冲突判定
    }
    if (a.weekday !== b.weekday) {
      return false;
    }
    if (a.periodStart > b.periodEnd || b.periodStart > a.periodEnd) {
      return false;
    }
    const wa = CourseLogic.parseCourseWeeks(a.weeks);
    const wb = CourseLogic.parseCourseWeeks(b.weeks);
    for (let i = 0; i < wa.length; i++) {
      if (wb.indexOf(wa[i]) >= 0) {
        return true;
      }
    }
    return false;
  }

  // 展示态：已选保持 selected；其余按容量/冲突派生 full / conflict / available
  static decorateStatuses(selections: SelectionCourse[]): SelectionCourse[] {
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
        if (CourseLogic.coursesConflict(item.course, selected[i].course)) {
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

  static computeRemainingSeconds(endTime: string): number {
    const end = Date.parse(endTime.replace(' ', 'T'));
    if (Number.isNaN(end)) {
      return 0;
    }
    const diff = Math.floor((end - Date.now()) / 1000);
    return diff > 0 ? diff : 0;
  }

  static remoteToNotice(n: RemoteNotice): Notice {
    const item: Notice = {
      id: n.id,
      title: n.title,
      publisher: n.publisher,
      publishedAt: n.publishedAt,
      summary: n.summary,
      content: n.content,
      isRead: n.isRead,
      category: n.category,
      urgency: (n.urgency && n.urgency.length > 0) ? n.urgency : 'normal',
      attachments: []
    };
    return item;
  }
}
