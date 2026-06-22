// 路由跳转封装 + 角色守卫
// Navigation 迁移：内部由已废弃的 @ohos.router 改为 NavPathStack（系统路由表）。
// 门面方法签名保持不变，调用点零改动；初始路由由 pages/Index 托管的 Navigation 承载。

import { SessionStorage } from '../common/storage/SessionStorage';
import { UserRole } from '../models/User';
import { AuthorizationService } from '../common/security/AuthorizationService';
import { AdminPermissionAction } from '../models/Admin';

export class Routes {
  static readonly Login = 'pages/LoginPage';
  static readonly Register = 'pages/RegisterPage';
  static readonly Forgot = 'pages/ForgotPage';
  static readonly Home = 'pages/HomePage';
  static readonly Today = 'pages/TodayPage';
  static readonly Notices = 'pages/NoticesPage';
  static readonly NoticeDetail = 'pages/NoticeDetailPage';
  static readonly Schedule = 'pages/SchedulePage';
  static readonly CourseDetail = 'pages/CourseDetailPage';
  static readonly Selection = 'pages/SelectionPage';
  static readonly Grades = 'pages/GradesPage';
  static readonly Exam = 'pages/ExamPage';
  static readonly Roster = 'pages/RosterPage';
  static readonly Eval = 'pages/EvalPage';
  static readonly Leave = 'pages/LeavePage';
  static readonly Feedback = 'pages/FeedbackPage';
  static readonly Practice = 'pages/PracticePage';
  static readonly Mine = 'pages/MinePage';
  static readonly Account = 'pages/AccountPage';
  static readonly EditInfo = 'pages/EditInfoPage';
  static readonly Password = 'pages/PasswordPage';
  static readonly Settings = 'pages/SettingsPage';
  static readonly ServiceHall = 'pages/ServiceHallPage';
  static readonly PracticeDetail = 'pages/PracticeDetailPage';
  static readonly About = 'pages/AboutPage';
  static readonly Doc = 'pages/DocPage';

  static readonly AdminLogin = 'pages/AdminLoginPage';
  static readonly AdminDashboard = 'pages/AdminDashboardPage';
  // 教师端（roadmap #6）
  static readonly TeacherHome = 'pages/TeacherHomePage';
  static readonly TeacherCourseDetail = 'pages/TeacherCourseDetailPage';
  static readonly TeacherEval = 'pages/TeacherEvalPage';
  static readonly TeacherNotice = 'pages/TeacherNoticePage';
  static readonly TeacherAppeal = 'pages/TeacherAppealPage';
  static readonly AdminStudents = 'pages/AdminStudentsPage';
  static readonly AdminCourses = 'pages/AdminCoursesPage';
  static readonly AdminSelection = 'pages/AdminSelectionPage';
  static readonly AdminRoundCourses = 'pages/AdminRoundCoursesPage';
  static readonly AdminGrades = 'pages/AdminGradesPage';
  static readonly AdminNotice = 'pages/AdminNoticePage';
  static readonly AdminEval = 'pages/AdminEvalPage';
  static readonly AdminApprovals = 'pages/AdminApprovalsPage';
  static readonly AdminFeedback = 'pages/AdminFeedbackPage';
  static readonly AdminProfile = 'pages/AdminProfilePage';
  static readonly AdminRolePerm = 'pages/AdminRolePermPage';
  static readonly AdminAuditLog = 'pages/AdminAuditLogPage';
  static readonly AdminCalendar = 'pages/AdminCalendarPage';
  static readonly AdminSysConfig = 'pages/AdminSysConfigPage';
  static readonly AdminPassword = 'pages/AdminPasswordPage';
  static readonly AdminStudentDetail = 'pages/AdminStudentDetailPage';
  static readonly AdminGradeAppeals = 'pages/AdminGradeAppealsPage';
  static readonly AdminExams = 'pages/AdminExamsPage';
  static readonly AdminPracticeSubmissions = 'pages/AdminPracticeSubmissionsPage';

