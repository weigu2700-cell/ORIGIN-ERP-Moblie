import { appConfig } from '@/config/env';
import type { ApiResult, AppErrorDetails, AppErrorKind, RequestOptions } from '@/types/api';
import { getToken, removeToken } from '@/utils/auth';

export class AppError extends Error {
  readonly kind: AppErrorKind;
  readonly code?: number;
  readonly statusCode?: number;
  readonly data?: unknown;
  readonly retryable: boolean;
  readonly requestId?: string;

  constructor(message: string, details: AppErrorDetails) {
    super(message);
    this.name = 'AppError';
    this.kind = details.kind;
    this.code = details.code;
    this.statusCode = details.statusCode;
    this.data = details.data;
    this.retryable = details.retryable ?? false;
    this.requestId = details.requestId;
  }
}

export function isAppError(error: unknown): error is AppError {
  return error instanceof AppError;
}

const SUCCESS_CODE = 200;
const UNAUTHORIZED_CODE = 401;
let handlingUnauthorized = false;

function isAbsoluteUrl(url: string) {
  return /^https?:\/\//i.test(url);
}

function joinUrl(baseUrl: string, path: string) {
  if (isAbsoluteUrl(path)) return path;
  return `${baseUrl}/${path.replace(/^\/+/, '')}`;
}

export function getApiConfigurationError(url = ''): AppError | null {
  if (isAbsoluteUrl(url) || appConfig.apiBaseUrlConfigured) return null;
  return new AppError(appConfig.apiBaseUrlError || 'API 地址未配置', {
    kind: 'contract',
  });
}

function appendQuery(url: string, query?: Record<string, unknown>) {
  if (!query) return url;

  const values: string[] = [];
  Object.entries(query).forEach(([key, value]) => {
    if (value === undefined || value === null || value === '') return;
    const items = Array.isArray(value) ? value : [value];
    items.forEach((item) => {
      values.push(`${encodeURIComponent(key)}=${encodeURIComponent(String(item))}`);
    });
  });

  if (!values.length) return url;
  return `${url}${url.includes('?') ? '&' : '?'}${values.join('&')}`;
}

function showError(message: string) {
  uni.showToast({
    title: message,
    icon: 'none',
    duration: 2200,
  });
}

function handleUnauthorized() {
  removeToken();
  if (handlingUnauthorized) return;

  handlingUnauthorized = true;
  uni.reLaunch({
    url: '/pages/login/login',
    complete: () => {
      handlingUnauthorized = false;
    },
  });
}

