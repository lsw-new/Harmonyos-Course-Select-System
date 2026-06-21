// 个人系统消息聚合 · 从现有 请假/成绩/选课/评教 接口派生消息流（纯客户端，不动后端）。
// 公告（Notice）与本仓库无关：公告仍由 CourseRepository.getNotices() 提供。

import { Message } from '../models/Message';
import { LeaveRequest } from '../models/Misc';
import { GradeRecord } from '../models/Academic';
import { EvaluationTask } from '../models/Evaluation';
import { SelectionCourse } from '../models/Course';
import { ProfileRepository } from './ProfileRepository';
import { AcademicRepository } from './AcademicRepository';
import { EvaluationRepository } from './EvaluationRepository';
import { CourseRepository } from './CourseRepository';
import { SessionStorage } from '../common/storage/SessionStorage';
import { MessageSeenStore } from '../common/services/MessageSeenStore';
import { Routes } from '../app/AppRoute';
import { AppConfig } from '../app/AppConfig';
import { RemoteApi, RemoteMessage } from '../common/remote/RemoteApi';

export class MessageRepository {
  private static _instance?: MessageRepository;

  static get(): MessageRepository {
    if (!MessageRepository._instance) {
      MessageRepository._instance = new MessageRepository();
    }
    return MessageRepository._instance;
  }

  private currentStudentId(): string {
    const s = SessionStorage.get().getStudent();
    return s ? s.studentId : '';
  }

  // 联机优先：服务端消息流（已读跨设备同步）；离线/远程失败按策略回退本地聚合。
  async getMessages(): Promise<Message[]> {
    if (AppConfig.useRemote) {
      try {
        const remote = await RemoteApi.listMessages();
        return remote.map((r: RemoteMessage): Message => this.remoteToMessage(r));
      } catch (e) {
        if (!AppConfig.allowMockFallbackInRemote) {
          throw new Error('远程服务异常，请稍后重试');
        }
        // 允许回退：落到下方本地聚合
      }
    }
    return this.getMessagesLocal();
  }

  // 本地聚合四个来源 → 应用本地已读 → 时间倒序（mock 模式 / 远程回退）
  private async getMessagesLocal(): Promise<Message[]> {
    const sid = this.currentStudentId();
    // 四个来源并行发起，任一失败回退空，互不阻断
    const leavesP = this.safeLeaves();
    const gradesP = this.safeGrades();
    const selectionsP = this.safeSelections();
    const tasksP = this.safeEvalTasks();
    const leaves = await leavesP;
    const grades = await gradesP;
    const selections = await selectionsP;
    const tasks = await tasksP;

    const list: Message[] = [];
    leaves.forEach((lv: LeaveRequest) => {
      const m = this.leaveToMessage(lv);
      if (m !== undefined) {
        list.push(m);
      }
    });
    grades.forEach((g: GradeRecord) => {
      if ((g.status !== undefined ? g.status : '') === 'published') {
        list.push(this.gradeToMessage(g));
      }
    });
    selections.forEach((sc: SelectionCourse) => {
      if (sc.status === 'selected') {
        list.push(this.selectionToMessage(sc));
      }
    });
    let openCount = 0;
    tasks.forEach((t: EvaluationTask) => {
      if (t.status === 'open') {
        openCount += 1;
      }
    });
    if (openCount > 0) {
      list.push(this.evalToMessage(openCount, tasks));
    }

    const readIds = await MessageSeenStore.loadRead(sid);
    const marked: Message[] = list.map((m: Message): Message => {
      const copy: Message = {
        id: m.id,
        kind: m.kind,
        title: m.title,
        body: m.body,
        timestamp: m.timestamp,
        isRead: readIds.indexOf(m.id) >= 0,
        route: m.route,
        param: m.param
      };
      return copy;
    });
    marked.sort((a: Message, b: Message): number => {
      if (a.timestamp.length === 0 && b.timestamp.length === 0) {
        return 0;
      }
      if (a.timestamp.length === 0) {
        return 1;
      }
      if (b.timestamp.length === 0) {
        return -1;
      }
      return a.timestamp < b.timestamp ? 1 : -1;
    });
    return marked;
  }

  async getUnreadCount(): Promise<number> {
    if (AppConfig.useRemote) {
      try {
        return await RemoteApi.messageUnreadCount();
      } catch (e) {
        if (!AppConfig.allowMockFallbackInRemote) {
          throw new Error('远程服务异常，请稍后重试');
        }
        // 允许回退：落到下方本地聚合
      }
    }
    const msgs = await this.getMessagesLocal();
    let c = 0;
    msgs.forEach((m: Message) => {
      if (!m.isRead) {
        c += 1;
      }
    });
    return c;
  }

  // 标记单条已读，并刷新首页未读消息角标。
  // 页面调用为「即发即忘」且已做乐观更新，故远程同步为尽力而为：失败不抛出，避免未捕获拒绝打断浏览。
  async markRead(id: string): Promise<void> {
    if (AppConfig.useRemote) {
      try {
        await RemoteApi.markMessageRead(id);
        const c = await RemoteApi.messageUnreadCount();
        AppStorage.setOrCreate<number>('home.unreadMessage', c);
      } catch (e) {
        // 远程失败：保留页面乐观态，本机无对应已读存储可写，静默跳过
      }
      return;
    }
    await MessageSeenStore.markRead(this.currentStudentId(), id);
    const c = await this.getUnreadCount();
    AppStorage.setOrCreate<number>('home.unreadMessage', c);
  }

