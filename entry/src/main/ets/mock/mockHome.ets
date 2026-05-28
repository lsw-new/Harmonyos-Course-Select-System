import { HomeSummary, QuickEntry, DownloadFile, RecentLogin, TermInfo } from '../models/Home';
import { mockSchedule } from './mockCourses';
import { mockNotices } from './mockNotices';

const term: TermInfo = {
  academicYear: '2025-2026',
  semester: '第二学期',
  weekIndex: 13,
  weekStartDate: '2026-05-25',
  weekDates: ['05/25', '05/26', '05/27', '05/28', '05/29', '05/30', '05/31']
};

const quickEntries: QuickEntry[] = [
  { key: 'schedule', label: '我的课表', icon: '🗓', route: 'pages/SchedulePage' },
  { key: 'grades', label: '我的成绩', icon: '✦', route: 'pages/GradesPage' },
  { key: 'selection', label: '选课中心', icon: '❀', route: 'pages/SelectionPage' },
  { key: 'eval', label: '量化评教', icon: '✿', route: 'pages/EvalPage' },
  { key: 'exam', label: '考试安排', icon: '✎', route: 'pages/ExamPage' },
  { key: 'notice', label: '通知公告', icon: '✉', route: 'pages/NoticesPage' },
  { key: 'roster', label: '学籍信息', icon: '◉', route: 'pages/RosterPage' },
  { key: 'practice', label: '实践公服', icon: '✤', route: 'pages/PracticePage' }
];

const files: DownloadFile[] = [
  { id: 'f-1', fileName: '2025-2026 校历.pdf', fileType: 'pdf', fileSize: 154720, updatedAt: '2025-09-01', url: 'mock://files/calendar.pdf' },
  { id: 'f-2', fileName: '课表模板.xlsx', fileType: 'xlsx', fileSize: 24576, updatedAt: '2025-09-01', url: 'mock://files/template.xlsx' }
];

const recentLogin: RecentLogin = {
  loginTime: '2026-05-27 08:43',
  network: '校园 Wi-Fi',
  region: '广州 · 玫瑰校区'
};

export const mockHomeSummary: HomeSummary = {
  term,
  todayCourses: mockSchedule.filter((s) => s.weekday === 3),
  noticeSummary: mockNotices.slice(0, 3),
  quickEntries,
  files,
  recentLogin,
  unreadNoticeCount: mockNotices.filter((n) => !n.isRead).length
};
