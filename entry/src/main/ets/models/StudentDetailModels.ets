// 学籍详情模型 · Étudiant

// 学籍状态：在读 / 休学 / 毕业班 / 已毕业
export type StudentStatus = 'active' | 'suspended' | 'graduating' | 'graduated';

// 学生完整档案（详情页使用）
export interface StudentDetail {
  studentId: string;
  name: string;
  gender: string;
  college: string;
  major: string;
  className: string;
  grade: string;
  gpa: number;
  earnedCredits: number;
  totalCredits: number;
  phone: string;
  email: string;
  dormitory: string;
  advisor: string;
  status: StudentStatus;
  enrollDate: string;
}
