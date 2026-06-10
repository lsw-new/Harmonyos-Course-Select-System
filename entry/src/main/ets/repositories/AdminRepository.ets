// 管理端仓储

import { BaseRepository } from './BaseRepository';
import {
  AdminDashboardSummary, DashboardStatCard, TrendPoint, DistributionItem,
  StudentAdminItem, AdminCourseItem, AdminCourseWritePayload, SelectionRound, SelectionRoundStatus,
  GradeAuditItem, GradeInputPayload, GradeRejectPayload, GradeScoreRow, NoticeDraft, EvaluationStats, ApprovalItem, ApprovalDetail, ApprovalStatus,
  AdminPermissionAction
} from '../models/Admin';
import { LeaveRequest, ApprovalState } from '../models/Misc';
import {
  mockAdminDashboard, mockAdminStudents, mockAdminCourses, mockSelectionRounds,
  mockGradeAudits, mockEvaluationStats, mockApprovals, mockApprovalDetail
} from '../mock/mockAdmin';
import { AppDatabase } from '../common/storage/AppDatabase';
import { LocalDataStore } from '../common/storage/LocalDataStore';
import { AuthorizationService } from '../common/security/AuthorizationService';
import { NoticeStore } from '../common/services/NoticeStore';
import { AppConfig } from '../app/AppConfig';
import { RemoteApi, GradeScoreEntry, AdminCourseBody, RemoteAdminRound } from '../common/remote/RemoteApi';
import { CourseLogic } from './CourseLogic';
import { AdminLogic } from './AdminLogic';
import { AdminRdbStore } from './AdminRdbStore';

const KEY_ADMIN_APPROVALS = 'local.adminApprovals.v1';
const KEY_ADMIN_GRADES = 'local.adminGrades.v1';
const KEY_ADMIN_COURSES = 'local.adminCourses.v1';
const KEY_LOCAL_LEAVES = 'local.leaveRequests.v1';

export class AdminRepository extends BaseRepository {
  private static _instance?: AdminRepository;
  static get(): AdminRepository {
    if (!AdminRepository._instance) {
      AdminRepository._instance = new AdminRepository();
    }
    return AdminRepository._instance;
  }

  private approvals: ApprovalItem[] = JSON.parse(JSON.stringify(mockApprovals)) as ApprovalItem[];
  private grades: GradeAuditItem[] = JSON.parse(JSON.stringify(mockGradeAudits)) as GradeAuditItem[];
  private courses: AdminCourseItem[] = JSON.parse(JSON.stringify(mockAdminCourses)) as AdminCourseItem[];
  private isApprovalsLoaded: boolean = false;
  private isGradesLoaded: boolean = false;
  private isCoursesLoaded: boolean = false;

  private async getApprovalItems(): Promise<ApprovalItem[]> {
    if (AppDatabase.isReady()) {
      const rdbItems = await AdminRdbStore.getApprovalItemsFromRdb();
      const stored = await LocalDataStore.loadArray<ApprovalItem>(KEY_ADMIN_APPROVALS, []);
      this.approvals = AdminLogic.mergeApprovalItems(AdminLogic.mergeApprovalItems(rdbItems, stored), mockApprovals);
      this.isApprovalsLoaded = true;
      return this.approvals;
    }
    const stored = await LocalDataStore.loadArray<ApprovalItem>(KEY_ADMIN_APPROVALS, []);
    this.approvals = AdminLogic.mergeApprovalItems(stored, mockApprovals);
    this.isApprovalsLoaded = true;
    return this.approvals;
  }

