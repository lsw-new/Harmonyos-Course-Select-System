// 仓储基类 · 提供 mock 延迟与统一错误转换

import { AppConfig } from '../app/AppConfig';
import { HttpError } from '../common/http/HttpError';
import { apiClient } from '../common/http/ApiClient';
import { HttpClient } from '../common/http/HttpClient';

export class BaseRepository {
  protected http: HttpClient = apiClient;

  protected delay<T>(value: T, ms: number = AppConfig.mockDelayMs): Promise<T> {
    return new Promise<T>((resolve) => {
      setTimeout(() => resolve(value), ms);
    });
  }

  protected delayCopy<T>(value: T, ms: number = AppConfig.mockDelayMs): Promise<T> {
    // ArkTS 不允许直接 spread Object，所以这里走 JSON 拷贝
    const cloned: T = JSON.parse(JSON.stringify(value)) as T;
    return this.delay(cloned, ms);
  }

  protected reject(message: string, kind: 'business' | 'forbidden' | 'unauthorized' | 'notFound' = 'business'): Promise<never> {
    return Promise.reject(new HttpError(kind, message));
  }
}
