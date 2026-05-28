// 首页聚合数据模型

import { ScheduleItem } from './Course';
import { Notice } from './Notice';

export interface TermInfo {
  academicYear: string;
  semester: string;
  weekIndex: number;
  weekStartDate: string;
  weekDates: string[];
}

export interface QuickEntry {
  key: string;
  label: string;
  icon: string;
  route: string;
}

export interface DownloadFile {
  id: string;
  fileName: string;
  fileType: string;
  fileSize?: number;
  updatedAt: string;
  url: string;
}

export interface RecentLogin {
  loginTime: string;
  network: string;
  region: string;
}

export interface HomeSummary {
  term: TermInfo;
  todayCourses: ScheduleItem[];
  noticeSummary: Notice[];
  quickEntries: QuickEntry[];
  files: DownloadFile[];
  recentLogin?: RecentLogin;
  unreadNoticeCount: number;
}