  private async getGradeItems(): Promise<GradeAuditItem[]> {
    if (AppDatabase.isReady()) {
      const rdbItems = await AdminRdbStore.loadGradeTasksFromRdb();
      if (rdbItems.length > 0) {
        const stored = await LocalDataStore.loadArray<GradeAuditItem>(KEY_ADMIN_GRADES, []);
        this.grades = AdminLogic.mergeGradeItems(rdbItems, AdminLogic.mergeGradeItems(stored, mockGradeAudits));
      } else {
        const stored = await LocalDataStore.loadArray<GradeAuditItem>(KEY_ADMIN_GRADES, mockGradeAudits);
        const sanitized = AdminLogic.sanitizeGradeItems(stored);
        this.grades = sanitized.length > 0 ? sanitized : JSON.parse(JSON.stringify(mockGradeAudits)) as GradeAuditItem[];
      }
      this.isGradesLoaded = true;
      return this.grades;
    }
    if (!this.isGradesLoaded) {
      const stored = await LocalDataStore.loadArray<GradeAuditItem>(KEY_ADMIN_GRADES, mockGradeAudits);
      const sanitized = AdminLogic.sanitizeGradeItems(stored);
      this.grades = sanitized.length > 0 ? sanitized : JSON.parse(JSON.stringify(mockGradeAudits)) as GradeAuditItem[];
      this.isGradesLoaded = true;
    }
    return this.grades;
  }


  private async getCourseItems(): Promise<AdminCourseItem[]> {
    if (AppDatabase.isReady()) {
      await AdminRdbStore.seedCoursesIfNeeded();
      const rdbItems = await AdminRdbStore.loadCoursesFromRdb();
      this.courses = AdminLogic.sanitizeCourseItems(rdbItems);
      this.isCoursesLoaded = true;
      return this.courses;
    }
    if (!this.isCoursesLoaded) {
      const stored = await LocalDataStore.loadArray<AdminCourseItem>(KEY_ADMIN_COURSES, mockAdminCourses);
      const sanitized = AdminLogic.sanitizeCourseItems(stored);
      this.courses = sanitized.length > 0 ? sanitized : JSON.parse(JSON.stringify(mockAdminCourses)) as AdminCourseItem[];
      this.isCoursesLoaded = true;
    }
    return this.courses;
  }

  private async saveCourses(next: AdminCourseItem[]): Promise<void> {
    this.courses = next;
    this.isCoursesLoaded = true;
    if (AppDatabase.isReady()) {
      await AdminRdbStore.saveCoursesToRdb(next);
      return;
    }
    await LocalDataStore.saveArray<AdminCourseItem>(KEY_ADMIN_COURSES, next);
  }


  private hasCourseWritePermission(action: AdminPermissionAction): boolean {
    return this.hasAdminPermission('courses.manage', action);
  }

  private hasAdminPermission(code: string, action: AdminPermissionAction): boolean {
    return AuthorizationService.hasAdminPermission(code, action);
  }

  private hasGradePermission(action: AdminPermissionAction): boolean {
    return this.hasAdminPermission('grades.approve', action);
  }

  private hasGradeInputPermission(): boolean {
    return this.hasGradePermission('create') || this.hasGradePermission('update');
  }

  private hasApprovalPermission(action: AdminPermissionAction): boolean {
    return this.hasAdminPermission('approvals.handle', action);
  }

  private rejectUnauthorized(): Promise<never> {
    return this.reject('无权限操作', 'unauthorized');
  }



  private async saveApprovals(next: ApprovalItem[]): Promise<void> {
    this.approvals = next;
    this.isApprovalsLoaded = true;
    await LocalDataStore.saveArray<ApprovalItem>(KEY_ADMIN_APPROVALS, next);
  }


  private async updateLinkedLeave(approvalId: string, state: ApprovalState, feedback: string): Promise<void> {
    if (approvalId.indexOf('ap-lv-') !== 0) {
      return;
    }
    const leaveId = approvalId.substring(3);
    if (AppDatabase.isReady()) {
      await AppDatabase.execute(
        `UPDATE leave_requests
         SET status = ${AppDatabase.sqlText(state)}, feedback = ${AppDatabase.sqlText(feedback)}, updated_at = CURRENT_TIMESTAMP
         WHERE leave_id = ${AppDatabase.sqlText(leaveId)}`
      );
      return;
    }
    const leaves = await LocalDataStore.loadArray<LeaveRequest>(KEY_LOCAL_LEAVES, []);
    let changed = false;
    const next = leaves.map((item) => {
      if (item.id !== leaveId) {
        return item;
      }
      changed = true;
      const updated: LeaveRequest = {
        id: item.id,
        type: item.type,
        startDate: item.startDate,
        endDate: item.endDate,
        reason: item.reason,
        attachments: item.attachments,
        state: state,
        submittedAt: item.submittedAt,
        feedback: feedback
      };
      return updated;
    });
    if (changed) {
      await LocalDataStore.saveArray<LeaveRequest>(KEY_LOCAL_LEAVES, next);
    }
  }