  // 全部标记已读。远程失败时向调用页传播（页面 catch 提示），与单条不同。
  async markAllRead(): Promise<void> {
    if (AppConfig.useRemote) {
      await RemoteApi.markAllMessagesRead();
      AppStorage.setOrCreate<number>('home.unreadMessage', 0);
      return;
    }
    const sid = this.currentStudentId();
    const msgs = await this.getMessagesLocal();
    const ids: string[] = msgs.map((m: Message): string => m.id);
    await MessageSeenStore.saveRead(sid, ids);
    AppStorage.setOrCreate<number>('home.unreadMessage', 0);
  }

  // ============ 远程消息映射（RemoteMessage → Message） ============

  private remoteToMessage(r: RemoteMessage): Message {
    const m: Message = {
      id: r.messageId,
      kind: r.kind,
      title: r.title,
      body: r.body,
      timestamp: this.formatTs(r.createdAt),
      isRead: r.read,
      route: r.route,
      param: this.buildParam(r)
    };
    return m;
  }

  // 后端 param 为标量：请假审批存 leave_id，前端请假详情页按 key 'id' 取参；其余消息无参。
  private buildParam(r: RemoteMessage): Record<string, Object> | undefined {
    if (r.route === Routes.LeaveDetail && r.param.length > 0) {
      const p: Record<string, Object> = { 'id': r.param };
      return p;
    }
    return undefined;
  }

  // ISO 时间串 → '年-月-日 时:分'（按设备本地时区展示）；非法时间回退原串。
  private formatTs(iso: string): string {
    if (iso.length === 0) {
      return '';
    }
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) {
      return iso;
    }
    const pad = (n: number): string => n < 10 ? `0${n}` : `${n}`;
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  // ============ 来源安全包装（任一失败回退空，不阻断其余） ============

  private async safeLeaves(): Promise<LeaveRequest[]> {
    try {
      return await ProfileRepository.get().getLeaveRequests();
    } catch (e) {
      return [];
    }
  }

  private async safeGrades(): Promise<GradeRecord[]> {
    try {
      return await AcademicRepository.get().getGrades();
    } catch (e) {
      return [];
    }
  }

  private async safeSelections(): Promise<SelectionCourse[]> {
    try {
      return await CourseRepository.get().getSelectionCourses();
    } catch (e) {
      return [];
    }
  }

  private async safeEvalTasks(): Promise<EvaluationTask[]> {
    try {
      return await EvaluationRepository.get().getTasks();
    } catch (e) {
      return [];
    }
  }

  // ============ 各来源 → Message 映射 ============

  private leaveToMessage(lv: LeaveRequest): Message | undefined {
    let title = '';
    if (lv.state === 'approved') {
      title = '请假申请已通过';
    } else if (lv.state === 'rejected') {
      title = '请假申请被驳回';
    } else if (lv.state === 'pending') {
      title = '请假申请已提交，等待审批';
    } else {
      return undefined; // withdrawn 不生成消息
    }
    let body = `${this.leaveTypeLabel(lv.type)} · ${lv.startDate} 至 ${lv.endDate}`;
    if (lv.state === 'rejected' && lv.feedback !== undefined && lv.feedback.length > 0) {
      body = `${body} · ${lv.feedback}`;
    }
    const param: Record<string, Object> = { 'id': lv.id };
    const m: Message = {
      id: `msg-leave-${lv.id}-${lv.state}`,
      kind: 'leave',
      title: title,
      body: body,
      timestamp: lv.submittedAt,
      isRead: false,
      route: Routes.LeaveDetail,
      param: param
    };
    return m;
  }

  private gradeToMessage(g: GradeRecord): Message {
    const m: Message = {
      id: `msg-grade-${g.id}`,
      kind: 'grade',
      title: `《${g.courseName}》成绩已发布`,
      body: this.gradeScoreText(g),
      timestamp: g.publishedAt !== undefined ? g.publishedAt : '',
      isRead: false,
      route: Routes.Grades,
      param: undefined
    };
    return m;
  }

  private selectionToMessage(sc: SelectionCourse): Message {
    const c = sc.course;
    const m: Message = {
      id: `msg-selection-${c.id}`,
      kind: 'selection',
      title: `选课成功：《${c.name}》`,
      body: `${c.code} · ${c.teacher} · ${c.credit} 学分`,
      timestamp: '',
      isRead: false,
      route: Routes.Selection,
      param: undefined
    };
    return m;
  }

  private evalToMessage(count: number, tasks: EvaluationTask[]): Message {
    let ts = '';
    tasks.forEach((t: EvaluationTask) => {
      const ot = t.openTime !== undefined ? t.openTime : '';
      if (t.status === 'open' && ot.length > 0) {
        if (ts.length === 0 || ot < ts) {
          ts = ot;
        }
      }
    });
    const m: Message = {
      id: 'msg-eval-open',
      kind: 'eval',
      title: '评教任务待完成',
      body: `本学期 ${count} 门课程待评教`,
      timestamp: ts,
      isRead: false,
      route: Routes.Eval,
      param: undefined
    };
    return m;
  }

  // number | string 联合安全转串（ArkTS 需 typeof 收窄）
  private scoreToStr(v?: number | string): string {
    if (v === undefined) {
      return '';
    }
    return typeof v === 'number' ? `${v}` : v;
  }

  private gradeScoreText(g: GradeRecord): string {
    let s = this.scoreToStr(g.finalScore);
    if (s.length === 0) {
      s = this.scoreToStr(g.totalScore);
    }
    if (s.length === 0) {
      return '成绩已发布，点击查看';
    }
    const gp = this.scoreToStr(g.gradePoint);
    return gp.length > 0 ? `成绩 ${s} · 绩点 ${gp}` : `成绩 ${s}`;
  }

  private leaveTypeLabel(type: string): string {
    if (type === 'sick') {
      return '病假';
    }
    if (type === 'personal') {
      return '事假';
    }
    if (type === 'public') {
      return '公假';
    }
    return '其他';
  }
}
