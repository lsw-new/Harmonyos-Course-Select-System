// 教师端仓储（roadmap #6）：联机走后端 /api/teacher/*，远程失败按策略回退 mock；
// mock 提供少量演示数据，便于离线/无后端时走通教师端各页。

import { AppConfig } from '../app/AppConfig';
import {
  RemoteApi, RemoteTeacherDashboard, RemoteTeacherCourse, RemoteTeacherStudent,
  RemoteTeacherCourseStudents, RemoteTeacherEval, RemoteTeacherGradeResult,
  RemoteTeacherNotice, RemoteTeacherNoticeResult, RemoteTeacherAppeal, RemoteTeacherAppealResult,
  RemoteTeacherGradeDistribution, RemoteTeacherScheduleItem
} from '../common/remote/RemoteApi';
import {
  TeacherDashboard, TeacherCourse, TeacherStudent, TeacherCourseStudents,
  TeacherEval, TeacherScoreInput, TeacherNotice, TeacherAppeal,
  TeacherGradeDistribution, TeacherScheduleItem
} from '../models/Teacher';

export interface TeacherGradeResult {
  updated: number;
  inputProgress: number;
  status: string;
}

export interface TeacherNoticeResult {
  noticeId: string;
  recipients: number;
}

export class TeacherRepository {
  private static _instance?: TeacherRepository;
  static get(): TeacherRepository {
    if (!TeacherRepository._instance) {
      TeacherRepository._instance = new TeacherRepository();
    }
    return TeacherRepository._instance;
  }

  private fail<T>(message: string): Promise<T> {
    return Promise.reject(new Error(message));
  }

  async getDashboard(): Promise<TeacherDashboard> {
    if (AppConfig.useRemote) {
      try {
        const r: RemoteTeacherDashboard = await RemoteApi.teacherDashboard();
        return {
          courseCount: r.courseCount,
          studentCount: r.studentCount,
          pendingGradeCount: r.pendingGradeCount,
          evalSubmitted: r.evalSubmitted
        };
      } catch (e) {
        if (!AppConfig.allowMockFallbackInRemote) {
          return this.fail<TeacherDashboard>('远程服务异常，请稍后重试');
        }
      }
    }
    const mock: TeacherDashboard = { courseCount: 2, studentCount: 94, pendingGradeCount: 1, evalSubmitted: 47 };
    return mock;
  }

  async getCourses(): Promise<TeacherCourse[]> {
    if (AppConfig.useRemote) {
      try {
        const list: RemoteTeacherCourse[] = await RemoteApi.teacherCourses();
        return list.map((c: RemoteTeacherCourse): TeacherCourse => this.toCourse(c));
      } catch (e) {
        if (!AppConfig.allowMockFallbackInRemote) {
          return this.fail<TeacherCourse[]>('远程服务异常，请稍后重试');
        }
      }
    }
    return this.mockCourses();
  }

  async getCourseStudents(courseId: string): Promise<TeacherCourseStudents> {
    if (AppConfig.useRemote) {
      try {
        const r: RemoteTeacherCourseStudents = await RemoteApi.teacherCourseStudents(courseId);
        return {
          courseId: r.courseId,
          term: r.term,
          teachingClassName: r.teachingClassName,
          students: r.students.map((s: RemoteTeacherStudent): TeacherStudent => this.toStudent(s))
        };
      } catch (e) {
        if (!AppConfig.allowMockFallbackInRemote) {
          return this.fail<TeacherCourseStudents>('远程服务异常，请稍后重试');
        }
      }
    }
    return this.mockStudents(courseId);
  }

  async submitGrades(courseId: string, scores: TeacherScoreInput[]): Promise<TeacherGradeResult> {
    if (AppConfig.useRemote) {
      try {
        const r: RemoteTeacherGradeResult = await RemoteApi.teacherSubmitGrades(courseId, scores);
        return { updated: r.updated, inputProgress: r.inputProgress, status: r.status };
      } catch (e) {
        return this.fail<TeacherGradeResult>((e instanceof Error) ? e.message : '录入失败');
      }
    }
    // mock：直接视为录入成功
    const mock: TeacherGradeResult = { updated: scores.length, inputProgress: 100, status: 'pendingAudit' };
    return mock;
  }

