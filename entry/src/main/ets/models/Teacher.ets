// 教师端模型（roadmap #6）。与学生/管理员资料并列；身份字段来自登录下发的 profile。

export interface TeacherProfile {
  teacherId: string;
  name: string;
  college: string;
  title: string;
  email: string;
  avatarUrl: string;
}

// 工作台概览
export interface TeacherDashboard {
  courseCount: number;
  studentCount: number;
  pendingGradeCount: number;
  evalAvg: number | null;
  evalSubmitted: number;
}

// 我的课程（一条 = 一个教学班成绩任务）
export interface TeacherCourse {
  courseId: string;
  taskId: string;
  code: string;
  name: string;
  category: string;
  credit: number;
  teachingClassName: string;
  term: string;
  studentCount: number;
  gradeStatus: string;
  inputProgress: number;
}

// 课程学生一行（含当前成绩）
export interface TeacherStudent {
  studentId: string;
  name: string;
  className: string;
  score: number | null;
  gradePoint: number | null;
  rank: number | null;
  status: string;
}

// 某课程学生名单返回
export interface TeacherCourseStudents {
  courseId: string;
  term: string;
  teachingClassName: string;
  published: boolean;
  students: TeacherStudent[];
}

// 评教聚合一行
export interface TeacherEval {
  courseId: string;
  courseName: string;
  term: string;
  taskCount: number;
  submittedCount: number;
  avgScore: number | null;
}

// 录入成绩入参一行
export interface TeacherScoreInput {
  studentId: string;
  score: number;
}

// 教师发布的课程通知一行
export interface TeacherNotice {
  noticeId: string;
  title: string;
  summary: string;
  category: string;
  urgency: string;
  publishedAt: string;
}

// 某课程成绩分布
export interface TeacherGradeDistribution {
  excellent: number;
  good: number;
  medium: number;
  pass: number;
  fail: number;
  total: number;
  avgScore: number;
}

// 课表一项
export interface TeacherScheduleItem {
  itemId: string;
  courseName: string;
  className: string;
  weekday: number;
  periodStart: number;
  periodEnd: number;
  startTime: string;
  endTime: string;
  classroom: string;
  weekText: string;
  term: string;
}

// 我所授课程收到的成绩申诉一行
export interface TeacherAppeal {
  appealId: string;
  studentId: string;
  studentName: string;
  courseId: string;
  courseName: string;
  term: string;
  reason: string;
  status: string;
  reply: string;
  submittedAt: string;
}
