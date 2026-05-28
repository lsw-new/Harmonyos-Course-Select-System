// 管理端仓储

import { BaseRepository } from './BaseRepository';
import {
  AdminDashboardSummary, StudentAdminItem, AdminCourseItem, SelectionRound,
  GradeAuditItem, NoticeDraft, EvaluationStats, ApprovalItem, ApprovalDetail, ApprovalStatus
} from '../models/Admin';
import {
  mockAdminDashboard, mockAdminStudents, mockAdminCourses, mockSelectionRounds,
  mockGradeAudits, mockEvaluationStats, mockApprovals, mockApprovalDetail
} from '../mock/mockAdmin';

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

  async getDashboard(): Promise<AdminDashboardSummary> {
    return this.delayCopy<AdminDashboardSummary>(mockAdminDashboard);
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
    let items = mockAdminCourses;
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

  async getSelectionRounds(): Promise<SelectionRound[]> {
    return this.delayCopy<SelectionRound[]>(mockSelectionRounds);
  }

  async getGradeAudits(status?: string): Promise<GradeAuditItem[]> {
    let items = this.grades;
    if (status && status !== '全部') {
      items = items.filter((g) => g.status === status);
    }
    return this.delayCopy<GradeAuditItem[]>(items);
  }

  async approveGrade(id: string): Promise<boolean> {
    const target = this.grades.find((g) => g.id === id);
    if (!target) {
      return this.reject('成绩记录不存在', 'notFound');
    }
    if (target.status !== 'pendingAudit') {
      return this.reject('当前状态不可审核');
    }
    target.status = 'published';
    return this.delay<boolean>(true);
  }

  async publishNotice(draft: NoticeDraft): Promise<boolean> {
    if (!draft.title || !draft.content) {
      return this.reject('标题和正文不能为空');
    }
    if (draft.receiverScope.length === 0 && draft.receiverType === 'custom') {
      return this.reject('请选择接收范围');
    }
    return this.delay<boolean>(true);
  }

  async getEvaluationStats(): Promise<EvaluationStats> {
    return this.delayCopy<EvaluationStats>(mockEvaluationStats);
  }

  async getApprovals(status?: ApprovalStatus | '全部'): Promise<ApprovalItem[]> {
    let items = this.approvals;
    if (status && status !== '全部') {
      items = items.filter((a) => a.status === status);
    }
    return this.delayCopy<ApprovalItem[]>(items);
  }

  async getApprovalDetail(id: string): Promise<ApprovalDetail> {
    const detail = mockApprovalDetail;
    if (id !== detail.id) {
      const fallback: ApprovalDetail = JSON.parse(JSON.stringify(detail)) as ApprovalDetail;
      const head = this.approvals.find((a) => a.id === id);
      if (!head) {
        return this.reject('审批记录不存在', 'notFound');
      }
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
    return this.delayCopy<ApprovalDetail>(detail);
  }

  async approve(id: string, comment: string): Promise<boolean> {
    if (!comment.trim()) {
      return this.reject('请填写审批意见');
    }
    const target = this.approvals.find((a) => a.id === id);
    if (!target) {
      return this.reject('审批记录不存在', 'notFound');
    }
    if (target.status !== 'pending') {
      return this.reject('当前状态不可操作');
    }
    target.status = 'approved';
    return this.delay<boolean>(true);
  }

  async rejectApproval(id: string, comment: string): Promise<boolean> {
    if (!comment.trim()) {
      return this.reject('请填写驳回意见');
    }
    const target = this.approvals.find((a) => a.id === id);
    if (!target) {
      return this.reject('审批记录不存在', 'notFound');
    }
    if (target.status !== 'pending') {
      return this.reject('当前状态不可操作');
    }
    target.status = 'rejected';
    return this.delay<boolean>(true);
  }
}
