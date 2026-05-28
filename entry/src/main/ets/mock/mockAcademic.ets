import { GradeRecord, GradeSummary, ExamArrangement, StudentRecord } from '../models/Academic';

export const mockGrades: GradeRecord[] = [
  {
    id: 'g-1', term: '2025-2026-1',
    courseCode: 'CS101', teachingClassNo: '01', courseName: '数据结构与算法',
    courseCategory: '必修', credit: 4,
    midtermScore: 86, finalExamScore: 92, totalScore: 90, finalScore: 90, gradePoint: 3.9
  },
  {
    id: 'g-2', term: '2025-2026-1',
    courseCode: 'LIT201', teachingClassNo: '02', courseName: '中国古典文学赏析',
    courseCategory: '选修', credit: 2,
    midtermScore: 88, finalExamScore: 95, totalScore: 92, finalScore: 92, gradePoint: 4.0
  },
  {
    id: 'g-3', term: '2025-2026-1',
    courseCode: 'MATH101', teachingClassNo: '03', courseName: '高等数学（上）',
    courseCategory: '必修', credit: 5,
    midtermScore: 78, finalExamScore: 81, totalScore: 80, finalScore: 80, gradePoint: 3.3
  },
  {
    id: 'g-4', term: '2025-2026-1',
    courseCode: 'PE001', teachingClassNo: '01', courseName: '形体训练',
    courseCategory: '必修', credit: 1,
    totalScore: '合格', finalScore: '合格'
  },
  {
    id: 'g-5', term: '2025-2026-2',
    courseCode: 'ENG201', teachingClassNo: '04', courseName: '大学英语 III',
    courseCategory: '必修', credit: 3,
    totalScore: '暂未发布'
  }
];

export const mockGradeSummary: GradeSummary[] = [
  { term: '2025-2026-1', earnedCredits: 12, weightedAverage: 87.6, termGpa: 3.72, totalGpa: 3.65 },
  { term: '2025-2026-2', earnedCredits: 0, weightedAverage: 0, termGpa: 0, totalGpa: 3.65 }
];

export const mockExams: ExamArrangement[] = [
  {
    id: 'e-1', term: '2025-2026-2', courseName: '数据结构与算法',
    examType: '期末闭卷', date: '2026-06-22', startTime: '09:00', endTime: '11:00',
    classroom: '理工楼 305', seatNo: 'A-12', notice: '禁止携带电子设备。'
  },
  {
    id: 'e-2', term: '2025-2026-2', courseName: '高等数学（下）',
    examType: '期末闭卷', date: '2026-06-25', startTime: '14:00', endTime: '16:00',
    classroom: '理工楼 102', seatNo: 'B-08'
  },
  {
    id: 'e-3', term: '2025-2026-2', courseName: '中国古典文学赏析',
    examType: '论文', date: '2026-06-15', startTime: '—', endTime: '—',
    classroom: '线上提交'
  }
];

export const mockStudentRecord: StudentRecord = {
  studentId: '202221001234',
  name: '林夏',
  englishName: 'Lin Xia',
  gender: '女',
  grade: '2022 级',
  schoolingLength: '4 年',
  educationLevel: '本科',
  studentCategory: '普通本科生',
  major: '汉语言文学',
  college: '人文与艺术学院',
  administrativeCollege: '人文与艺术学院',
  direction: '文学方向',
  className: '汉文 2202',
  entranceDate: '2022-09-01',
  graduationDate: '2026-06-30',
  studyMode: '全日制',
  isRegistered: true,
  isAtSchool: true,
  campus: '玫瑰校区',
  recordStatus: '在籍在校',
  effectiveDate: '2022-09-01',
  hasRecord: true,
  remark: '—'
};