  // 补充详情 / 二级页面（UI 包融入）
  static readonly SelectionResult = 'pages/SelectionResultPage';
  static readonly SelectionConfirm = 'pages/SelectionConfirmPage';
  static readonly GradeDetail = 'pages/GradeDetailPage';
  static readonly GradeAppeal = 'pages/GradeAppealPage';
  static readonly ExamDetail = 'pages/ExamDetailPage';
  static readonly LeaveDetail = 'pages/LeaveDetailPage';
  static readonly FeedbackDetail = 'pages/FeedbackDetailPage';
  static readonly PracticeSignup = 'pages/PracticeSignupPage';
  static readonly MyPractice = 'pages/MyPracticePage';
  static readonly MessageCenter = 'pages/MessageCenterPage';
  static readonly AttachmentPreview = 'pages/AttachmentPreviewPage';
  static readonly NoPermission = 'pages/NoPermissionPage';
  static readonly AdminApprovalDetail = 'pages/AdminApprovalDetailPage';
  static readonly AdminCourseDetail = 'pages/AdminCourseDetailPage';
  static readonly ImportResult = 'pages/ImportResultPage';
  static readonly AuditLogDetail = 'pages/AuditLogDetailPage';
}

const STUDENT_ROUTES: string[] = [
  Routes.Home, Routes.Today, Routes.Notices, Routes.NoticeDetail,
  Routes.Schedule, Routes.CourseDetail, Routes.Selection,
  Routes.Grades, Routes.Exam, Routes.Roster,
  Routes.Eval, Routes.Leave, Routes.Feedback, Routes.Practice,
  Routes.Mine, Routes.Account, Routes.EditInfo, Routes.Password, Routes.Settings,
  Routes.ServiceHall, Routes.PracticeDetail,
  Routes.SelectionResult, Routes.SelectionConfirm, Routes.GradeDetail, Routes.GradeAppeal, Routes.ExamDetail,
  Routes.LeaveDetail, Routes.FeedbackDetail, Routes.PracticeSignup, Routes.MyPractice, Routes.MessageCenter,
  Routes.AttachmentPreview
];

const ADMIN_ROUTES: string[] = [
  Routes.AdminDashboard, Routes.AdminStudents, Routes.AdminCourses,
  Routes.AdminSelection, Routes.AdminGrades, Routes.AdminNotice,
  Routes.AdminEval, Routes.AdminApprovals, Routes.AdminFeedback, Routes.AdminProfile,
  Routes.AdminRolePerm, Routes.AdminAuditLog, Routes.AdminCalendar,
  Routes.AdminSysConfig, Routes.AdminPassword, Routes.AdminStudentDetail,
  Routes.AdminApprovalDetail, Routes.AdminCourseDetail, Routes.ImportResult, Routes.AuditLogDetail,
  Routes.AdminRoundCourses, Routes.AdminGradeAppeals, Routes.AdminExams,
  Routes.AdminPracticeSubmissions
];

const TEACHER_ROUTES: string[] = [
  Routes.TeacherHome, Routes.TeacherCourseDetail, Routes.TeacherEval,
  Routes.TeacherNotice, Routes.TeacherAppeal
];

const PUBLIC_ROUTES: string[] = [
  Routes.Login, Routes.Register, Routes.Forgot, Routes.AdminLogin,
  Routes.About, Routes.Doc,
  Routes.NoPermission
];

// 空参数占位（ArkTS 严格模式禁裸字面量，统一用此具名常量）。
const EMPTY_PARAMS: Record<string, Object> = {};

export interface NavigateOptions {
  params?: Record<string, Object>;
  replace?: boolean;
}

function expectedRoleFor(url: string): UserRole | undefined {
  if (STUDENT_ROUTES.indexOf(url) >= 0) return 'student';
  if (ADMIN_ROUTES.indexOf(url) >= 0) return 'admin';
  if (TEACHER_ROUTES.indexOf(url) >= 0) return 'teacher';
  return undefined;
}

// P2-03：管理端路由所需的细粒度权限（入口/只读统一用 view 动作）。
// 与后端 P0-02 强校验呼应：前端在角色通过后再按权限收敛入口，未登记的管理端
// 路由（仪表盘 / 个人页 / 日历 / 导入结果）仅需 role=admin。
class RoutePerm {
  code: string;
  action: AdminPermissionAction;
  constructor(code: string, action: AdminPermissionAction) {
    this.code = code;
    this.action = action;
  }
}

