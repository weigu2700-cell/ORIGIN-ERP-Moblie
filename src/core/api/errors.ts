/**
 * API 错误模型 —— 文档 4.1 节定义。
 */
import type { AppErrorKind, AppErrorDetails } from '@/types/api';

export type { AppErrorKind, AppErrorDetails };

export interface ErrorContext {
  kind: AppErrorKind;
  message: string;
  code?: number;
  statusCode?: number;
  retryable: boolean;
  requestId?: string;
  documentType?: string;
  action?: string;
}

export function errorContextFromAppError(error: unknown): ErrorContext {
  return classifyError(error);
}

export function classifyError(error: unknown): ErrorContext {
  if (error && typeof error === 'object') {
    const err = error as Record<string, unknown>;
    const statusCode =
      typeof err.statusCode === 'number' ? err.statusCode : undefined;
    const message = typeof err.message === 'string' ? err.message : '';
    const kind = deriveKind(statusCode, message);
    return {
      kind,
      message: message || '未知错误',
      statusCode,
      retryable: isRetryableError(kind),
    };
  }
  return {
    kind: 'unknown',
    message: '未知错误',
    retryable: false,
  };
}

function deriveKind(
  statusCode?: number,
  message?: string,
): AppErrorKind {
  if (!statusCode) {
    if (message && /fetch|network|connect/i.test(message))
      return 'network';
    if (message && /timeout|timed out/i.test(message))
      return 'timeout';
    return 'unknown';
  }
  switch (statusCode) {
    case 400:
      return 'validation';
    case 401:
      return 'unauthorized';
    case 403:
      return 'forbidden';
    case 404:
      return 'notFound';
    case 409:
      return 'conflict';
    case 422:
      return 'validation';
    case 500:
    case 502:
    case 503:
    case 504:
      return 'server';
    default:
      return 'unknown';
  }
}

export function isRetryableError(kind: AppErrorKind): boolean {
  return kind === 'network' || kind === 'timeout' || kind === 'server';
}