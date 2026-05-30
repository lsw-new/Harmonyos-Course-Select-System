// 路由跳转封装 + 角色守卫

import router from '@ohos.router';
import { SessionStorage } from '../common/storage/SessionStorage';
import { UserRole } from '../models/User';

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
  static readonly AdminStudents = 'pages/AdminStudentsPage';
  static readonly AdminCourses = 'pages/AdminCoursesPage';
  static readonly AdminSelection = 'pages/AdminSelectionPage';
  static readonly AdminGrades = 'pages/AdminGradesPage';
  static readonly AdminNotice = 'pages/AdminNoticePage';
  static readonly AdminEval = 'pages/AdminEvalPage';
  static readonly AdminApprovals = 'pages/AdminApprovalsPage';
  static readonly AdminProfile = 'pages/AdminProfilePage';
  static readonly AdminRolePerm = 'pages/AdminRolePermPage';
  static readonly AdminAuditLog = 'pages/AdminAuditLogPage';
  static readonly AdminCalendar = 'pages/AdminCalendarPage';
  static readonly AdminSysConfig = 'pages/AdminSysConfigPage';
  static readonly AdminPassword = 'pages/AdminPasswordPage';
  static readonly AdminStudentDetail = 'pages/AdminStudentDetailPage';
}

const STUDENT_ROUTES: string[] = [
  Routes.Home, Routes.Today, Routes.Notices, Routes.NoticeDetail,
  Routes.Schedule, Routes.CourseDetail, Routes.Selection,
  Routes.Grades, Routes.Exam, Routes.Roster,
  Routes.Eval, Routes.Leave, Routes.Feedback, Routes.Practice,
  Routes.Mine, Routes.Account, Routes.EditInfo, Routes.Password, Routes.Settings,
  Routes.ServiceHall, Routes.PracticeDetail
];

const ADMIN_ROUTES: string[] = [
  Routes.AdminDashboard, Routes.AdminStudents, Routes.AdminCourses,
  Routes.AdminSelection, Routes.AdminGrades, Routes.AdminNotice,
  Routes.AdminEval, Routes.AdminApprovals, Routes.AdminProfile,
  Routes.AdminRolePerm, Routes.AdminAuditLog, Routes.AdminCalendar,
  Routes.AdminSysConfig, Routes.AdminPassword, Routes.AdminStudentDetail
];

const PUBLIC_ROUTES: string[] = [
  Routes.Login, Routes.Register, Routes.Forgot, Routes.AdminLogin,
  Routes.About, Routes.Doc
];

export interface NavigateOptions {
  params?: Record<string, Object>;
  replace?: boolean;
}

function expectedRoleFor(url: string): UserRole | undefined {
  if (STUDENT_ROUTES.indexOf(url) >= 0) return 'student';
  if (ADMIN_ROUTES.indexOf(url) >= 0) return 'admin';
  return undefined;
}

export class AppRoute {
  static go(url: string, options: NavigateOptions = {}): void {
    if (!AppRoute.guard(url)) {
      return;
    }
    if (options.replace) {
      router.replaceUrl({ url, params: options.params });
    } else {
      router.pushUrl({ url, params: options.params });
    }
  }

  static back(): void {
    router.back();
  }

  static clearTo(url: string, params?: Record<string, Object>): void {
    router.clear();
    router.replaceUrl({ url, params });
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
      router.replaceUrl({ url: required === 'admin' ? Routes.AdminLogin : Routes.Login });
      return false;
    }
    if (session.getRole() !== required) {
      router.replaceUrl({ url: required === 'admin' ? Routes.AdminLogin : Routes.Login });
      return false;
    }
    return true;
  }

  static getParam<T>(key: string, fallback: T): T {
    try {
      const params = router.getParams() as Record<string, Object>;
      if (params && params[key] !== undefined) {
        return params[key] as T;
      }
    } catch (e) {
      // ignore
    }
    return fallback;
  }
}
