// 学业 · 成绩、考试、学籍

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
}
