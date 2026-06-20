// 实践项目模型 · Practice
// 实践与公服模块的项目列表 / 详情数据契约。

export type PracticeCategory = 'internship' | 'research' | 'social' | 'volunteer';

// 列表项：携带由持久化报名状态派生的 signedUp。
export interface PracticeProject {
  id: string;
  title: string;
  org: string;
  category: PracticeCategory;
  credits: number;
  period: string;
  slotsTotal: number;
  slotsTaken: number;
  signedUp: boolean;
}

// 详情：在列表项基础上扩展描述、要求、导师、地点等。
export interface PracticeProjectDetail {
  id: string;
  title: string;
  org: string;
  category: PracticeCategory;
  credits: number;
  period: string;
  location: string;
  mentor: string;
  slotsTotal: number;
  slotsTaken: number;
  signedUp: boolean;
  description: string;
  requirements: string[];
}

// 持久化的报名记录：存项目 id（signedAt 为可选报名时间戳），避免与种子数据耦合。
export interface PracticeSignupRecord {
  id: string;
  signedAt?: string;
}

// 实践成果提交状态：已提交 / 已评分 / 已通过 / 已驳回
export type PracticeSubmissionStatus = 'submitted' | 'scored' | 'passed' | 'rejected';

// 学生端·我的实践成果提交（一项目一份）
export interface PracticeSubmission {
  submissionId: string;
  projectId: string;
  studentId: string;
  content: string;
  attachments: string[];
  status: PracticeSubmissionStatus;
  score: number | null;
  feedback: string;
  scoredAt: string;
  submittedAt: string;
  updatedAt: string;
}
