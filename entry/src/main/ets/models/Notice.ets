// 通知与公告

export interface NoticeAttachment {
  id: string;
  fileName: string;
  fileUrl: string;
  fileSize?: number;
  updatedAt?: string;
}

// urgency 仅由后端「通知发布」决定：'normal' 普通；'important' 重要（强制弹窗，立刻可关）；
// 'urgent' 紧急（强制弹窗，5 秒倒计时后可关）。Notice 始终带 urgency，缺省 'normal' 等价普通通知。
export interface Notice {
  id: string;
  title: string;
  publisher: string;
  publishedAt: string;
  summary: string;
  content: string;
  isRead: boolean;
  category: string;
  urgency: string;
  attachments: NoticeAttachment[];
}

export interface NoticeCategoryFilter {
  key: string;
  label: string;
  count?: number;
}