  private async saveGrades(next: GradeAuditItem[]): Promise<void> {
    const sanitized = AdminLogic.sanitizeGradeItems(next);
    this.grades = sanitized;
    this.isGradesLoaded = true;
    await LocalDataStore.saveArray<GradeAuditItem>(KEY_ADMIN_GRADES, sanitized);
  }


  async getDashboard(): Promise<AdminDashboardSummary> {
    if (AppConfig.useRemote) {
      try {
        const remote = await RemoteApi.adminDashboard();
        const summary: AdminDashboardSummary = {
          statCards: remote.statCards.map((s): DashboardStatCard => {
            const card: DashboardStatCard = { key: s.key, label: s.label, value: s.value, color: s.color };
            return card;
          }),
          selectionTrend: remote.selectionTrend.map((t): TrendPoint => {
            const p: TrendPoint = { label: t.label, value: t.value };
            return p;
          }),
          courseTypeDistribution: remote.courseTypeDistribution.map((d): DistributionItem => {
            const item: DistributionItem = { name: d.name, value: d.value };
            return item;
          }),
          pendingApprovals: remote.pendingApprovals.map((a) => AdminLogic.remoteToApproval(a))
        };
        return this.delayCopy<AdminDashboardSummary>(summary);
      } catch (e) {
        // 远程失败回退本地汇总，保证仪表盘可用
      }
    }
    const approvals = await this.getApprovalItems();
    const summary: AdminDashboardSummary = {
      statCards: mockAdminDashboard.statCards,
      selectionTrend: mockAdminDashboard.selectionTrend,
      courseTypeDistribution: mockAdminDashboard.courseTypeDistribution,
      pendingApprovals: approvals.filter((item) => item.status === 'pending')
    };
    return this.delayCopy<AdminDashboardSummary>(summary);
  }

  async getStudents(query?: string, college?: string): Promise<StudentAdminItem[]> {
    if (AppConfig.useRemote) {
      try {
        const remote = await RemoteApi.adminListStudents(query, college);
        return this.delayCopy<StudentAdminItem[]>(remote.map((s) => AdminLogic.remoteToStudent(s)));
      } catch (e) {
        // 远程失败：remote 模式禁止静默回退时直接抛错，交由页面错误态呈现
        if (!AppConfig.allowMockFallbackInRemote) {
          throw new Error('远程服务异常，请稍后重试');
        }
        // 否则回退本地
      }
    }
    let items = mockAdminStudents;
    if (query && query.length > 0) {
      const q = query.toLowerCase();
      items = items.filter((s) =>
        s.name.toLowerCase().includes(q) ||
        s.studentId.toLowerCase().includes(q) ||
        s.className.toLowerCase().includes(q)
      );
    }
    if (college && college !== '全部') {
      items = items.filter((s) => s.college === college);
    }
    return this.delayCopy<StudentAdminItem[]>(items);
  }

  // 课程写入载荷 → 远程请求体（远程模式下后端为课程目录单一事实来源）
  private toCourseBody(payload: AdminCourseWritePayload): AdminCourseBody {
    const body: AdminCourseBody = {
      code: payload.code,
      name: payload.name,
      teacher: payload.teacher,
      category: payload.category,
      credit: payload.credit,
      timeText: payload.timeText,
      capacity: payload.capacity,
      status: payload.status
    };
    return body;
  }

