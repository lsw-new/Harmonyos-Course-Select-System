// Track B 远程数据源：封装后端 API 调用（认证 / 课程 / 选课垂直切片）。
// 仅当 AppConfig.useRemote=true 时被仓储调用；apiClient 已自动拆 ApiResponse 信封并附带 token。
// 说明：ArkTS 禁 Record 对象字面量，故 GET 查询参数内联进 path、POST/DELETE body 用具名接口。
import { apiClient } from '../http/ApiClient';
import { HttpRequestOptions } from '../http/HttpClient';

export interface RemoteCourse {
  id: string;
  code: string;
  name: string;
  teacher: string;
  category: string;
  credit: number;
  timeText: string;
  capacity: number;
  selectedCount: number;
  status: string;
}

export interface RemoteRound {
  id: string;
  name: string;
  status: string;
  startTime: string;
  endTime: string;
  creditLimit: number;
}

export interface RemoteAdminPermission {
  code: string;
  name: string;
  module: string;
  actions: string[];
}

// P1-03：后端随登录下发的真实 profile（学生字段 + 管理员字段合并，按 role 取用）。
export interface RemoteProfile {
  // 共有
  name?: string;
  avatarUrl?: string;
  email?: string;
  role?: string;
  // 学生
  studentId?: string;
  college?: string;
  major?: string;
  className?: string;
  grade?: string;
  phone?: string;
  address?: string;
  emergencyContact?: string;
  bio?: string;
  // 管理员
  adminId?: string;
  department?: string;
  roleName?: string;
  onlineStatus?: string;
  permissions?: RemoteAdminPermission[];
}

export interface ProfileUpdateBody {
  avatarUrl?: string;
  phone?: string;
  email?: string;
  address?: string;
  emergencyContact?: string;
  bio?: string;
}

export interface RemoteLoginResult {
  token: string;
  accountId: string;
  role: string;
  profile?: RemoteProfile;
}

interface LoginBody {
  account: string;
  password: string;
}

interface EmailCodeBody {
  email: string;
}

interface VerifyEmailCodeBody {
  email: string;
  code: string;
}

interface RegisterBody {
  studentId: string;
  name: string;
  email: string;
  emailCode: string;
  password: string;
}

interface ResetPasswordBody {
  account: string;
  contact: string;
  verifyCode: string;
  newPassword: string;
}

interface SelectionBody {
  studentId: string;
  courseId: string;
}

export interface RemoteGrade {
  id: string;
  term: string;
  courseCode: string;
  teachingClassNo: string;
  courseName: string;
  courseCategory: string;
  credit: number;
  score: number;
  gradePoint: number;
  rank: number;
  publishedAt: string;
}

export interface RemoteScheduleItem {
  id: string;
  term: string;
  type: string;
  courseId: string;
  courseName: string;
  teacher: string;
  weekday: number;
  periodStart: number;
  periodEnd: number;
  startTime: string;
  endTime: string;
  classroom: string;
  campus?: string;
  weeks: number[];
  weekText: string;
  courseType: string;
}

export interface RemoteSchedule {
  className: string;
  items: RemoteScheduleItem[];
}

export interface RemoteNotice {
  id: string;
  title: string;
  publisher: string;
  publishedAt: string;
  summary: string;
  content: string;
  isRead: boolean;
  category: string;
  attachments: string[];
}

export interface RemoteLeave {
  id: string;
  type: string;
  startDate: string;
  endDate: string;
  reason: string;
  attachments: string[];
  state: string;
  submittedAt: string;
  feedback: string;
}

interface LeaveCreateBody {
  studentId: string;
  type: string;
  startDate: string;
  endDate: string;
  reason: string;
}

interface StudentIdBody {
  studentId: string;
}

export interface RemoteFeedback {
  id: string;
  category: string;
  title: string;
  content: string;
  contact: string;
  screenshots: string[];
  submittedAt: string;
  state: string;
}

export interface RemoteEvalTask {
  id: string;
  term: string;
  courseCode: string;
  courseName: string;
  courseCategory: string;
  teacherName: string;
  questionnaireName: string;
  status: string;
  openTime: string;
  closeTime: string;
}

export interface RemotePractice {
  id: string;
  title: string;
  org: string;
  category: string;
  credits: number;
  period: string;
  location: string;
  mentor: string;
  slotsTotal: number;
  slotsTaken: number;
  signedUp: boolean;
  description: string;
  requirements: string[];
}

interface FeedbackBody {
  studentId: string;
  category: string;
  title: string;
  content: string;
  contact: string;
}

