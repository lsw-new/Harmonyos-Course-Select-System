// 请假、反馈、实践 等扩展模型

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
}

export type FeedbackCategory = 'bug' | 'suggestion' | 'service' | 'other';

export interface FeedbackItem {
  id: string;
  category: FeedbackCategory;
  title: string;
  content: string;
  contact: string;
  screenshots: string[];
  submittedAt: string;
  state: 'submitted' | 'processing' | 'closed';
}

export interface PracticeEntry {
  key: string;
  label: string;
  description: string;
  available: boolean;
  url?: string;
}
