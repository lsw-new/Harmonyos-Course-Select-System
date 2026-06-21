// 教师端模型（roadmap #6）。与学生/管理员资料并列；身份字段来自登录下发的 profile。

export interface TeacherProfile {
  teacherId: string;
  name: string;
  college: string;
  title: string;
  email: string;
}

// 工作台概览四项
export interface TeacherDashboard {
  courseCount: number;
  studentCount: number;
  pendingGradeCount: number;
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
  status: string;
}

// 某课程学生名单返回
export interface TeacherCourseStudents {
  courseId: string;
  term: string;
  teachingClassName: string;
  students: TeacherStudent[];
}

// 评教聚合一行
export interface TeacherEval {
  courseId: string;
  courseName: string;
  term: string;
  taskCount: number;
  submittedCount: number;
}

// 录入成绩入参一行
export interface TeacherScoreInput {
  studentId: string;
  score: number;
}