interface EvalSubmitBody {
  studentId: string;
  answers: Object;
}

export interface RemoteStudent {
  studentId: string;
  name: string;
  college: string;
  major: string;
  className: string;
  status: string;
  educationLevel: string;
}

export interface RemoteStudentDetail {
  studentId: string;
  name: string;
  college: string;
  major: string;
  className: string;
  grade: string;
  phone: string;
  email: string;
}

export interface RemoteGradeTask {
  id: string;
  courseName: string;
  teachingClassName: string;
  teacherName: string;
  inputProgress: number;
  status: string;
  updatedAt: string;
  rejectReason?: string;
}

export interface RemoteStatCard {
  key: string;
  label: string;
  value: number;
  color?: string;
}

export interface RemoteTrendPoint {
  label: string;
  value: number;
}

export interface RemoteDistributionItem {
  name: string;
  value: number;
}

export interface RemoteDashboard {
  statCards: RemoteStatCard[];
  selectionTrend: RemoteTrendPoint[];
  courseTypeDistribution: RemoteDistributionItem[];
  pendingApprovals: RemoteApproval[];
}

export interface RemoteAdminRound {
  id: string;
  name: string;
  status: string;
  startTime: string;
  endTime: string;
  progressPercent: number;
  participantCount: number;
  selectionCount: number;
  averageCredit: number;
  conflictCount: number;
}

export interface RemoteRatingBucket {
  star: number;
  count: number;
}

export interface RemoteCalendarEvent {
  id: string;
  date: string;
  title: string;
  type: string;
}

export interface CalendarEventBody {
  date: string;
  title: string;
  type: string;
}

export interface RemoteEvalStats {
  term: string;
  participationRate: number;
  completionRate: number;
  averageScore: number;
  ratingDistribution: RemoteRatingBucket[];
}

export interface AdminCourseBody {
  code: string;
  name: string;
  teacher: string;
  category: string;
  credit: number;
  timeText: string;
  capacity: number;
  status: string;
}

export interface RemoteGradeScoreRow {
  studentId: string;
  name: string;
  score: number | null;
}

export interface RemoteGradeScores {
  taskId: string;
  students: RemoteGradeScoreRow[];
}

export interface GradeScoreEntry {
  studentId: string;
  score: number;
}

interface GradeScoresBody {
  scores: GradeScoreEntry[];
}

export interface RemoteApproval {
  id: string;
  type: string;
  applicantName: string;
  applicantId: string;
  title: string;
  reason: string;
  status: string;
  isUrgent: boolean;
  submittedAt: string;
}

interface InputProgressBody {
  inputProgress: number;
}

interface ReasonBody {
  reason: string;
}

interface CommentBody {
  comment: string;
}

export interface RemotePermItem {
  code: string;
  name: string;
  module: string;
  actions: string[];
}

export interface RemoteRole {
  id: string;
  name: string;
  description: string;
  memberCount: number;
  permissions: RemotePermItem[];
}

export interface RemoteAuditLog {
  id: string;
  operatorName: string;
  operatorId: string;
  action: string;
  actionType: string;
  target: string;
  timestamp: string;
  result: string;
  ip: string;
}

export interface RemoteTemplate {
  id: string;
  name: string;
  description: string;
  questionCount: number;
  status: string;
}

interface TemplateBody {
  name: string;
  description: string;
  questionCount: number;
  status: string;
}

interface NoticeBody {
  title: string;
  content: string;
  publisher: string;
  category: string;
  urgency: string;
  receiverType: string;
  receiverScope: string[];
}

export class RemoteApi {
  static async login(account: string, password: string): Promise<RemoteLoginResult> {
    const body: LoginBody = { account: account, password: password };
    return apiClient.post<RemoteLoginResult>('/auth/login', body);
  }

  // 发送邮箱验证码（公开端点，无需登录态）。
  // 后端同步等 SMTP 发完邮件才响应（常超过默认 10s），超时放宽到 30s，
  // 避免「邮件实际已发出、App 端却先超时报网络错误」。
  static async sendEmailCode(email: string): Promise<void> {
    const body: EmailCodeBody = { email: email };
    const opts: HttpRequestOptions = { method: 'POST', body: body, timeoutMs: 30000 };
    await apiClient.request<Object>('/auth/email-code', opts);
  }

  // 校验邮箱验证码（公开端点，成功即被后端消费）
  static async verifyEmailCode(email: string, code: string): Promise<void> {
    const body: VerifyEmailCodeBody = { email: email, code: code };
    await apiClient.post<Object>('/auth/verify-email-code', body);
  }

