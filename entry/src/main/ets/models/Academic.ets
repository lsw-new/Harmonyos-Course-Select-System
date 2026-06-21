// 学业 · 成绩、考试、学籍

export type GradePublishStatus = 'draft' | 'published' | 'pendingAudit' | 'inputting' | 'appealed' | 'rejected';

export interface GradeRecord {
  id: string;
  term: string;
  courseCode: string;
  teachingClassNo: string;
  courseName: string;
  courseCategory: string;
  credit: number;
  midtermScore?: number | string;
  finalExamScore?: number | string;
  totalScore?: number | string;
  finalScore?: number | string;
  gradePoint?: number | string;
  rank?: number;
  // 发布状态：仅 published 的成绩对学生可见
  status?: GradePublishStatus;
  publishedAt?: string;
}

export interface GradeSummary {
  term: string;
  earnedCredits: number;
  weightedAverage: number;
  termGpa: number;
  totalGpa: number;
}

export interface ExamArrangement {
  id: string;
  term: string;
  courseName: string;
  examType: string;
  date: string;
  startTime: string;
  endTime: string;
  classroom: string;
  seatNo?: string;
  notice?: string;
}

export interface StudentRecord {
  studentId: string;
  name: string;
  englishName?: string;
  gender: string;
  grade: string;
  schoolingLength: string;
  educationLevel: string;
  studentCategory: string;
  major: string;
  college: string;
  administrativeCollege: string;
  direction?: string;
  className: string;
  entranceDate: string;
  graduationDate?: string;
  studyMode: string;
  isRegistered: boolean;
  isAtSchool: boolean;
  campus: string;
  recordStatus: string;
  effectiveDate: string;
  hasRecord: boolean;
  isOnJob?: boolean;
  remark?: string;
  photoUrl?: string;
  // 真实聚合（remote /api/profile/record）：平均绩点 / 已修学分 / 已修门数（按已发布成绩计算）
  gpaText?: string;
  earnedCredits?: number;
  passedCount?: number;
  // 学籍注册字段（roadmap #3）：来自后端 DB，null 表示未填
  // 注：educationLevel 已在上方定义（原 mock 字段），此处不重复。
  // programLength 对应学制（补充 schoolingLength mock 字段），enrollmentStatus 对应学籍状态。
  politicalStatus?: string | null;
  ethnicity?: string | null;
  nativePlace?: string | null;
  enrollmentDate?: string | null;
  programLength?: string | null;
  enrollmentStatus?: string | null;
}