function routePermissionFor(url: string): RoutePerm | undefined {
  switch (url) {
    case Routes.AdminStudents:
    case Routes.AdminStudentDetail:
      return new RoutePerm('students.manage', 'view');
    case Routes.AdminCourses:
    case Routes.AdminCourseDetail:
      return new RoutePerm('courses.manage', 'view');
    case Routes.AdminSelection:
      return new RoutePerm('selection.manage', 'view');
    case Routes.AdminRoundCourses:
      return new RoutePerm('courses.manage', 'view');
    case Routes.AdminGrades:
      return new RoutePerm('grades.approve', 'view');
    case Routes.AdminGradeAppeals:
      return new RoutePerm('grades.approve', 'view');
    case Routes.AdminExams:
      return new RoutePerm('courses.manage', 'view');
    case Routes.AdminPracticeSubmissions:
      return new RoutePerm('courses.manage', 'view');
    case Routes.AdminNotice:
      return new RoutePerm('notices.publish', 'view');
    case Routes.AdminEval:
      return new RoutePerm('evaluation.manage', 'view');
    case Routes.AdminApprovals:
    case Routes.AdminApprovalDetail:
      return new RoutePerm('approvals.handle', 'view');
    case Routes.AdminFeedback:
      return new RoutePerm('feedback.handle', 'view');
    case Routes.AdminRolePerm:
      return new RoutePerm('roles.manage', 'view');
    case Routes.AdminAuditLog:
    case Routes.AuditLogDetail:
      return new RoutePerm('audit.view', 'view');
    case Routes.AdminSysConfig:
      return new RoutePerm('system.config', 'view');
    default:
      return undefined;
  }
}

export class AppRoute {
  // 全局唯一返回栈：由 pages/Index 的 Navigation(AppRoute.stack) 托管，所有跳转走它。
  static readonly stack: NavPathStack = new NavPathStack();

  // 已移除固定 1.5s 假加载遮罩（保留方法名兼容调用点，确保遮罩关闭态）。
  // 加载态改由各页真实 @State loading + 骨架屏(SkeletonList) 体现。
  static showLoading(): void {
    AppStorage.setOrCreate('routeLoading', false);
  }

  static go(url: string, options: NavigateOptions = {}): void {
    if (!AppRoute.guard(url)) {
      return;
    }
    AppRoute.showLoading();
    const params: Record<string, Object> = options.params ?? EMPTY_PARAMS;
    if (options.replace) {
      AppRoute.stack.replacePathByName(url, params);
    } else {
      AppRoute.stack.pushPathByName(url, params);
    }
  }

  static back(): void {
    AppRoute.showLoading();
    AppRoute.stack.pop();
  }

  static clearTo(url: string, params?: Record<string, Object>): void {
    AppRoute.showLoading();
    AppRoute.stack.clear();
    AppRoute.stack.pushPathByName(url, params ?? EMPTY_PARAMS);
  }

  static guard(url: string): boolean {
    if (PUBLIC_ROUTES.indexOf(url) >= 0) {
      return true;
    }
    const session = SessionStorage.get();
    const required = expectedRoleFor(url);
    if (!required) {
      return true;
    }
    if (!session.isAuthenticated()) {
      AppRoute.stack.replacePathByName(required === 'admin' ? Routes.AdminLogin : Routes.Login, EMPTY_PARAMS);
      return false;
    }
    if (session.getRole() !== required) {
      AppRoute.stack.replacePathByName(required === 'admin' ? Routes.AdminLogin : Routes.Login, EMPTY_PARAMS);
      return false;
    }
    // P2-03：管理端角色通过后再校验路由所需的细粒度权限，缺权限跳无权限页
    if (required === 'admin') {
      const perm = routePermissionFor(url);
      if (perm !== undefined && !AuthorizationService.hasAdminPermission(perm.code, perm.action)) {
        AppRoute.stack.replacePathByName(Routes.NoPermission, EMPTY_PARAMS);
        return false;
      }
    }
    return true;
  }

  static getParam<T>(key: string, fallback: T): T {
    const size: number = AppRoute.stack.size();
    if (size > 0) {
      const raw = AppRoute.stack.getParamByIndex(size - 1) as Record<string, Object> | undefined;
      if (raw !== undefined && raw[key] !== undefined) {
        return raw[key] as T;
      }
    }
    return fallback;
  }
}