  async getCourses(query?: string, category?: string): Promise<AdminCourseItem[]> {
    if (AppConfig.useRemote) {
      try {
        const remote = await RemoteApi.adminListCourses();
        let items = remote.map((r) => CourseLogic.remoteToAdminCourse(r));
        if (query && query.length > 0) {
          const q = query.toLowerCase();
          items = items.filter((c) =>
            c.name.toLowerCase().includes(q) ||
            c.code.toLowerCase().includes(q) ||
            c.teacher.toLowerCase().includes(q));
        }
        if (category && category !== '全部') {
          items = items.filter((c) => c.category === category);
        }
        return this.delayCopy<AdminCourseItem[]>(items);
      } catch (e) {
        // 远程失败回退本地 RDB 课程目录
      }
    }
    let items = await this.getCourseItems();
    if (query && query.length > 0) {
      const q = query.toLowerCase();
      items = items.filter((c) =>
        c.name.toLowerCase().includes(q) ||
        c.code.toLowerCase().includes(q) ||
        c.teacher.toLowerCase().includes(q)
      );
    }
    if (category && category !== '全部') {
      items = items.filter((c) => c.category === category);
    }
    return this.delayCopy<AdminCourseItem[]>(items);
  }

  // 选课人数调整：学生端选/退课时回写同一份课程数据，使课程容量/已选成为单一事实来源
  async adjustEnrollment(code: string, delta: number): Promise<void> {
    const items = await this.getCourseItems();
    const key = code.trim().toLowerCase();
    let changed = false;
    const next = items.map((item) => {
      if (item.code.trim().toLowerCase() !== key) {
        return item;
      }
      let count = item.selectedCount + delta;
      if (count < 0) {
        count = 0;
      }
      if (count > item.capacity) {
        count = item.capacity;
      }
      changed = true;
      const updated: AdminCourseItem = {
        id: item.id,
        code: item.code,
        name: item.name,
        teacher: item.teacher,
        category: item.category,
        credit: item.credit,
        timeText: item.timeText,
        capacity: item.capacity,
        selectedCount: count,
        status: item.status
      };
      return updated;
    });
    if (changed) {
      await this.saveCourses(next);
    }
  }

  async createCourse(payload: AdminCourseWritePayload): Promise<AdminCourseItem> {
    if (!this.hasCourseWritePermission('create')) {
      return this.rejectUnauthorized();
    }
    if (AppConfig.useRemote) {
      try {
        const remote = await RemoteApi.adminCreateCourse(this.toCourseBody(payload));
        return this.delayCopy<AdminCourseItem>(CourseLogic.remoteToAdminCourse(remote));
      } catch (e) {
        // 写操作不静默回退本地，显式报错避免两端数据分叉
        return this.reject((e instanceof Error) ? e.message : String(e));
      }
    }
    const items = await this.getCourseItems();
    const normalized = AdminLogic.normalizeCoursePayload(payload);
    const error = AdminLogic.validateCoursePayload(normalized, items);
    if (error.length > 0) {
      return this.reject(error);
    }
    const item: AdminCourseItem = {
      id: `ac-${Date.now()}`,
      code: normalized.code,
      name: normalized.name,
      teacher: normalized.teacher,
      category: normalized.category,
      credit: normalized.credit,
      timeText: normalized.timeText,
      capacity: normalized.capacity,
      selectedCount: normalized.selectedCount,
      status: normalized.status
    };
    const next = [item].concat(items);
    await this.saveCourses(next);
    return this.delayCopy<AdminCourseItem>(item);
  }

  async updateCourse(id: string, payload: AdminCourseWritePayload): Promise<AdminCourseItem> {
    if (!this.hasCourseWritePermission('update')) {
      return this.rejectUnauthorized();
    }
    if (AppConfig.useRemote) {
      try {
        const remote = await RemoteApi.adminUpdateCourse(id, this.toCourseBody(payload));
        return this.delayCopy<AdminCourseItem>(CourseLogic.remoteToAdminCourse(remote));
      } catch (e) {
        return this.reject((e instanceof Error) ? e.message : String(e));
      }
    }
    const items = await this.getCourseItems();
    const target = items.find((item) => item.id === id);
    if (!target) {
      return this.reject('课程不存在', 'notFound');
    }
    const normalized = AdminLogic.normalizeCoursePayload(payload);
    const error = AdminLogic.validateCoursePayload(normalized, items, id);
    if (error.length > 0) {
      return this.reject(error);
    }
    const updated: AdminCourseItem = {
      id: target.id,
      code: normalized.code,
      name: normalized.name,
      teacher: normalized.teacher,
      category: normalized.category,
      credit: normalized.credit,
      timeText: normalized.timeText,
      capacity: normalized.capacity,
      selectedCount: normalized.selectedCount,
      status: normalized.status
    };
    const next = items.map((item) => item.id === id ? updated : item);
    await this.saveCourses(next);
    return this.delayCopy<AdminCourseItem>(updated);
  }

