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
  // 页面展示的验证码挑战值；仓储据此校验用户输入是否正确
  expectedCaptcha?: string;
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
  targetGrade?: string;
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
  targetGrade?: string;
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

// 打分名单行：本班已注册学生 + 已录分数（null 表示未打分）
export interface GradeScoreRow {
  studentId: string;
  name: string;
  score: number | null;
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
  // #7 多级审批进度（有序）；列表项可携带，详情据此渲染进度条。legacy 记录缺失时为 undefined
  steps?: ApprovalStepVm[];
}

// 管理端·成绩申诉受理
export type GradeAppealStatus = 'pending' | 'accepted' | 'rejected';

export interface GradeAppealItem {
  appealId: string;
  studentId: string;
  studentName: string;
  taskId: string;
  courseId: string;
  term: string;
  reason: string;
  status: GradeAppealStatus;
  reply: string;
  handledBy: string;
  handledAt: string;
  submittedAt: string;
  updatedAt: string;
}

// 管理端·考试 CRUD
export interface AdminExamItem {
  examId: string;
  courseId: string;
  courseName: string;
  courseCode: string;
  term: string;
  examDate: string;
  startTime: string;
  endTime: string;
  location: string;
  seatNo: string;
  examType: string;
}

export interface AdminExamWritePayload {
  courseId: string;
  term: string;
  examDate: string;
  startTime: string;
  endTime: string;
  location: string;
  seatNo: string;
  examType: string;
}

// 管理端·实践成果受理
export type PracticeSubmissionStatus = 'submitted' | 'scored' | 'passed' | 'rejected';

export interface PracticeSubmissionAdminItem {
  submissionId: string;
  projectId: string;
  studentId: string;
  studentName: string;
  projectTitle: string;
  content: string;
  attachments: string[];
  status: PracticeSubmissionStatus;
  score: number | null;
  feedback: string;
  scoredBy: string;
  scoredAt: string;
  submittedAt: string;
  updatedAt: string;
}

export interface PracticeScorePayload {
  score: number | null;
  feedback: string;
  status: PracticeSubmissionStatus;
}

export interface ApprovalFlowNode {
  id: string;
  nodeName: string;
  operatorName?: string;
  status: 'pending' | 'approved' | 'rejected' | 'waiting';
  handledAt?: string;
  comment?: string;
}

// #7 多级审批流单步（后端 steps[] 的前端视图模型）。
// status：waiting=尚未轮到，pending=当前处理中，approved=已通过，rejected=已驳回。
export type ApprovalStepStatus = 'waiting' | 'pending' | 'approved' | 'rejected';

export interface ApprovalStepVm {
  order: number;
  title: string;
  approverRole: string;
  status: ApprovalStepStatus;
  handler: string;
  handledAt: string;
  comment: string;
}

export interface ApprovalDetail extends ApprovalItem {
  flow: ApprovalFlowNode[];
  attachments: string[];
  // #7 多级审批进度（按 order 有序）；旧记录或后端未下发时为 []
  steps: ApprovalStepVm[];
}
