// 请假、反馈、实践 等扩展模型

import { ApprovalStepVm } from './Admin';

export type LeaveType = 'sick' | 'personal' | 'public' | 'other';
export type ApprovalState = 'pending' | 'approved' | 'rejected' | 'withdrawn';

export interface LeaveRequest {
  id: string;
  type: LeaveType;
  startDate: string;
  endDate: string;
  reason: string;
  attachments: string[];
  state: ApprovalState;
  submittedAt: string;
  feedback?: string;
  // #7 多级审批进度（按 order 有序）；旧记录或后端未下发时为 []
  steps?: ApprovalStepVm[];
}

export type FeedbackCategory = 'bug' | 'suggestion' | 'service' | 'other';
export type FeedbackState = 'submitted' | 'processing' | 'closed';

export interface FeedbackItem {
  id: string;
  category: FeedbackCategory;
  title: string;
  content: string;
  contact: string;
  screenshots: string[];
  submittedAt: string;
  state: 'submitted' | 'processing' | 'closed';
  reply?: string;
  repliedBy?: string;
  repliedByName?: string;
  repliedAt?: string;
  studentId?: string;
  studentName?: string;
}

export interface PracticeEntry {
  key: string;
  label: string;
  description: string;
  available: boolean;
  url?: string;
}
