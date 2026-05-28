// 通用响应与分页

export interface PageMeta {
  total: number;
  page: number;
  pageSize: number;
}

export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
  meta?: PageMeta;
}

export interface PageState<T> {
  loading: boolean;
  refreshing: boolean;
  error?: string;
  data?: T;
}
