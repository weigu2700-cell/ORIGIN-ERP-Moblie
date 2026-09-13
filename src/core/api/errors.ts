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
  if (error && typeof error === 'object') {
    const err = error as Record<string, unknown>;
    return {
      kind: (err.kind as AppErrorKind) || 'server',
      message: typeof err.message === 'string' ? err.message : '未知错误',
      code: typeof err.code === 'number' ? err.code : undefined,
      statusCode: typeof err.statusCode === 'number' ? err.statusCode : undefined,
      retryable: Boolean(err.retryable),
      requestId: typeof err.requestId === 'string' ? err.requestId : undefined,
    };
  }
  return {
    kind: 'server',
    message: '未知错误',
    retryable: false,
  };
}