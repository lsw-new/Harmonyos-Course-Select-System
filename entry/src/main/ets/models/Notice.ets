// 通知与公告

export interface NoticeAttachment {
  id: string;
  fileName: string;
  fileUrl: string;
  fileSize?: number;
  updatedAt?: string;
}

export interface Notice {
  id: string;
  title: string;
  publisher: string;
  publishedAt: string;
  summary: string;
  content: string;
  isRead: boolean;
  category: string;
  attachments: NoticeAttachment[];
}

export interface NoticeCategoryFilter {
  key: string;
  label: string;
  count?: number;
}
