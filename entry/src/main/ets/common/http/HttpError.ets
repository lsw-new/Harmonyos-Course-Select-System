// 统一错误对象

export type HttpErrorKind =
  | 'network'
  | 'timeout'
  | 'unauthorized'
  | 'forbidden'
  | 'notFound'
  | 'server'
  | 'business'
  | 'cancel'
  | 'unknown';

export class HttpError extends Error {
  kind: HttpErrorKind;
  status?: number;
  cause?: Object;

  constructor(kind: HttpErrorKind, message: string, status?: number, cause?: Object) {
    super(message);
    this.kind = kind;
    this.status = status;
    this.cause = cause;
  }

  static fromStatus(status: number, message?: string): HttpError {
    if (status === 401) {
      return new HttpError('unauthorized', message ?? '请重新登录', status);
    }
    if (status === 403) {
      return new HttpError('forbidden', message ?? '没有权限执行该操作', status);
    }
    if (status === 404) {
      return new HttpError('notFound', message ?? '请求的资源不存在', status);
    }
    if (status >= 500) {
      return new HttpError('server', message ?? '服务暂不可用，请稍后再试', status);
    }
    return new HttpError('business', message ?? '请求失败', status);
  }

  static network(message: string = '网络异常，请检查连接'): HttpError {
    return new HttpError('network', message);
  }

  static unknown(message: string = '未知错误'): HttpError {
    return new HttpError('unknown', message);
  }
}

export function isUnauthorized(err: Object): boolean {
  return err instanceof HttpError && err.kind === 'unauthorized';
}