  async getEvaluations(): Promise<TeacherEval[]> {
    if (AppConfig.useRemote) {
      try {
        const list: RemoteTeacherEval[] = await RemoteApi.teacherEvaluations();
        return list.map((e: RemoteTeacherEval): TeacherEval => ({
          courseId: e.courseId,
          courseName: e.courseName,
          term: e.term,
          taskCount: e.taskCount,
          submittedCount: e.submittedCount,
          avgScore: e.avgScore
        }));
      } catch (e) {
        if (!AppConfig.allowMockFallbackInRemote) {
          return this.fail<TeacherEval[]>('远程服务异常，请稍后重试');
        }
      }
    }
    return this.mockEvals();
  }

  async publishNotice(courseId: string, title: string, content: string): Promise<TeacherNoticeResult> {
    if (AppConfig.useRemote) {
      try {
        const r: RemoteTeacherNoticeResult = await RemoteApi.teacherPublishNotice(courseId, title, content);
        return { noticeId: r.noticeId, recipients: r.recipients };
      } catch (e) {
        return this.fail<TeacherNoticeResult>((e instanceof Error) ? e.message : '发布失败');
      }
    }
    const mock: TeacherNoticeResult = { noticeId: 'mock-notice', recipients: 47 };
    return mock;
  }

  async getNotices(): Promise<TeacherNotice[]> {
    if (AppConfig.useRemote) {
      try {
        const list: RemoteTeacherNotice[] = await RemoteApi.teacherNotices();
        return list.map((n: RemoteTeacherNotice): TeacherNotice => ({
          noticeId: n.noticeId, title: n.title, summary: n.summary,
          category: n.category, urgency: n.urgency, publishedAt: n.publishedAt
        }));
      } catch (e) {
        if (!AppConfig.allowMockFallbackInRemote) {
          return this.fail<TeacherNotice[]>('远程服务异常，请稍后重试');
        }
      }
    }
    return [
      { noticeId: 'mn1', title: '本周五补考通知', summary: '本周五补考，正常课程暂停', category: '课程通知', urgency: 'normal', publishedAt: '2026-06-20 10:00' }
    ];
  }

  async getAppeals(): Promise<TeacherAppeal[]> {
    if (AppConfig.useRemote) {
      try {
        const list: RemoteTeacherAppeal[] = await RemoteApi.teacherGradeAppeals();
        return list.map((a: RemoteTeacherAppeal): TeacherAppeal => this.toAppeal(a));
      } catch (e) {
        if (!AppConfig.allowMockFallbackInRemote) {
          return this.fail<TeacherAppeal[]>('远程服务异常，请稍后重试');
        }
      }
    }
    return [
      { appealId: 'ma1', studentId: '2023307020941', studentName: '李仕炜', courseId: 'mock-c1', courseName: '编译原理', term: '2025-2026-2', reason: '平时分疑似漏算，请复核', status: 'pending', reply: '', submittedAt: '2026-06-19 14:00' }
    ];
  }

  async handleAppeal(appealId: string, decision: string, reply: string): Promise<string> {
    if (AppConfig.useRemote) {
      try {
        const r: RemoteTeacherAppealResult = await RemoteApi.teacherHandleAppeal(appealId, decision, reply);
        return r.status;
      } catch (e) {
        return this.fail<string>((e instanceof Error) ? e.message : '处理失败');
      }
    }
    return decision;
  }

  private toAppeal(a: RemoteTeacherAppeal): TeacherAppeal {
    return {
      appealId: a.appealId, studentId: a.studentId, studentName: a.studentName,
      courseId: a.courseId, courseName: a.courseName, term: a.term,
      reason: a.reason, status: a.status, reply: a.reply, submittedAt: a.submittedAt
    };
  }

  async updateEmail(email: string): Promise<boolean> {
    if (AppConfig.useRemote) {
      try {
        await RemoteApi.teacherUpdateEmail(email);
        return true;
      } catch (e) {
        return this.fail<boolean>((e instanceof Error) ? e.message : '更新失败');
      }
    }
    return true;
  }

  // 更新头像：avatarUrl 由 FileService.pickAndUploadAvatarImage 产出（绝对 https 或 data URL）。
  async updateAvatar(avatarUrl: string): Promise<boolean> {
    if (AppConfig.useRemote) {
      try {
        await RemoteApi.teacherUpdateAvatar(avatarUrl);
        return true;
      } catch (e) {
        return this.fail<boolean>((e instanceof Error) ? e.message : '更新头像失败');
      }
    }
    return true;
  }

