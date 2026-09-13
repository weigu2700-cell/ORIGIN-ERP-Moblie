export interface ApiResult<T> {
  code: number;
  msg: string;
  data: T;
}

export type AppErrorKind =
  | 'network'
  | 'timeout'
  | 'unauthorized'
  | 'forbidden'
  | 'validation'
  | 'conflict'
  | 'server'
  | 'contract';

export interface AppErrorDetails {
  kind: AppErrorKind;
  code?: number;
  statusCode?: number;
  data?: unknown;
  retryable?: boolean;
  requestId?: string;
}

export interface RequestOptions {
  url: string;
  method?: UniApp.RequestOptions['method'];
  data?: unknown;
  query?: Record<string, unknown>;
  headers?: Record<string, string>;
  timeout?: number;
  auth?: boolean;
  showError?: boolean;
}
