/**
 * 通用异步状态模型。
 * 文档要求：loading/empty/error/offline/forbidden/conflict/success 均有可恢复界面。
 */
export type AsyncStatus =
  | 'idle'
  | 'loading'
  | 'ready'
  | 'empty'
  | 'error'
  | 'offline'
  | 'forbidden'
  | 'conflict';

export interface AsyncState<T> {
  status: AsyncStatus;
  data: T | null;
  error: string;
  lastUpdatedAt: Date | null;
}

export function idleAsyncState<T>(initialData: T | null = null): AsyncState<T> {
  return {
    status: 'idle',
    data: initialData,
    error: '',
    lastUpdatedAt: null,
  };
}

export function loadingAsyncState<T>(prev: AsyncState<T>): AsyncState<T> {
  return {
    status: 'loading',
    data: prev.data,
    error: '',
    lastUpdatedAt: prev.lastUpdatedAt,
  };
}

export function readyAsyncState<T>(data: T): AsyncState<T> {
  return {
    status: 'ready',
    data,
    error: '',
    lastUpdatedAt: new Date(),
  };
}

export function emptyAsyncState<T>(): AsyncState<T> {
  return {
    status: 'empty',
    data: null,
    error: '',
    lastUpdatedAt: new Date(),
  };
}

export function errorAsyncState<T>(prev: AsyncState<T>, error: string): AsyncState<T> {
  return {
    status: 'error',
    data: prev.data,
    error,
    lastUpdatedAt: prev.lastUpdatedAt,
  };
}

export function offlineAsyncState<T>(prev: AsyncState<T>): AsyncState<T> {
  return {
    status: 'offline',
    data: prev.data,
    error: '当前无网络连接',
    lastUpdatedAt: prev.lastUpdatedAt,
  };
}

export function forbiddenAsyncState<T>(): AsyncState<T> {
  return {
    status: 'forbidden',
    data: null,
    error: '无此操作权限',
    lastUpdatedAt: null,
  };
}

export function isLoading(state: AsyncState<unknown>): boolean {
  return state.status === 'loading';
}

export function isSettled(state: AsyncState<unknown>): boolean {
  return state.status === 'ready' || state.status === 'empty';
}