  // P1-01：注册（公开端点，后端校验验证码 + 建账号 + 建学生资料）
  static async register(studentId: string, name: string, email: string, emailCode: string, password: string): Promise<void> {
    const body: RegisterBody = { studentId: studentId, name: name, email: email, emailCode: emailCode, password: password };
    await apiClient.post<Object>('/auth/register', body);
  }

  // P1-02：找回密码（公开端点，后端校验账号存在 + 邮箱匹配 + 验证码，仅重置不建号）
  static async resetPassword(account: string, contact: string, verifyCode: string, newPassword: string): Promise<void> {
    const body: ResetPasswordBody = { account: account, contact: contact, verifyCode: verifyCode, newPassword: newPassword };
    await apiClient.post<Object>('/auth/reset-password', body);
  }

  static async listOpenCourses(): Promise<RemoteCourse[]> {
    return apiClient.get<RemoteCourse[]>('/courses?status=open');
  }

  static async mySelections(studentId: string): Promise<RemoteCourse[]> {
    return apiClient.get<RemoteCourse[]>('/selections?studentId=' + encodeURIComponent(studentId));
  }

  static async activeRound(): Promise<RemoteRound | null> {
    return apiClient.get<RemoteRound | null>('/selection-rounds/active');
  }

  static async select(studentId: string, courseId: string): Promise<void> {
    const body: SelectionBody = { studentId: studentId, courseId: courseId };
    await apiClient.post<Object>('/selections', body);
  }

  static async drop(studentId: string, courseId: string): Promise<void> {
    const body: SelectionBody = { studentId: studentId, courseId: courseId };
    await apiClient.delete<Object>('/selections', body);
  }

  // 班级课表：后端按 JWT 学号查名册定位班级，返回本班课表（含课程-教师绑定）
  static async classSchedule(): Promise<RemoteSchedule> {
    return apiClient.get<RemoteSchedule>('/schedule');
  }

  // 更新本人资料（头像/联系方式，仅提交的字段生效），返回更新后完整 profile
  static async updateProfile(body: ProfileUpdateBody): Promise<RemoteProfile> {
    return apiClient.put<RemoteProfile>('/profile', body);
  }

  static async listGrades(studentId: string, term?: string): Promise<RemoteGrade[]> {
    let path = '/grades?studentId=' + encodeURIComponent(studentId);
    if (term && term.length > 0 && term !== '全部') {
      path += '&term=' + encodeURIComponent(term);
    }
    return apiClient.get<RemoteGrade[]>(path);
  }

  static async listNotices(studentId: string, category?: string): Promise<RemoteNotice[]> {
    let path = '/notices?studentId=' + encodeURIComponent(studentId);
    if (category && category.length > 0 && category !== '全部') {
      path += '&category=' + encodeURIComponent(category);
    }
    return apiClient.get<RemoteNotice[]>(path);
  }

  static async noticeDetail(studentId: string, id: string): Promise<RemoteNotice> {
    return apiClient.get<RemoteNotice>('/notices/' + encodeURIComponent(id) + '?studentId=' + encodeURIComponent(studentId));
  }

  static async markNoticeRead(studentId: string, id: string): Promise<void> {
    const body: StudentIdBody = { studentId: studentId };
    await apiClient.post<Object>('/notices/' + encodeURIComponent(id) + '/read', body);
  }

  static async listLeave(studentId: string): Promise<RemoteLeave[]> {
    return apiClient.get<RemoteLeave[]>('/leave?studentId=' + encodeURIComponent(studentId));
  }

  static async submitLeave(studentId: string, type: string, startDate: string, endDate: string, reason: string): Promise<RemoteLeave> {
    const body: LeaveCreateBody = { studentId: studentId, type: type, startDate: startDate, endDate: endDate, reason: reason };
    return apiClient.post<RemoteLeave>('/leave', body);
  }

  static async listFeedback(studentId: string): Promise<RemoteFeedback[]> {
    return apiClient.get<RemoteFeedback[]>('/feedback?studentId=' + encodeURIComponent(studentId));
  }

  static async submitFeedback(studentId: string, category: string, title: string, content: string, contact: string): Promise<RemoteFeedback> {
    const body: FeedbackBody = { studentId: studentId, category: category, title: title, content: content, contact: contact };
    return apiClient.post<RemoteFeedback>('/feedback', body);
  }

