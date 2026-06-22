// ============================================================
// 【演示用模拟数据 · Mock — 非真实数据】
// 本文件为演示/离线展示专用，所有首页摘要、快捷入口及登录记录均为人工编造。
// remote 模式（AppConfig.runtimeMode = 'remote'）下，此文件中的数据不应作为数据来源出现；
// 该模式下首页数据由 Track B 后端（https://lsw666.dns.army/api）提供。
// ============================================================

import { HomeSummary, QuickEntry, DownloadFile, RecentLogin, TermInfo } from '../models/Home';
import { ScheduleItem } from '../models/Course';
import { mockSchedule } from './mockCourses';
import { mockNotices } from './mockNotices';
import { TermUtils } from '../common/utils/TermUtils';

// 教学周/本周日期按真实日期动态计算（锚点在 TermUtils.termStart），不再写死某一周。
const CURRENT_WEEK: number = TermUtils.teachingWeek();

const term: TermInfo = {
  academicYear: '2025-2026',
  semester: '第二学期',
  weekIndex: CURRENT_WEEK,
  weekStartDate: TermUtils.weekStartDateText(CURRENT_WEEK),
  weekDates: TermUtils.weekDatesOf(CURRENT_WEEK)
};

const quickEntries: QuickEntry[] = [
  { key: 'schedule', label: '我的课表', icon: 'schedule', route: 'pages/SchedulePage' },
  { key: 'grades', label: '我的成绩', icon: 'grades', route: 'pages/GradesPage' },
  { key: 'selection', label: '选课中心', icon: 'selection', route: 'pages/SelectionPage' },
  { key: 'eval', label: '量化评教', icon: 'evaluation', route: 'pages/EvalPage' },
  { key: 'exam', label: '考试安排', icon: 'exam', route: 'pages/ExamPage' },
  { key: 'notice', label: '通知公告', icon: 'notice', route: 'pages/NoticesPage' },
  { key: 'roster', label: '学籍信息', icon: 'roster', route: 'pages/RosterPage' },
  { key: 'practice', label: '实践公服', icon: 'practice', route: 'pages/PracticePage' }
];

const files: DownloadFile[] = [
  { id: 'f-1', fileName: '2025-2026 校历.pdf', fileType: 'pdf', fileSize: 154720, updatedAt: '2025-09-01', url: 'mock://files/calendar.pdf' },
  { id: 'f-2', fileName: '课表模板.xlsx', fileType: 'xlsx', fileSize: 24576, updatedAt: '2025-09-01', url: 'mock://files/template.xlsx' }
];

const recentLogin: RecentLogin = {
  loginTime: '2026-05-27 08:43',
  network: '校园 Wi-Fi',
  region: '景德镇 · 茶苑校区'
};

// 今日星期：用真实日期 MM/DD 在本周日期表中定位（与首页“今日”高亮口径一致）；
// 超出本周范围时回退 JS 星期（周日记为 7）。
function resolveTodayWeekday(t: TermInfo): number {
  const now = new Date();
  const mm = (now.getMonth() + 1).toString().padStart(2, '0');
  const dd = now.getDate().toString().padStart(2, '0');
  const idx = t.weekDates.indexOf(`${mm}/${dd}`);
  if (idx >= 0) {
    return idx + 1;
  }
  const js = now.getDay();
  return js === 0 ? 7 : js;
}

// 今日课程：按 当前教学周 + 今日星期 + 课程周次有效 筛选，且同一时段只保留一门，
// 避免出现相互冲突的多门课程（如不同教学周却同一时段的课叠加显示）。
function resolveTodayCourses(t: TermInfo): ScheduleItem[] {
  const weekday = resolveTodayWeekday(t);
  const valid = mockSchedule.filter((s) => s.weekday === weekday && s.weeks.indexOf(t.weekIndex) >= 0);
  const seenSlots: string[] = [];
  const result: ScheduleItem[] = [];
  valid.forEach((s) => {
    const slot = `${s.periodStart}-${s.periodEnd}`;
    if (seenSlots.indexOf(slot) < 0) {
      seenSlots.push(slot);
      result.push(s);
    }
  });
  return result;
}

export const mockHomeSummary: HomeSummary = {
  term,
  todayCourses: resolveTodayCourses(term),
  noticeSummary: mockNotices.slice(0, 3),
  quickEntries,
  files,
  recentLogin,
  unreadNoticeCount: mockNotices.filter((n) => !n.isRead).length
};
