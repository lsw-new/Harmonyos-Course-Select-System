// 网络请求统一封装
// 当 AppConfig.useMock = true 时，repositories 会跳过 http，直接读取 mock 数据

import http from '@ohos.net.http';
import { ApiResponse } from '../../models/Common';
import { HttpError } from './HttpError';

const DEFAULT_TIMEOUT_MS = 10000;

export type HttpMethod = 'GET' | 'POST' | 'PUT' | 'DELETE' | 'PATCH';

export interface HttpRequestOptions {
  method?: HttpMethod;
  query?: Record<string, string | number | boolean>;
  body?: Object;
  headers?: Record<string, string>;
  timeoutMs?: number;
}

function buildUrl(baseUrl: string, path: string, query?: Record<string, string | number | boolean>): string {
  const url = path.startsWith('http') ? path : `${baseUrl}${path}`;
  if (!query) {
    return url;
  }
  const search: string[] = [];
  Object.keys(query).forEach((key) => {
    const value = query[key];
    if (value === undefined || value === null) {
      return;
    }
    search.push(`${encodeURIComponent(key)}=${encodeURIComponent(String(value))}`);
  });
  if (search.length === 0) {
    return url;
  }
  return `${url}${url.includes('?') ? '&' : '?'}${search.join('&')}`;
}

export class HttpClient {
  private baseUrl: string;
  private tokenProvider?: () => string | undefined;
  private onUnauthorized?: () => void;

  constructor(baseUrl: string) {
    this.baseUrl = baseUrl;
  }

  setTokenProvider(provider: () => string | undefined): void {
    this.tokenProvider = provider;
  }

  setUnauthorizedHandler(handler: () => void): void {
    this.onUnauthorized = handler;
  }

  async request<T>(path: string, options: HttpRequestOptions = {}): Promise<T> {
    const method = options.method ?? 'GET';
    const url = buildUrl(this.baseUrl, path, options.query);
    const httpRequest = http.createHttp();

    const headers: Record<string, string> = {
      'Content-Type': 'application/json'
    };
    if (options.headers) {
      Object.keys(options.headers).forEach((key) => {
        headers[key] = options.headers![key];
      });
    }
    if (this.tokenProvider) {
      const token = this.tokenProvider();
      if (token) {
        headers['Authorization'] = `Bearer ${token}`;
      }
    }

    try {
      const response = await httpRequest.request(url, {
        method: method as http.RequestMethod,
        header: headers,
        extraData: options.body ? JSON.stringify(options.body) : undefined,
        connectTimeout: options.timeoutMs ?? DEFAULT_TIMEOUT_MS,
        readTimeout: options.timeoutMs ?? DEFAULT_TIMEOUT_MS
      });

      const status = response.responseCode;
      const raw = typeof response.result === 'string'
        ? response.result
        : JSON.stringify(response.result);
      if (status === 401) {
        if (this.onUnauthorized) {
          this.onUnauthorized();
        }
        throw HttpError.fromStatus(401, HttpClient.extractError(raw));
      }
      if (status < 200 || status >= 300) {
        // 优先用后端信封里的精确错误文案（如限流「发送过于频繁」），而非笼统的状态码默认提示
        throw HttpError.fromStatus(status, HttpClient.extractError(raw));
      }

      const parsed = JSON.parse(raw) as ApiResponse<T>;
      if (!parsed.success) {
        throw new HttpError('business', parsed.error ?? parsed.message ?? '业务异常', status);
      }
      return parsed.data as T;
    } catch (e) {
      if (e instanceof HttpError) {
        throw e;
      }
      throw HttpError.network(`网络异常：${(e as Error).message ?? ''}`);
    } finally {
      httpRequest.destroy();
    }
  }

  // 非 2xx 时尝试解析响应体信封，取后端给出的错误文案；响应体非 JSON（如网关错误页）则回退状态码默认文案。
  private static extractError(raw: string): string | undefined {
    try {
      const parsed = JSON.parse(raw) as ApiResponse<Object>;
      if (typeof parsed.error === 'string' && parsed.error.length > 0) {
        return parsed.error;
      }
      if (typeof parsed.message === 'string' && parsed.message.length > 0) {
        return parsed.message;
      }
    } catch (e) {
      // 忽略解析失败，走默认文案
    }
    return undefined;
  }

  get<T>(path: string, query?: Record<string, string | number | boolean>): Promise<T> {
    return this.request<T>(path, { method: 'GET', query });
  }

  post<T>(path: string, body?: Object): Promise<T> {
    return this.request<T>(path, { method: 'POST', body });
  }

  put<T>(path: string, body?: Object): Promise<T> {
    return this.request<T>(path, { method: 'PUT', body });
  }

  delete<T>(path: string, body?: Object): Promise<T> {
    return this.request<T>(path, { method: 'DELETE', body });
  }

  patch<T>(path: string, body?: Object): Promise<T> {
    return this.request<T>(path, { method: 'PATCH', body });
  }
}