  static async listEvaluations(studentId: string, term?: string): Promise<RemoteEvalTask[]> {
    let path = '/evaluations?studentId=' + encodeURIComponent(studentId);
    if (term && term.length > 0 && term !== '全部') {
      path += '&term=' + encodeURIComponent(term);
    }
    return apiClient.get<RemoteEvalTask[]>(path);
  }

  static async submitEvaluation(studentId: string, taskId: string, answers: Object): Promise<void> {
    const body: EvalSubmitBody = { studentId: studentId, answers: answers };
    await apiClient.post<Object>('/evaluations/' + encodeURIComponent(taskId) + '/submit', body);
  }

  static async listPractice(studentId: string, category?: string): Promise<RemotePractice[]> {
    let path = '/practice?studentId=' + encodeURIComponent(studentId);
    if (category && category.length > 0) {
      path += '&category=' + encodeURIComponent(category);
    }
    return apiClient.get<RemotePractice[]>(path);
  }

  static async practiceDetail(studentId: string, id: string): Promise<RemotePractice> {
    return apiClient.get<RemotePractice>('/practice/' + encodeURIComponent(id) + '?studentId=' + encodeURIComponent(studentId));
  }

  static async practiceSignup(studentId: string, id: string): Promise<RemotePractice> {
    const body: StudentIdBody = { studentId: studentId };
    return apiClient.post<RemotePractice>('/practice/' + encodeURIComponent(id) + '/signup', body);
  }

  static async practiceCancel(studentId: string, id: string): Promise<RemotePractice> {
    const body: StudentIdBody = { studentId: studentId };
    return apiClient.delete<RemotePractice>('/practice/' + encodeURIComponent(id) + '/signup', body);
  }

  // ===== 管理端（需管理员 token）=====
  static async adminListStudents(query?: string, college?: string): Promise<RemoteStudent[]> {
    const params: string[] = [];
    if (query && query.length > 0) {
      params.push('q=' + encodeURIComponent(query));
    }
    if (college && college.length > 0 && college !== '全部') {
      params.push('college=' + encodeURIComponent(college));
    }
    const path = params.length > 0 ? '/admin/students?' + params.join('&') : '/admin/students';
    return apiClient.get<RemoteStudent[]>(path);
  }

  // 学生详情（student_profiles 真实档案）
  static async adminStudentDetail(studentId: string): Promise<RemoteStudentDetail> {
    return apiClient.get<RemoteStudentDetail>('/admin/students/' + encodeURIComponent(studentId));
  }

  // 仪表盘：注册/名册/课程/审批/成绩/评教实时计数 + 近7天选课趋势 + 课程类型分布 + 待审批前5条
  static async adminDashboard(): Promise<RemoteDashboard> {
    return apiClient.get<RemoteDashboard>('/admin/dashboard');
  }

  // 教学日历（calendar_events 实库）
  static async adminCalendarEvents(): Promise<RemoteCalendarEvent[]> {
    return apiClient.get<RemoteCalendarEvent[]>('/admin/calendar');
  }

  static async adminAddCalendarEvent(body: CalendarEventBody): Promise<RemoteCalendarEvent> {
    return apiClient.post<RemoteCalendarEvent>('/admin/calendar', body);
  }

  static async adminDeleteCalendarEvent(id: string): Promise<void> {
    await apiClient.delete<Object>('/admin/calendar/' + encodeURIComponent(id), undefined);
  }

  // 管理端课程目录（全部状态）
  static async adminListCourses(): Promise<RemoteCourse[]> {
    return apiClient.get<RemoteCourse[]>('/admin/courses');
  }

  static async adminCreateCourse(body: AdminCourseBody): Promise<RemoteCourse> {
    return apiClient.post<RemoteCourse>('/admin/courses', body);
  }

  static async adminUpdateCourse(id: string, body: AdminCourseBody): Promise<RemoteCourse> {
    return apiClient.put<RemoteCourse>('/admin/courses/' + encodeURIComponent(id), body);
  }

  static async adminDeleteCourse(id: string): Promise<void> {
    await apiClient.delete<Object>('/admin/courses/' + encodeURIComponent(id), undefined);
  }

  // 选课轮次统计（参与人数/选课数/均学分/时间进度，实时聚合）
  static async adminSelectionStats(): Promise<RemoteAdminRound[]> {
    return apiClient.get<RemoteAdminRound[]>('/admin/selection/stats');
  }