  async deleteCourse(id: string): Promise<boolean> {
    if (!this.hasCourseWritePermission('delete')) {
      return this.rejectUnauthorized();
    }
    if (AppConfig.useRemote) {
      try {
        await RemoteApi.adminDeleteCourse(id);
        return this.delay<boolean>(true);
      } catch (e) {
        return this.reject((e instanceof Error) ? e.message : String(e));
      }
    }
    const items = await this.getCourseItems();
    const target = items.find((item) => item.id === id);
    if (!target) {
      return this.reject('课程不存在', 'notFound');
    }
    if (target.selectedCount > 0) {
      return this.reject('已有学生选课，不能删除');
    }
    const next = items.filter((item) => item.id !== id);
    await this.saveCourses(next);
    return this.delay<boolean>(true);
  }

  // 远程轮次统计 → 本地 SelectionRound（状态词表两端一致）
  private remoteToSelectionRound(r: RemoteAdminRound): SelectionRound {
    const round: SelectionRound = {
      id: r.id,
      name: r.name,
      status: r.status as SelectionRoundStatus,
      startTime: r.startTime,
      endTime: r.endTime,
      progressPercent: r.progressPercent,
      participantCount: r.participantCount,
      selectionCount: r.selectionCount,
      averageCredit: r.averageCredit,
      conflictCount: r.conflictCount
    };
    return round;
  }

  async getSelectionRounds(): Promise<SelectionRound[]> {
    if (AppConfig.useRemote) {
      try {
        const remote = await RemoteApi.adminSelectionStats();
        return this.delayCopy<SelectionRound[]>(remote.map((r) => this.remoteToSelectionRound(r)));
      } catch (e) {
        // 远程失败回退本地 mock 统计
      }
    }
    return this.delayCopy<SelectionRound[]>(mockSelectionRounds);
  }

  async getGradeAudits(status?: string): Promise<GradeAuditItem[]> {
    if (AppConfig.useRemote) {
      try {
        const remote = await RemoteApi.adminListGrades(status);
        return this.delayCopy<GradeAuditItem[]>(remote.map((t) => AdminLogic.remoteToGradeTask(t)));
      } catch (e) {
        // 远程失败：remote 模式禁止静默回退时直接抛错，交由页面错误态呈现
        if (!AppConfig.allowMockFallbackInRemote) {
          throw new Error('远程服务异常，请稍后重试');
        }
        // 否则回退本地
      }
    }
    let items = await this.getGradeItems();
    if (status && status !== '全部') {
      items = items.filter((g) => g.status === status);
    }
    return this.delayCopy<GradeAuditItem[]>(items);
  }

  async approveGrade(id: string): Promise<boolean> {
    if (!this.hasGradePermission('approve')) {
      return this.rejectUnauthorized();
    }
    if (AppConfig.useRemote) {
      try {
        await RemoteApi.adminGradeApprove(id);
        return this.delay<boolean>(true);
      } catch (e) {
        return this.reject((e instanceof Error) ? e.message : String(e));
      }
    }
    const grades = await this.getGradeItems();
    const target = grades.find((g) => g.id === id);
    if (!target) {
      return this.reject('成绩记录不存在', 'notFound');
    }
    if (target.status !== 'pendingAudit') {
      return this.reject('当前状态不可审核');
    }
    if (target.inputProgress !== 100) {
      return this.reject('录入进度达到 100% 后才能审核通过');
    }
    const next = grades.map((item) => {
      if (item.id !== id) {
        return item;
      }
      const updated: GradeAuditItem = {
        id: item.id,
        courseName: item.courseName,
        teachingClassName: item.teachingClassName,
        teacherName: item.teacherName,
        inputProgress: item.inputProgress,
        status: 'published',
        updatedAt: new Date().toISOString()
      };
      return updated;
    });
    await this.saveGrades(next);
    // RDB 就绪时同步 grade_tasks + grades 表
    if (AppDatabase.isReady()) {
      await AdminRdbStore.publishGradesToRdb(id).catch((err: Object) => {
        const msg = err instanceof Error ? err.message : String(err);
        // 非阻断：RDB 写入失败不影响 LocalDataStore 已保存的状态
        console.warn(`[AdminRepository] publishGradesToRdb failed: ${msg}`);
      });
    }
    return this.delay<boolean>(true);
  }