function createNetworkError(error: UniApp.GeneralCallbackResult, retryable: boolean) {
  const rawMessage = error.errMsg || '';
  const isTimeout = /timeout/i.test(rawMessage);
  return new AppError(isTimeout ? '请求超时，请检查网络后重试' : '网络连接失败，请稍后重试', {
    kind: isTimeout ? 'timeout' : 'network',
    data: error,
    retryable,
  });
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function parseApiResult<T>(value: unknown): ApiResult<T> | null {
  if (!isRecord(value) || typeof value.code !== 'number' || typeof value.msg !== 'string') {
    return null;
  }
  if (!('data' in value)) return null;
  return value as unknown as ApiResult<T>;
}

function getResponseMessage(value: unknown) {
  if (!isRecord(value)) return '';
  const message = value.msg ?? value.message ?? value.error;
  return typeof message === 'string' ? message : '';
}

function getRequestId(header: Record<string, string> | undefined) {
  if (!header) return undefined;
  const key = Object.keys(header).find((name) => name.toLowerCase() === 'x-request-id');
  return key ? header[key] : undefined;
}

function getErrorKind(statusCode?: number, code?: number): AppErrorKind {
  const effectiveCode = [code, statusCode].find(
    (value) => value === 400 || value === 401 || value === 403 || value === 409 || value === 422,
  );
  if (effectiveCode === 401) return 'unauthorized';
  if (effectiveCode === 403) return 'forbidden';
  if (effectiveCode === 409) return 'conflict';
  if (effectiveCode === 400 || effectiveCode === 422) return 'validation';
  return 'server';
}

function isReadMethod(method: RequestOptions['method']) {
  return method === 'GET' || method === 'HEAD' || method === 'OPTIONS';
}

export function request<T>(options: RequestOptions): Promise<T> {
  const {
    url,
    method = 'GET',
    data,
    query,
    headers = {},
    timeout = appConfig.requestTimeout,
    auth = true,
    showError: shouldShowError = true,
  } = options;

  const configurationError = getApiConfigurationError(url);
  if (configurationError) {
    if (shouldShowError) showError(configurationError.message);
    return Promise.reject(configurationError);
  }

  const token = auth ? getToken() : '';
  const header: Record<string, string> = {
    'Content-Type': 'application/json',
    ...headers,
  };
  if (token) header.Authorization = `Bearer ${token}`;

  return new Promise((resolve, reject) => {
    uni.request({
      url: appendQuery(joinUrl(appConfig.apiBaseUrl, url), query),
      method,
      data: data as UniApp.RequestOptions['data'],
      header,
      timeout,
      success: (response: UniNamespace.RequestSuccessCallbackResult) => {
        const result = parseApiResult<T>(response.data);
        const responseCode = result?.code;
        const isUnauthorized =
          response.statusCode === UNAUTHORIZED_CODE || responseCode === UNAUTHORIZED_CODE;
        const requestId = getRequestId(response.header as Record<string, string> | undefined);

        if (isUnauthorized) handleUnauthorized();

        if (response.statusCode < 200 || response.statusCode >= 300) {
          const kind = getErrorKind(response.statusCode, responseCode);
          const error = new AppError(
            getResponseMessage(response.data) || `请求失败（${response.statusCode}）`,
            {
              kind,
              code: responseCode,
              statusCode: response.statusCode,
              data: result?.data ?? response.data,
              retryable: kind === 'server' && isReadMethod(method),
              requestId,
            },
          );
          if (shouldShowError && !isUnauthorized) showError(error.message);
          reject(error);
          return;
        }

        if (!result) {
          const error = new AppError('服务响应格式异常', {
            kind: 'contract',
            statusCode: response.statusCode,
            data: response.data,
            requestId,
          });
          if (shouldShowError) showError(error.message);
          reject(error);
          return;
        }

        if (result.code !== SUCCESS_CODE) {
          const kind = getErrorKind(response.statusCode, result.code);
          const error = new AppError(result.msg || '请求失败', {
            kind,
            code: result.code,
            statusCode: response.statusCode,
            data: result.data,
            retryable: kind === 'server' && isReadMethod(method),
            requestId,
          });
          if (shouldShowError && !isUnauthorized) showError(error.message);
          reject(error);
          return;
        }

        resolve(result.data);
      },
      fail: (failure: UniNamespace.GeneralCallbackResult) => {
        const error = createNetworkError(failure, isReadMethod(method));
        if (shouldShowError) showError(error.message);
        reject(error);
      },
    });
  });
}

export function get<T>(
  url: string,
  query?: Record<string, unknown>,
  options: Omit<RequestOptions, 'url' | 'method' | 'query'> = {},
) {
  return request<T>({ ...options, url, query, method: 'GET' });
}

export function post<T>(
  url: string,
  data?: unknown,
  options: Omit<RequestOptions, 'url' | 'method' | 'data'> = {},
) {
  return request<T>({ ...options, url, data, method: 'POST' });
}

export function put<T>(
  url: string,
  data?: unknown,
  options: Omit<RequestOptions, 'url' | 'method' | 'data'> = {},
) {
  return request<T>({ ...options, url, data, method: 'PUT' });
}

export function del<T>(
  url: string,
  data?: unknown,
  options: Omit<RequestOptions, 'url' | 'method' | 'data'> = {},
) {
  return request<T>({ ...options, url, data, method: 'DELETE' });
}
