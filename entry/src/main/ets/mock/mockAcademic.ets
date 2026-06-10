import { GradeRecord, GradeSummary, ExamArrangement, StudentRecord } from '../models/Academic';

// 仅 status === 'published' 的成绩对学生端可见。
// 课程与「我的课表」同源：23计算机科学与技术U9 班级课表的 9 门真实课程（联机模式成绩由管理端打分发布）。
export const mockGrades: GradeRecord[] = [
  {
    id: 'g-VDZ02119204', term: '2025-2026-2',
    courseCode: 'VDZ02119204', teachingClassNo: 'U9', courseName: '鸿蒙应用开发初级认证',
    courseCategory: '必修', credit: 2,
    totalScore: 92, finalScore: 92, gradePoint: 4.0,
    status: 'published', publishedAt: '2026-06-10T10:00:00.000Z'
  },
  {
    id: 'g-VDZ02119303', term: '2025-2026-2',
    courseCode: 'VDZ02119303', teachingClassNo: 'U9', courseName: '鸿蒙移动应用开发综合实践',
    courseCategory: '必修', credit: 2,
    totalScore: 90, finalScore: 90, gradePoint: 4.0,
    status: 'published', publishedAt: '2026-06-10T10:00:00.000Z'
  },
  {
    id: 'g-VDZ02114904', term: '2025-2026-2',
    courseCode: 'VDZ02114904', teachingClassNo: 'U9', courseName: '软件测试与管理',
    courseCategory: '必修', credit: 2,
    totalScore: 86, finalScore: 86, gradePoint: 3.6,
    status: 'published', publishedAt: '2026-06-10T10:00:00.000Z'
  },
  {
    id: 'g-VDZ02115104', term: '2025-2026-2',
    courseCode: 'VDZ02115104', teachingClassNo: 'U9', courseName: '大型数据库管理与维护',
    courseCategory: '必修', credit: 2,
    totalScore: 84, finalScore: 84, gradePoint: 3.4,
    status: 'published', publishedAt: '2026-06-10T10:00:00.000Z'
  },
  {
    id: 'g-VDZ02112704', term: '2025-2026-2',
    courseCode: 'VDZ02112704', teachingClassNo: 'U9', courseName: '计算机组成原理',
    courseCategory: '必修', credit: 2,
    totalScore: 81, finalScore: 81, gradePoint: 3.1,
    status: 'published', publishedAt: '2026-06-10T10:00:00.000Z'
  },
  {
    id: 'g-VDZ02102903', term: '2025-2026-2',
    courseCode: 'VDZ02102903', teachingClassNo: 'U9', courseName: '软件工程',
    courseCategory: '必修', credit: 2,
    totalScore: 88, finalScore: 88, gradePoint: 3.8,
    status: 'published', publishedAt: '2026-06-10T10:00:00.000Z'
  },
  {
    id: 'g-VDZ02103003', term: '2025-2026-2',
    courseCode: 'VDZ02103003', teachingClassNo: 'U9', courseName: '编译原理',
    courseCategory: '必修', credit: 2,
    totalScore: 79, finalScore: 79, gradePoint: 2.9,
    status: 'published', publishedAt: '2026-06-10T10:00:00.000Z'
  },
  {
    id: 'g-VMK01100203', term: '2025-2026-2',
    courseCode: 'VMK01100203', teachingClassNo: 'U9', courseName: '中国近现代史纲要',
    courseCategory: '公选', credit: 2,
    totalScore: 91, finalScore: 91, gradePoint: 4.0,
    status: 'published', publishedAt: '2026-06-10T10:00:00.000Z'
  },
  {
    id: 'g-VJW01102302', term: '2025-2026-2',
    courseCode: 'VJW01102302', teachingClassNo: 'U9', courseName: '博物馆展览鉴赏',
    courseCategory: '公选', credit: 2,
    totalScore: '暂未发布',
    status: 'pendingAudit'
  }
];

export const mockGradeSummary: GradeSummary[] = [
  { term: '2025-2026-2', earnedCredits: 16, weightedAverage: 86.4, termGpa: 3.6, totalGpa: 3.6 }
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
  studentId: '2023307020941',
  name: '李仕炜',
  englishName: 'Lin Xia',
  gender: '男',
  grade: '2023 级',
  schoolingLength: '4 年',
  educationLevel: '本科',
  studentCategory: '普通本科生',
  major: '计算机科学与技术',
  college: '电子信息工程学院',
  administrativeCollege: '电子信息工程学院',
  direction: '文学方向',
  className: '23计科U9',
  entranceDate: '2022-09-01',
  graduationDate: '2026-06-30',
  studyMode: '全日制',
  isRegistered: true,
  isAtSchool: true,
  campus: '茶苑校区',
  recordStatus: '在籍在校',
  effectiveDate: '2022-09-01',
  hasRecord: true,
  remark: '—'
};