  // 打分名单：任务对应班级的已注册学生 + 已录分数（联机能力，后端为权威数据源）
  async getGradeScores(taskId: string): Promise<GradeScoreRow[]> {
    if (!this.hasGradeInputPermission()) {
      return this.rejectUnauthorized();
    }
    if (AppConfig.useRemote) {
      try {
        const remote = await RemoteApi.adminGradeScores(taskId);
        const rows: GradeScoreRow[] = remote.students.map((s): GradeScoreRow => {
          const row: GradeScoreRow = { studentId: s.studentId, name: s.name, score: s.score };
          return row;
        });
        return this.delayCopy<GradeScoreRow[]>(rows);
      } catch (e) {
        return this.reject((e instanceof Error) ? e.message : String(e));
      }
    }
    return this.reject('按学生打分为联机功能，请在联机模式下使用');
  }

  // 按学生打分：后端 UPSERT 成绩 + 重算排名 + 自动更新录入进度（满员转待审核）
  async submitGradeScores(taskId: string, entries: GradeScoreEntry[]): Promise<GradeAuditItem> {
    if (!this.hasGradeInputPermission()) {
      return this.rejectUnauthorized();
    }
    if (!entries || entries.length === 0) {
      return this.reject('请先填写分数');
    }
    for (let i = 0; i < entries.length; i++) {
      const score = entries[i].score;
      if (!Number.isFinite(score) || score < 0 || score > 100) {
        return this.reject('分数需为 0-100 的数字');
      }
    }
    if (AppConfig.useRemote) {
      try {
        const remote = await RemoteApi.adminSubmitGradeScores(taskId, entries);
        return this.delayCopy<GradeAuditItem>(AdminLogic.remoteToGradeTask(remote));
      } catch (e) {
        return this.reject((e instanceof Error) ? e.message : String(e));
      }
    }
    return this.reject('按学生打分为联机功能，请在联机模式下使用');
  }

  async inputGrade(payload: GradeInputPayload): Promise<GradeAuditItem> {
    if (!this.hasGradeInputPermission()) {
      return this.rejectUnauthorized();
    }
    if (AppConfig.useRemote) {
      try {
        const remote = await RemoteApi.adminGradeInput(payload.id, payload.inputProgress);
        return this.delayCopy<GradeAuditItem>(AdminLogic.remoteToGradeTask(remote));
      } catch (e) {
        return this.reject((e instanceof Error) ? e.message : String(e));
      }
    }
    if (!AdminLogic.isValidInputProgress(payload.inputProgress)) {
      return this.reject('录入进度需为 0-100 的整数');
    }
    const grades = await this.getGradeItems();
    const target = grades.find((g) => g.id === payload.id);
    if (!target) {
      return this.reject('成绩记录不存在', 'notFound');
    }
    if (!AdminLogic.canInputGradeStatus(target.status)) {
      return this.reject('当前状态不可录入');
    }
    const nextStatus = AdminLogic.toGradeStatusByProgress(payload.inputProgress);
    const updated: GradeAuditItem = {
      id: target.id,
      courseName: target.courseName,
      teachingClassName: target.teachingClassName,
      teacherName: target.teacherName,
      inputProgress: payload.inputProgress,
      status: nextStatus,
      updatedAt: new Date().toISOString()
    };
    const next = grades.map((item) => item.id === payload.id ? updated : item);
    await this.saveGrades(next);
    // RDB 就绪时同步 grade_tasks 状态
    if (AppDatabase.isReady()) {
      await AdminRdbStore.updateGradeTaskStatusInRdb(payload.id, nextStatus).catch((err: Object) => {
        const msg = err instanceof Error ? err.message : String(err);
        console.warn(`[AdminRepository] updateGradeTaskStatusInRdb failed: ${msg}`);
      });
    }
    return this.delayCopy<GradeAuditItem>(updated);
  }

