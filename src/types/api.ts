export interface ApiResult<T> {
  code: number;
  msg: string;
  data: T;
}

export interface RequestOptions {
  url: string;
  method?: UniApp.RequestOptions["method"];
  data?: unknown;
  query?: Record<string, unknown>;
  headers?: Record<string, string>;
  timeout?: number;
  auth?: boolean;
  showError?: boolean;
}