  async getGradeDistribution(courseId: string): Promise<TeacherGradeDistribution> {
    if (AppConfig.useRemote) {
      try {
        const r: RemoteTeacherGradeDistribution = await RemoteApi.teacherGradeDistribution(courseId);
        return {
          excellent: r.excellent, good: r.good, medium: r.medium,
          pass: r.pass, fail: r.fail, total: r.total, avgScore: r.avgScore
        };
      } catch (e) {
        if (!AppConfig.allowMockFallbackInRemote) {
          return this.fail<TeacherGradeDistribution>('远程服务异常，请稍后重试');
        }
      }
    }
    return { excellent: 2, good: 3, medium: 1, pass: 1, fail: 0, total: 7, avgScore: 84.3 };
  }

  async getSchedule(): Promise<TeacherScheduleItem[]> {
    if (AppConfig.useRemote) {
      try {
        const list: RemoteTeacherScheduleItem[] = await RemoteApi.teacherSchedule();
        return list.map((s: RemoteTeacherScheduleItem): TeacherScheduleItem => ({
          itemId: s.itemId, courseName: s.courseName, className: s.className, weekday: s.weekday,
          periodStart: s.periodStart, periodEnd: s.periodEnd, startTime: s.startTime, endTime: s.endTime,
          classroom: s.classroom, weekText: s.weekText, term: s.term
        }));
      } catch (e) {
        if (!AppConfig.allowMockFallbackInRemote) {
          return this.fail<TeacherScheduleItem[]>('远程服务异常，请稍后重试');
        }
      }
    }
    return [
      { itemId: 'ms1', courseName: '编译原理', className: '23计算机U9', weekday: 1, periodStart: 1, periodEnd: 2, startTime: '08:00', endTime: '09:40', classroom: '教7-802', weekText: '1-16周', term: '2025-2026-2' },
      { itemId: 'ms2', courseName: '操作系统', className: '23计算机U9', weekday: 3, periodStart: 5, periodEnd: 6, startTime: '14:00', endTime: '15:40', classroom: '教5-301', weekText: '1-16周', term: '2025-2026-2' }
    ];
  }

  // ===== 映射 =====
  private toCourse(c: RemoteTeacherCourse): TeacherCourse {
    return {
      courseId: c.courseId,
      taskId: c.taskId,
      code: c.code,
      name: c.name,
      category: c.category,
      credit: c.credit,
      teachingClassName: c.teachingClassName,
      term: c.term,
      studentCount: c.studentCount,
      gradeStatus: c.gradeStatus,
      inputProgress: c.inputProgress
    };
  }

  private toStudent(s: RemoteTeacherStudent): TeacherStudent {
    return {
      studentId: s.studentId,
      name: s.name,
      className: s.className,
      score: s.score,
      gradePoint: s.gradePoint,
      status: s.status
    };
  }

  // ===== mock =====
  private mockCourses(): TeacherCourse[] {
    return [
      { courseId: 'mock-c1', taskId: 'mock-gt1', code: 'CS2103', name: '编译原理', category: 'required', credit: 3, teachingClassName: '23计算机U9', term: '2025-2026-2', studentCount: 47, gradeStatus: 'inputting', inputProgress: 60 },
      { courseId: 'mock-c2', taskId: 'mock-gt2', code: 'CS2201', name: '操作系统', category: 'required', credit: 4, teachingClassName: '23计算机U9', term: '2025-2026-2', studentCount: 47, gradeStatus: 'pendingAudit', inputProgress: 100 }
    ];
  }

  private mockStudents(courseId: string): TeacherCourseStudents {
    return {
      courseId: courseId,
      term: '2025-2026-2',
      teachingClassName: '23计算机U9',
      students: [
        { studentId: '2023307020941', name: '李仕炜', className: '23计算机U9', score: 88, gradePoint: 3.8, status: 'scored' },
        { studentId: '2023307020942', name: '王同学', className: '23计算机U9', score: null, gradePoint: null, status: 'none' },
        { studentId: '2023307020943', name: '张同学', className: '23计算机U9', score: 76, gradePoint: 2.6, status: 'scored' }
      ]
    };
  }

  private mockEvals(): TeacherEval[] {
    return [
      { courseId: 'mock-c1', courseName: '编译原理', term: '2025-2026-2', taskCount: 47, submittedCount: 30, avgScore: 4.6 },
      { courseId: 'mock-c2', courseName: '操作系统', term: '2025-2026-2', taskCount: 47, submittedCount: 41, avgScore: 4.8 }
    ];
  }
}