  async updateGradeInput(payload: GradeInputPayload): Promise<GradeAuditItem> {
    return this.inputGrade(payload);
  }

  async rejectGrade(payload: GradeRejectPayload): Promise<boolean> {
    if (!this.hasGradePermission('approve')) {
      return this.rejectUnauthorized();
    }
    if (AppConfig.useRemote) {
      try {
        await RemoteApi.adminGradeReject(payload.id, payload.reason);
        return this.delay<boolean>(true);
      } catch (e) {
        return this.reject((e instanceof Error) ? e.message : String(e));
      }
    }
    const normalizedReason = AdminLogic.normalizeRejectReason(payload.reason);
    const reasonError = AdminLogic.validateRejectReason(normalizedReason);
    if (reasonError.length > 0) {
      return this.reject(reasonError);
    }
    const grades = await this.getGradeItems();
    const target = grades.find((g) => g.id === payload.id);
    if (!target) {
      return this.reject('成绩记录不存在', 'notFound');
    }
    if (target.status !== 'pendingAudit') {
      return this.reject('当前状态不可驳回');
    }
    const next = grades.map((item) => {
      if (item.id !== payload.id) {
        return item;
      }
      const updated: GradeAuditItem = {
        id: item.id,
        courseName: item.courseName,
        teachingClassName: item.teachingClassName,
        teacherName: item.teacherName,
        inputProgress: item.inputProgress,
        status: 'rejected',
        updatedAt: new Date().toISOString(),
        rejectReason: normalizedReason
      };
      return updated;
    });
    await this.saveGrades(next);
    // RDB 就绪时同步 grade_tasks 状态（含驳回理由）
    if (AppDatabase.isReady()) {
      await AdminRdbStore.updateGradeTaskStatusInRdb(payload.id, 'rejected', normalizedReason).catch((err: Object) => {
        const msg = err instanceof Error ? err.message : String(err);
        console.warn(`[AdminRepository] updateGradeTaskStatusInRdb(reject) failed: ${msg}`);
      });
    }
    return this.delay<boolean>(true);
  }

  async publishNotice(draft: NoticeDraft): Promise<boolean> {
    if (!this.hasAdminPermission('notices.publish', 'publish')) {
      return this.rejectUnauthorized();
    }
    if (!draft.title.trim() || !draft.content.trim()) {
      return this.reject('标题和正文不能为空');
    }
    if (draft.receiverScope.length === 0 && draft.receiverType === 'custom') {
      return this.reject('请选择接收范围');
    }
    if (AppConfig.useRemote) {
      try {
        await RemoteApi.adminPublishNotice(draft.title, draft.content, draft.publisher, draft.category, draft.urgency, draft.receiverType, draft.receiverScope);
        return this.delay<boolean>(true);
      } catch (e) {
        return this.reject((e instanceof Error) ? e.message : String(e));
      }
    }
    await NoticeStore.publish(draft);
    return this.delay<boolean>(true);
  }

  async getEvaluationStats(): Promise<EvaluationStats> {
    return this.delayCopy<EvaluationStats>(mockEvaluationStats);
  }

  async getApprovals(status?: ApprovalStatus | '全部'): Promise<ApprovalItem[]> {
    if (AppConfig.useRemote) {
      try {
        const remote = await RemoteApi.adminListApprovals(status);
        return this.delayCopy<ApprovalItem[]>(remote.map((a) => AdminLogic.remoteToApproval(a)));
      } catch (e) {
        // 远程失败：remote 模式禁止静默回退时直接抛错，交由页面错误态呈现
        if (!AppConfig.allowMockFallbackInRemote) {
          throw new Error('远程服务异常，请稍后重试');
        }
        // 否则回退本地
      }
    }
    let items = await this.getApprovalItems();
    if (status && status !== '全部') {
      items = items.filter((a) => a.status === status);
    }
    return this.delayCopy<ApprovalItem[]>(items);
  }

