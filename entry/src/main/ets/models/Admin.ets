// 管理端模型

export interface AdminLoginResult {
  token: string;
  profile: AdminProfile;
}

export type AdminPermissionAction = 'view' | 'create' | 'update' | 'delete' | 'approve' | 'publish';

export interface AdminPermission {
  code: string;
  name: string;
  module: string;
  actions: AdminPermissionAction[];
}

export interface AdminProfile {
  adminId: string;
  name: string;
  department: string;
  roleName: string;
  avatarUrl?: string;
  onlineStatus: 'online' | 'busy' | 'offline';
  permissions: AdminPermission[];
}

export interface AdminRole {
  id: string;
  name: string;
  description?: string;
  permissions: AdminPermission[];
}

export interface AdminLoginRequest {
  adminId: string;
  password: string;
  captcha: string;
  remember?: boolean;
}

export interface TrendPoint {
  label: string;
  value: number;
}

export interface DistributionItem {
  name: string;
  value: number;
  color?: string;
}

export interface DashboardStatCard {
  key: string;
  label: string;
  value: number;
  delta?: number;
  color?: string;
}

export interface AdminDashboardSummary {
  statCards: DashboardStatCard[];
  selectionTrend: TrendPoint[];
  courseTypeDistribution: DistributionItem[];
  pendingApprovals: ApprovalItem[];
}

export type StudentAdminStatus = 'active' | 'graduating' | 'suspended' | 'graduated';
export type StudentEducationLevel = 'undergraduate' | 'postgraduate' | 'other';

export interface StudentAdminItem {
  studentId: string;
  name: string;
  college: string;
  major: string;
  className: string;
  gpa?: number;
  status: StudentAdminStatus;
  educationLevel: StudentEducationLevel;
}

export type AdminCourseCategory = 'required' | 'elective' | 'public' | 'practice';
export type AdminCourseStatus = 'draft' | 'open' | 'closed' | 'archived';

export interface AdminCourseItem {
  id: string;
  code: string;
  name: string;
  teacher: string;
  category: AdminCourseCategory;
  credit: number;
  timeText: string;
  capacity: number;
  selectedCount: number;
  status: AdminCourseStatus;
}

export interface AdminCourseWritePayload {
  code: string;
  name: string;
  teacher: string;
  category: AdminCourseCategory;
  credit: number;
  timeText: string;
  capacity: number;
  selectedCount: number;
  status: AdminCourseStatus;
}

export type SelectionRoundStatus = 'notStarted' | 'running' | 'ended';

export interface SelectionRound {
  id: string;
  name: string;
  status: SelectionRoundStatus;
  startTime: string;
  endTime: string;
  progressPercent: number;
  participantCount: number;
  selectionCount: number;
  averageCredit: number;
  conflictCount: number;
}

export type GradeAuditStatus = 'pendingAudit' | 'inputting' | 'published' | 'appealed' | 'rejected';

export interface GradeInputPayload {
  id: string;
  inputProgress: number;
}

export interface GradeRejectPayload {
  id: string;
  reason: string;
}

export interface GradeAuditItem {
  id: string;
  courseName: string;
  teachingClassName: string;
  teacherName: string;
  inputProgress: number;
  status: GradeAuditStatus;
  updatedAt: string;
  rejectReason?: string;
}

export interface NoticeDraft {
  title: string;
  content: string;
  publisher: string;
  category: string;
  urgency: 'normal' | 'important' | 'urgent';
  publishTime?: string;
  expireTime?: string;
  receiverType: 'all' | 'students' | 'teachers' | 'custom';
  receiverScope: string[];
}

export interface EvaluationStats {
  term: string;
  openStatus: 'open' | 'closed' | 'draft';
  startTime: string;
  endTime: string;
  participationRate: number;
  completionRate: number;
  averageScore: number;
  questionnaireCount: number;
}

export type ApprovalStatus = 'pending' | 'approved' | 'rejected' | 'withdrawn';

export interface ApprovalItem {
  id: string;
  type: string;
  applicantName: string;
  applicantId: string;
  title: string;
  reason: string;
  status: ApprovalStatus;
  isUrgent: boolean;
  submittedAt: string;
}

export interface ApprovalFlowNode {
  id: string;
  nodeName: string;
  operatorName?: string;
  status: 'pending' | 'approved' | 'rejected' | 'waiting';
  handledAt?: string;
  comment?: string;
}

export interface ApprovalDetail extends ApprovalItem {
  flow: ApprovalFlowNode[];
  attachments: string[];
}
