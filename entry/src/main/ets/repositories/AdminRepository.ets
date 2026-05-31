// 管理端仓储

import { BaseRepository } from './BaseRepository';
import {
  AdminDashboardSummary, StudentAdminItem, AdminCourseItem, AdminCourseWritePayload, SelectionRound,
  GradeAuditItem, GradeInputPayload, GradeRejectPayload, NoticeDraft, EvaluationStats, ApprovalItem, ApprovalDetail, ApprovalStatus,
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

const KEY_ADMIN_APPROVALS = 'local.adminApprovals.v1';
const KEY_ADMIN_GRADES = 'local.adminGrades.v1';
const KEY_ADMIN_COURSES = 'local.adminCourses.v1';
const KEY_LOCAL_LEAVES = 'local.leaveRequests.v1';
const COURSE_CATEGORIES: string[] = ['required', 'elective', 'public', 'practice'];
const COURSE_STATUSES: string[] = ['draft', 'open', 'closed', 'archived'];
const GRADE_STATUSES: string[] = ['pendingAudit', 'inputting', 'published', 'appealed', 'rejected'];
const COURSE_CODE_PATTERN: RegExp = /^[A-Za-z0-9_-]{2,32}$/;
const CONTROL_CHAR_PATTERN: RegExp = /[\r\n\u0000-\u001f\u007f]/;

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
      this.approvals = this.mergeApprovalItems(this.mergeApprovalItems(rdbItems, stored), mockApprovals);
      this.isApprovalsLoaded = true;
      return this.approvals;
    }
    const stored = await LocalDataStore.loadArray<ApprovalItem>(KEY_ADMIN_APPROVALS, []);
    this.approvals = this.mergeApprovalItems(stored, mockApprovals);
    this.isApprovalsLoaded = true;
    return this.approvals;
  }

  private async getGradeItems(): Promise<GradeAuditItem[]> {
    if (!this.isGradesLoaded) {
      const stored = await LocalDataStore.loadArray<GradeAuditItem>(KEY_ADMIN_GRADES, mockGradeAudits);
      const sanitized = this.sanitizeGradeItems(stored);
      this.grades = sanitized.length > 0 ? sanitized : JSON.parse(JSON.stringify(mockGradeAudits)) as GradeAuditItem[];
      this.isGradesLoaded = true;
    }
    return this.grades;
  }

  private async getCourseItems(): Promise<AdminCourseItem[]> {
    if (!this.isCoursesLoaded) {
      const stored = await LocalDataStore.loadArray<AdminCourseItem>(KEY_ADMIN_COURSES, mockAdminCourses);
      const sanitized = this.sanitizeCourseItems(stored);
      this.courses = sanitized.length > 0 ? sanitized : JSON.parse(JSON.stringify(mockAdminCourses)) as AdminCourseItem[];
      this.isCoursesLoaded = true;
    }
    return this.courses;
  }

  private async saveCourses(next: AdminCourseItem[]): Promise<void> {
    this.courses = next;
    this.isCoursesLoaded = true;
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

  private isAllowedCourseCategory(value: string): boolean {
    return COURSE_CATEGORIES.indexOf(value) >= 0;
  }

  private isAllowedCourseStatus(value: string): boolean {
    return COURSE_STATUSES.indexOf(value) >= 0;
  }

  private isAllowedGradeStatus(value: string): boolean {
    return GRADE_STATUSES.indexOf(value) >= 0;
  }

  private shouldHaveCompleteGradeInput(status: string): boolean {
    return status === 'pendingAudit' || status === 'published' || status === 'rejected' || status === 'appealed';
  }

  private isValidRejectReason(value: string | undefined): boolean {
    return value !== undefined && this.isCleanText(value, 1, 120);
  }

  private isFiniteNumber(value: number): boolean {
    return typeof value === 'number' && value === value && value !== Infinity && value !== -Infinity;
  }

  private hasOneDecimalAtMost(value: number): boolean {
    return Math.round(value * 10) === value * 10;
  }

  private isCleanText(value: string, min: number, max: number): boolean {
    if (typeof value !== 'string') {
      return false;
    }
    const text = value.trim();
    return text.length >= min && text.length <= max && !CONTROL_CHAR_PATTERN.test(text);
  }

  private isValidStoredCourse(item: AdminCourseItem): boolean {
    if (!item || typeof item !== 'object') {
      return false;
    }
    if (!this.isCleanText(item.id, 1, 64)) {
      return false;
    }
    if (typeof item.code !== 'string' || !COURSE_CODE_PATTERN.test(item.code.trim())) {
      return false;
    }
    if (!this.isCleanText(item.name, 1, 64) || !this.isCleanText(item.teacher, 1, 32) || !this.isCleanText(item.timeText, 1, 80)) {
      return false;
    }
    if (!this.isAllowedCourseCategory(item.category) || !this.isAllowedCourseStatus(item.status)) {
      return false;
    }
    if (!this.isFiniteNumber(item.credit) || item.credit <= 0 || item.credit > 20 || !this.hasOneDecimalAtMost(item.credit)) {
      return false;
    }
    if (!this.isFiniteNumber(item.capacity) || Math.floor(item.capacity) !== item.capacity || item.capacity < 1 || item.capacity > 10000) {
      return false;
    }
    if (!this.isFiniteNumber(item.selectedCount) || Math.floor(item.selectedCount) !== item.selectedCount || item.selectedCount < 0 || item.selectedCount > item.capacity) {
      return false;
    }
    return true;
  }

  private sanitizeCourseItems(items: AdminCourseItem[]): AdminCourseItem[] {
    return items.filter((item) => this.isValidStoredCourse(item)).map((item) => {
      const sanitized: AdminCourseItem = {
        id: item.id.trim(),
        code: item.code.trim(),
        name: item.name.trim(),
        teacher: item.teacher.trim(),
        category: item.category,
        credit: item.credit,
        timeText: item.timeText.trim(),
        capacity: item.capacity,
        selectedCount: item.selectedCount,
        status: item.status
      };
      return sanitized;
    });
  }

  private isValidStoredGrade(item: GradeAuditItem): boolean {
    if (!item || typeof item !== 'object') {
      return false;
    }
    if (!this.isCleanText(item.id, 1, 64)) {
      return false;
    }
    if (!this.isCleanText(item.courseName, 1, 80) || !this.isCleanText(item.teachingClassName, 1, 80) || !this.isCleanText(item.teacherName, 1, 32)) {
      return false;
    }
    if (!this.isCleanText(item.updatedAt, 1, 40)) {
      return false;
    }
    if (!this.isValidInputProgress(item.inputProgress) || !this.isAllowedGradeStatus(item.status)) {
      return false;
    }
    if (this.shouldHaveCompleteGradeInput(item.status) && item.inputProgress !== 100) {
      return false;
    }
    if (item.status === 'rejected' && !this.isValidRejectReason(item.rejectReason)) {
      return false;
    }
    return true;
  }

  private sanitizeGradeItems(items: GradeAuditItem[]): GradeAuditItem[] {
    const ids: string[] = [];
    const sanitized: GradeAuditItem[] = [];
    items.forEach((item) => {
      if (!this.isValidStoredGrade(item)) {
        return;
      }
      const id = item.id.trim();
      if (ids.indexOf(id) >= 0) {
        return;
      }
      ids.push(id);
      const next: GradeAuditItem = {
        id: id,
        courseName: item.courseName.trim(),
        teachingClassName: item.teachingClassName.trim(),
        teacherName: item.teacherName.trim(),
        inputProgress: item.inputProgress,
        status: item.status,
        updatedAt: item.updatedAt.trim()
      };
      const rejectReason = item.rejectReason;
      if (item.status === 'rejected' && rejectReason !== undefined && this.isValidRejectReason(rejectReason)) {
        next.rejectReason = rejectReason.trim();
      }
      sanitized.push(next);
    });
    return sanitized;
  }

  private isValidInputProgress(value: number): boolean {
    return this.isFiniteNumber(value) && Math.floor(value) === value && value >= 0 && value <= 100;
  }

  private normalizeRejectReason(reason: string): string {
    return reason.trim();
  }

  private validateRejectReason(reason: string): string {
    if (!this.isCleanText(reason, 1, 120)) {
      return '驳回理由需为 1-120 字且不能包含换行或控制字符';
    }
    return '';
  }

  private canInputGradeStatus(status: string): boolean {
    return status === 'inputting' || status === 'rejected' || status === 'appealed';
  }

  private toGradeStatusByProgress(inputProgress: number): 'inputting' | 'pendingAudit' {
    return inputProgress === 100 ? 'pendingAudit' : 'inputting';
  }

  private validateCoursePayload(payload: AdminCourseWritePayload, items: AdminCourseItem[], editingId?: string): string {
    const code = payload.code.trim();
    const name = payload.name.trim();
    const teacher = payload.teacher.trim();
    const timeText = payload.timeText.trim();
    if (!COURSE_CODE_PATTERN.test(code)) {
      return '课程代码需为 2-32 位字母、数字、下划线或短横线';
    }
    if (!this.isCleanText(name, 1, 64)) {
      return '课程名称需为 1-64 字且不能包含换行或控制字符';
    }
    if (!this.isCleanText(teacher, 1, 32)) {
      return '教师需为 1-32 字且不能包含换行或控制字符';
    }
    if (!this.isCleanText(timeText, 1, 80)) {
      return '上课时间需为 1-80 字且不能包含换行或控制字符';
    }
    if (!this.isAllowedCourseCategory(payload.category)) {
      return '课程类型不合法';
    }
    if (!this.isAllowedCourseStatus(payload.status)) {
      return '课程状态不合法';
    }
    if (!this.isFiniteNumber(payload.credit) || payload.credit <= 0 || payload.credit > 20 || !this.hasOneDecimalAtMost(payload.credit)) {
      return '学分需大于 0 且不超过 20，最多一位小数';
    }
    if (!this.isFiniteNumber(payload.capacity) || Math.floor(payload.capacity) !== payload.capacity || payload.capacity < 1 || payload.capacity > 10000) {
      return '容量需为 1-10000 的整数';
    }
    if (!this.isFiniteNumber(payload.selectedCount) || Math.floor(payload.selectedCount) !== payload.selectedCount || payload.selectedCount < 0 || payload.selectedCount > payload.capacity) {
      return '已选人数需为 0 到容量之间的整数';
    }
    const duplicated = items.some((item) => item.id !== editingId && item.code.toLowerCase() === code.toLowerCase());
    if (duplicated) {
      return '课程代码已存在';
    }
    const hasTeacherConflict = items.some((item) => item.id !== editingId && item.teacher.trim() === teacher && item.timeText.trim() === timeText);
    if (hasTeacherConflict) {
      return '同一教师在该时间已有课程';
    }
    return '';
  }

  private normalizeCoursePayload(payload: AdminCourseWritePayload): AdminCourseWritePayload {
    return {
      code: payload.code.trim(),
      name: payload.name.trim(),
      teacher: payload.teacher.trim(),
      category: payload.category,
      credit: payload.credit,
      timeText: payload.timeText.trim(),
      capacity: payload.capacity,
      selectedCount: payload.selectedCount,
      status: payload.status
    };
  }

  private mergeApprovalItems(localItems: ApprovalItem[], seedItems: ApprovalItem[]): ApprovalItem[] {
    const result: ApprovalItem[] = JSON.parse(JSON.stringify(localItems)) as ApprovalItem[];
    seedItems.forEach((item) => {
      const exists = result.some((cur) => cur.id === item.id);
      if (!exists) {
        result.push(item);
      }
    });
    return result;
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
    const sanitized = this.sanitizeGradeItems(next);
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
    const normalized = this.normalizeCoursePayload(payload);
    const error = this.validateCoursePayload(normalized, items);
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
    const normalized = this.normalizeCoursePayload(payload);
    const error = this.validateCoursePayload(normalized, items, id);
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
    return this.delay<boolean>(true);
  }

  async inputGrade(payload: GradeInputPayload): Promise<GradeAuditItem> {
    if (!this.hasGradeInputPermission()) {
      return this.rejectUnauthorized();
    }
    if (!this.isValidInputProgress(payload.inputProgress)) {
      return this.reject('录入进度需为 0-100 的整数');
    }
    const grades = await this.getGradeItems();
    const target = grades.find((g) => g.id === payload.id);
    if (!target) {
      return this.reject('成绩记录不存在', 'notFound');
    }
    if (!this.canInputGradeStatus(target.status)) {
      return this.reject('当前状态不可录入');
    }
    const nextStatus = this.toGradeStatusByProgress(payload.inputProgress);
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
    return this.delayCopy<GradeAuditItem>(updated);
  }

  async updateGradeInput(payload: GradeInputPayload): Promise<GradeAuditItem> {
    return this.inputGrade(payload);
  }

  async rejectGrade(payload: GradeRejectPayload): Promise<boolean> {
    if (!this.hasGradePermission('approve')) {
      return this.rejectUnauthorized();
    }
    const normalizedReason = this.normalizeRejectReason(payload.reason);
    const reasonError = this.validateRejectReason(normalizedReason);
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
    await NoticeStore.publish(draft);
    return this.delay<boolean>(true);
  }

  async getEvaluationStats(): Promise<EvaluationStats> {
    return this.delayCopy<EvaluationStats>(mockEvaluationStats);
  }

  async getApprovals(status?: ApprovalStatus | '全部'): Promise<ApprovalItem[]> {
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