  async getApprovalDetail(id: string): Promise<ApprovalDetail> {
    const approvals = await this.getApprovalItems();
    const head = approvals.find((a) => a.id === id);
    if (!head) {
      return this.reject('审批记录不存在', 'notFound');
    }
    const detail = mockApprovalDetail;
    const fallback: ApprovalDetail = JSON.parse(JSON.stringify(detail)) as ApprovalDetail;
    fallback.id = head.id;
    fallback.type = head.type;
    fallback.applicantName = head.applicantName;
    fallback.applicantId = head.applicantId;
    fallback.title = head.title;
    fallback.reason = head.reason;
    fallback.status = head.status;
    fallback.isUrgent = head.isUrgent;
    fallback.submittedAt = head.submittedAt;
    return this.delay<ApprovalDetail>(fallback);
  }

  async approve(id: string, comment: string): Promise<boolean> {
    if (!this.hasApprovalPermission('approve')) {
      return this.rejectUnauthorized();
    }
    if (!comment.trim()) {
      return this.reject('请填写审批意见');
    }
    if (AppConfig.useRemote) {
      try {
        await RemoteApi.adminApprove(id, comment.trim());
        return this.delay<boolean>(true);
      } catch (e) {
        return this.reject((e instanceof Error) ? e.message : String(e));
      }
    }
    const approvals = await this.getApprovalItems();
    const target = approvals.find((a) => a.id === id);
    if (!target) {
      return this.reject('审批记录不存在', 'notFound');
    }
    if (target.status !== 'pending') {
      return this.reject('当前状态不可操作');
    }
    const next = approvals.map((item) => {
      if (item.id !== id) {
        return item;
      }
      const updated: ApprovalItem = {
        id: item.id,
        type: item.type,
        applicantName: item.applicantName,
        applicantId: item.applicantId,
        title: item.title,
        reason: item.reason,
        status: 'approved',
        isUrgent: item.isUrgent,
        submittedAt: item.submittedAt
      };
      return updated;
    });
    if (AppDatabase.isReady() && id.indexOf('ap-lv-') === 0) {
      await AdminRdbStore.saveApprovalStatusToRdb(id, 'approved', comment.trim());
    } else {
      await this.saveApprovals(next);
    }
    await this.updateLinkedLeave(id, 'approved', comment.trim());
    return this.delay<boolean>(true);
  }

  async rejectApproval(id: string, comment: string): Promise<boolean> {
    if (!this.hasApprovalPermission('approve')) {
      return this.rejectUnauthorized();
    }
    if (!comment.trim()) {
      return this.reject('请填写驳回意见');
    }
    if (AppConfig.useRemote) {
      try {
        await RemoteApi.adminReject(id, comment.trim());
        return this.delay<boolean>(true);
      } catch (e) {
        return this.reject((e instanceof Error) ? e.message : String(e));
      }
    }
    const approvals = await this.getApprovalItems();
    const target = approvals.find((a) => a.id === id);
    if (!target) {
      return this.reject('审批记录不存在', 'notFound');
    }
    if (target.status !== 'pending') {
      return this.reject('当前状态不可操作');
    }
    const next = approvals.map((item) => {
      if (item.id !== id) {
        return item;
      }
      const updated: ApprovalItem = {
        id: item.id,
        type: item.type,
        applicantName: item.applicantName,
        applicantId: item.applicantId,
        title: item.title,
        reason: item.reason,
        status: 'rejected',
        isUrgent: item.isUrgent,
        submittedAt: item.submittedAt
      };
      return updated;
    });
    if (AppDatabase.isReady() && id.indexOf('ap-lv-') === 0) {
      await AdminRdbStore.saveApprovalStatusToRdb(id, 'rejected', comment.trim());
    } else {
      await this.saveApprovals(next);
    }
    await this.updateLinkedLeave(id, 'rejected', comment.trim());
    return this.delay<boolean>(true);
  }
}
