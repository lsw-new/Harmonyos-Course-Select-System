// 管理端仓储

import { BaseRepository } from './BaseRepository';
import {
  AdminDashboardSummary, StudentAdminItem, AdminCourseItem, AdminCourseWritePayload, SelectionRound,
  GradeAuditItem, GradeAuditStatus, GradeInputPayload, GradeRejectPayload, NoticeDraft, EvaluationStats, ApprovalItem, ApprovalDetail, ApprovalStatus,
  AdminPermissionAction, AdminCourseCategory, AdminCourseStatus
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
import { RemoteApi } from '../common/remote/RemoteApi';
import { AdminLogic } from './AdminLogic';

const KEY_ADMIN_APPROVALS = 'local.adminApprovals.v1';
const KEY_ADMIN_GRADES = 'local.adminGrades.v1';
const KEY_ADMIN_COURSES = 'local.adminCourses.v1';
const SEED_COURSES_FLAG = 'seed.courses.v1';
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
      const rdbItems = await this.getApprovalItemsFromRdb();
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
      const rdbItems = await this.loadGradeTasksFromRdb();
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

  // 从 grade_tasks 表加载成绩审核任务列表
  private async loadGradeTasksFromRdb(): Promise<GradeAuditItem[]> {
    const resultSet = await AppDatabase.query(
      `SELECT
         gt.task_id,
         COALESCE(c.name, '') AS course_name,
         COALESCE(gt.teaching_class_name, '') AS teaching_class_name,
         COALESCE(gt.teacher_name, '') AS teacher_name,
         gt.input_progress,
         gt.status,
         gt.updated_at,
         COALESCE(gt.reject_reason, '') AS reject_reason
       FROM grade_tasks gt
       LEFT JOIN courses c ON c.course_id = gt.course_id
       ORDER BY gt.updated_at DESC`
    );
    const items: GradeAuditItem[] = [];
    try {
      while (resultSet.goToNextRow()) {
        const status = resultSet.getString(resultSet.getColumnIndex('status')) as GradeAuditStatus;
        const rejectReason = resultSet.getString(resultSet.getColumnIndex('reject_reason'));
        const item: GradeAuditItem = {
          id: resultSet.getString(resultSet.getColumnIndex('task_id')),
          courseName: resultSet.getString(resultSet.getColumnIndex('course_name')),
          teachingClassName: resultSet.getString(resultSet.getColumnIndex('teaching_class_name')),
          teacherName: resultSet.getString(resultSet.getColumnIndex('teacher_name')),
          inputProgress: resultSet.getLong(resultSet.getColumnIndex('input_progress')),
          status: status,
          updatedAt: resultSet.getString(resultSet.getColumnIndex('updated_at'))
        };
        if (status === 'rejected' && rejectReason.length > 0) {
          item.rejectReason = rejectReason;
        }
        items.push(item);
      }
    } finally {
      resultSet.close();
    }
    return items;
  }


  // approve 时：若 RDB 就绪，尝试批量将该任务关联课程的所有选课学生的成绩行置为 published
  private async publishGradesToRdb(taskId: string): Promise<void> {
    // 1. 从 grade_tasks 找 course_id
    const taskResultSet = await AppDatabase.query(
      `SELECT course_id FROM grade_tasks WHERE task_id = ${AppDatabase.sqlText(taskId)} LIMIT 1`
    );
    let courseId = '';
    try {
      if (taskResultSet.goToNextRow()) {
        courseId = taskResultSet.getString(taskResultSet.getColumnIndex('course_id'));
      }
    } finally {
      taskResultSet.close();
    }
    if (courseId.length === 0) {
      // grade_tasks 中无此任务或无 course_id，跳过 grades 写入
      return;
    }
    // 2. 更新 grade_tasks 状态
    await AppDatabase.execute(
      `UPDATE grade_tasks SET status = 'published', updated_at = CURRENT_TIMESTAMP WHERE task_id = ${AppDatabase.sqlText(taskId)}`
    );
    // 3. 将该课程下所有 grades 行置为 published（若存在）
    await AppDatabase.execute(
      `UPDATE grades SET status = 'published', published_at = CURRENT_TIMESTAMP WHERE course_id = ${AppDatabase.sqlText(courseId)} AND status != 'published'`
    );
  }

  // 更新 grade_tasks 表状态（用于 inputGrade / rejectGrade）
  private async updateGradeTaskStatusInRdb(taskId: string, status: string, rejectReason?: string): Promise<void> {
    const taskResultSet = await AppDatabase.query(
      `SELECT task_id FROM grade_tasks WHERE task_id = ${AppDatabase.sqlText(taskId)} LIMIT 1`
    );
    let exists = false;
    try {
      exists = taskResultSet.goToNextRow();
    } finally {
      taskResultSet.close();
    }
    if (!exists) {
      return;
    }
    const reasonSql = rejectReason !== undefined
      ? `, reject_reason = ${AppDatabase.sqlText(rejectReason)}`
      : '';
    await AppDatabase.execute(
      `UPDATE grade_tasks SET status = ${AppDatabase.sqlText(status)}, updated_at = CURRENT_TIMESTAMP${reasonSql} WHERE task_id = ${AppDatabase.sqlText(taskId)}`
    );
  }

  private async getCourseItems(): Promise<AdminCourseItem[]> {
    if (AppDatabase.isReady()) {
      await this.seedCoursesIfNeeded();
      const rdbItems = await this.loadCoursesFromRdb();
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
      await this.saveCoursesToRdb(next);
      return;
    }
    await LocalDataStore.saveArray<AdminCourseItem>(KEY_ADMIN_COURSES, next);
  }

  // ============ 课程 RDB 持久化（AppDatabase 就绪时启用，否则回退 Preferences） ============

  // 首次进入 RDB 模式时把内置课程灌入 courses 表，并用 app_meta 标记，避免删空后又被重新种子。
  private async seedCoursesIfNeeded(): Promise<void> {
    const resultSet = await AppDatabase.query(
      `SELECT value FROM app_meta WHERE key = ${AppDatabase.sqlText(SEED_COURSES_FLAG)} LIMIT 1`
    );
    let seeded = false;
    try {
      seeded = resultSet.goToNextRow();
    } finally {
      resultSet.close();
    }
    if (seeded) {
      return;
    }
    const seed = JSON.parse(JSON.stringify(mockAdminCourses)) as AdminCourseItem[];
    for (let i = 0; i < seed.length; i++) {
      await this.upsertCourseToRdb(seed[i]);
    }
    await AppDatabase.execute(
      `INSERT OR REPLACE INTO app_meta (key, value, updated_at) VALUES (${AppDatabase.sqlText(SEED_COURSES_FLAG)}, '1', CURRENT_TIMESTAMP)`
    );
  }

  private async loadCoursesFromRdb(): Promise<AdminCourseItem[]> {
    const resultSet = await AppDatabase.query(
      `SELECT course_id, code, name, teacher, category, credit, COALESCE(time_text, '') AS time_text, capacity, selected_count, status
       FROM courses ORDER BY created_at DESC`
    );
    const items: AdminCourseItem[] = [];
    try {
      while (resultSet.goToNextRow()) {
        const item: AdminCourseItem = {
          id: resultSet.getString(resultSet.getColumnIndex('course_id')),
          code: resultSet.getString(resultSet.getColumnIndex('code')),
          name: resultSet.getString(resultSet.getColumnIndex('name')),
          teacher: resultSet.getString(resultSet.getColumnIndex('teacher')),
          category: resultSet.getString(resultSet.getColumnIndex('category')) as AdminCourseCategory,
          credit: resultSet.getDouble(resultSet.getColumnIndex('credit')),
          timeText: resultSet.getString(resultSet.getColumnIndex('time_text')),
          capacity: resultSet.getLong(resultSet.getColumnIndex('capacity')),
          selectedCount: resultSet.getLong(resultSet.getColumnIndex('selected_count')),
          status: resultSet.getString(resultSet.getColumnIndex('status')) as AdminCourseStatus
        };
        items.push(item);
      }
    } finally {
      resultSet.close();
    }
    return items;
  }

  private async upsertCourseToRdb(item: AdminCourseItem): Promise<void> {
    await AppDatabase.execute(
      `INSERT INTO courses (course_id, code, name, category, credit, teacher, capacity, selected_count, time_text, status, updated_at)
       VALUES (${AppDatabase.sqlText(item.id)}, ${AppDatabase.sqlText(item.code)}, ${AppDatabase.sqlText(item.name)}, ${AppDatabase.sqlText(item.category)}, ${item.credit}, ${AppDatabase.sqlText(item.teacher)}, ${item.capacity}, ${item.selectedCount}, ${AppDatabase.sqlText(item.timeText)}, ${AppDatabase.sqlText(item.status)}, CURRENT_TIMESTAMP)
       ON CONFLICT(course_id) DO UPDATE SET
         code = excluded.code, name = excluded.name, category = excluded.category, credit = excluded.credit,
         teacher = excluded.teacher, capacity = excluded.capacity, selected_count = excluded.selected_count,
         time_text = excluded.time_text, status = excluded.status, updated_at = CURRENT_TIMESTAMP`
    );
  }

  // 全量写回：逐条 UPSERT（按 course_id 原地更新，不触发 selections 外键删除），再删除 next 中不存在的课程（被删课程已校验无人选）。
  private async saveCoursesToRdb(next: AdminCourseItem[]): Promise<void> {
    for (let i = 0; i < next.length; i++) {
      await this.upsertCourseToRdb(next[i]);
    }
    if (next.length > 0) {
      const keepIds = next.map((c) => AppDatabase.sqlText(c.id)).join(', ');
      await AppDatabase.execute(`DELETE FROM courses WHERE course_id NOT IN (${keepIds})`);
    } else {
      await AppDatabase.execute('DELETE FROM courses');
    }
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


  private async getApprovalItemsFromRdb(): Promise<ApprovalItem[]> {
    const resultSet = await AppDatabase.query(
      `SELECT
        ai.approval_id,
        ai.biz_type,
        COALESCE(sp.name, ai.applicant_id, '') AS applicant_name,
        COALESCE(ai.applicant_id, '') AS applicant_id,
        ai.title,
        COALESCE(ai.reason, '') AS reason,
        ai.status,
        CASE WHEN ai.is_urgent = 1 THEN 'true' ELSE 'false' END AS is_urgent,
        ai.submitted_at
       FROM approval_instances ai
       LEFT JOIN student_profiles sp ON sp.student_id = ai.applicant_id
       ORDER BY ai.submitted_at DESC`
    );
    const items: ApprovalItem[] = [];
    try {
      while (resultSet.goToNextRow()) {
        const item: ApprovalItem = {
          id: resultSet.getString(resultSet.getColumnIndex('approval_id')),
          type: resultSet.getString(resultSet.getColumnIndex('biz_type')) === 'leave' ? '\u8bf7\u5047' : resultSet.getString(resultSet.getColumnIndex('biz_type')),
          applicantName: resultSet.getString(resultSet.getColumnIndex('applicant_name')),
          applicantId: resultSet.getString(resultSet.getColumnIndex('applicant_id')),
          title: resultSet.getString(resultSet.getColumnIndex('title')),
          reason: resultSet.getString(resultSet.getColumnIndex('reason')),
          status: resultSet.getString(resultSet.getColumnIndex('status')) as ApprovalStatus,
          isUrgent: resultSet.getString(resultSet.getColumnIndex('is_urgent')) === 'true',
          submittedAt: resultSet.getString(resultSet.getColumnIndex('submitted_at'))
        };
        items.push(item);
      }
    } finally {
      resultSet.close();
    }
    return items;
  }

  private async saveApprovals(next: ApprovalItem[]): Promise<void> {
    this.approvals = next;
    this.isApprovalsLoaded = true;
    await LocalDataStore.saveArray<ApprovalItem>(KEY_ADMIN_APPROVALS, next);
  }

  private async saveApprovalStatusToRdb(id: string, status: ApprovalStatus, comment: string): Promise<void> {
    await AppDatabase.execute(
      `UPDATE approval_instances
       SET status = ${AppDatabase.sqlText(status)}, updated_at = CURRENT_TIMESTAMP
       WHERE approval_id = ${AppDatabase.sqlText(id)}`
    );
    await AppDatabase.execute(
      `UPDATE approval_steps
       SET status = ${AppDatabase.sqlText(status)}, comment = ${AppDatabase.sqlText(comment)}, handled_at = CURRENT_TIMESTAMP
       WHERE approval_id = ${AppDatabase.sqlText(id)} AND step_order = 1`
    );
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

  async getCourses(query?: string, category?: string): Promise<AdminCourseItem[]> {
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

  async getSelectionRounds(): Promise<SelectionRound[]> {
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
      await this.publishGradesToRdb(id).catch((err: Object) => {
        const msg = err instanceof Error ? err.message : String(err);
        // 非阻断：RDB 写入失败不影响 LocalDataStore 已保存的状态
        console.warn(`[AdminRepository] publishGradesToRdb failed: ${msg}`);
      });
    }
    return this.delay<boolean>(true);
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
      await this.updateGradeTaskStatusInRdb(payload.id, nextStatus).catch((err: Object) => {
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
      await this.updateGradeTaskStatusInRdb(payload.id, 'rejected', normalizedReason).catch((err: Object) => {
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
      await this.saveApprovalStatusToRdb(id, 'approved', comment.trim());
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
      await this.saveApprovalStatusToRdb(id, 'rejected', comment.trim());
    } else {
      await this.saveApprovals(next);
    }
    await this.updateLinkedLeave(id, 'rejected', comment.trim());
    return this.delay<boolean>(true);
  }
}