  // 评教统计（参与率/完成率/平均分/星级分布，实时聚合）
  static async adminEvalStats(): Promise<RemoteEvalStats> {
    return apiClient.get<RemoteEvalStats>('/admin/eval/stats');
  }

  static async adminListGrades(status?: string): Promise<RemoteGradeTask[]> {
    let path = '/admin/grades';
    if (status && status.length > 0 && status !== '全部') {
      path += '?status=' + encodeURIComponent(status);
    }
    return apiClient.get<RemoteGradeTask[]>(path);
  }

  static async adminGradeInput(taskId: string, inputProgress: number): Promise<RemoteGradeTask> {
    const body: InputProgressBody = { inputProgress: inputProgress };
    return apiClient.post<RemoteGradeTask>('/admin/grades/' + encodeURIComponent(taskId) + '/input', body);
  }

  // 打分名单：任务对应班级的已注册学生 + 已录分数
  static async adminGradeScores(taskId: string): Promise<RemoteGradeScores> {
    return apiClient.get<RemoteGradeScores>('/admin/grades/' + encodeURIComponent(taskId) + '/scores');
  }

  // 按学生打分：后端 UPSERT 成绩 + 重算排名 + 自动更新录入进度，返回更新后任务
  static async adminSubmitGradeScores(taskId: string, scores: GradeScoreEntry[]): Promise<RemoteGradeTask> {
    const body: GradeScoresBody = { scores: scores };
    return apiClient.post<RemoteGradeTask>('/admin/grades/' + encodeURIComponent(taskId) + '/scores', body);
  }

  static async adminGradeApprove(taskId: string): Promise<void> {
    await apiClient.post<Object>('/admin/grades/' + encodeURIComponent(taskId) + '/approve');
  }

  static async adminGradeReject(taskId: string, reason: string): Promise<void> {
    const body: ReasonBody = { reason: reason };
    await apiClient.post<Object>('/admin/grades/' + encodeURIComponent(taskId) + '/reject', body);
  }

  static async adminListApprovals(status?: string): Promise<RemoteApproval[]> {
    let path = '/admin/approvals';
    if (status && status.length > 0 && status !== '全部') {
      path += '?status=' + encodeURIComponent(status);
    }
    return apiClient.get<RemoteApproval[]>(path);
  }

  static async adminApprove(id: string, comment: string): Promise<void> {
    const body: CommentBody = { comment: comment };
    await apiClient.post<Object>('/admin/approvals/' + encodeURIComponent(id) + '/approve', body);
  }

  static async adminReject(id: string, comment: string): Promise<void> {
    const body: CommentBody = { comment: comment };
    await apiClient.post<Object>('/admin/approvals/' + encodeURIComponent(id) + '/reject', body);
  }

  static async adminListRoles(): Promise<RemoteRole[]> {
    return apiClient.get<RemoteRole[]>('/admin/roles');
  }

  static async adminListAuditLogs(type?: string): Promise<RemoteAuditLog[]> {
    let path = '/admin/audit-logs';
    if (type && type.length > 0 && type !== '全部') {
      path += '?type=' + encodeURIComponent(type);
    }
    return apiClient.get<RemoteAuditLog[]>(path);
  }

  static async adminListTemplates(): Promise<RemoteTemplate[]> {
    return apiClient.get<RemoteTemplate[]>('/admin/eval/templates');
  }

  static async adminCreateTemplate(name: string, description: string, questionCount: number, status: string): Promise<RemoteTemplate> {
    const body: TemplateBody = { name: name, description: description, questionCount: questionCount, status: status };
    return apiClient.post<RemoteTemplate>('/admin/eval/templates', body);
  }

  static async adminUpdateTemplate(id: string, name: string, description: string, questionCount: number, status: string): Promise<RemoteTemplate> {
    const body: TemplateBody = { name: name, description: description, questionCount: questionCount, status: status };
    return apiClient.put<RemoteTemplate>('/admin/eval/templates/' + encodeURIComponent(id), body);
  }

  static async adminDeleteTemplate(id: string): Promise<void> {
    await apiClient.delete<Object>('/admin/eval/templates/' + encodeURIComponent(id));
  }

  static async adminPublishNotice(title: string, content: string, publisher: string, category: string, urgency: string, receiverType: string, receiverScope: string[]): Promise<void> {
    const body: NoticeBody = {
      title: title,
      content: content,
      publisher: publisher,
      category: category,
      urgency: urgency,
      receiverType: receiverType,
      receiverScope: receiverScope
    };
    await apiClient.post<Object>('/admin/notices', body);
  }
}
