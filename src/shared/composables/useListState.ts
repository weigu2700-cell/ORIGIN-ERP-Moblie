/**
 * 通用列表状态管理 —— M1 只读闭环模板产物。
 * 封装 loading/empty/error/offline 状态与分页逻辑，后续业务列表直接复用。
 */
import { computed, ref, shallowRef } from 'vue';
import type { AsyncStatus } from '@/shared/types/async-state';

export interface ListStateOptions<T> {
  pageSize?: number;
  fetchPage: (pageNum: number, pageSize: number) => Promise<{ records: T[]; total: number }>;
  onError?: (error: unknown) => void;
}

export function useListState<T>(options: ListStateOptions<T>) {
  const { pageSize = 20, fetchPage, onError } = options;

  const status = ref<AsyncStatus>('idle');
  const errorMessage = ref('');
  const list = shallowRef<T[]>([]);
  const total = ref(0);
  const page = ref(1);
  const loading = ref(false);
  let requestSequence = 0;

  const finished = computed(() => list.value.length >= total.value);
  const isEmpty = computed(() => status.value === 'ready' && !loading.value && !list.value.length);
  const isInitialLoading = computed(() => status.value === 'loading' && !list.value.length);

  function reset() {
    requestSequence++;
    loading.value = false;
    list.value = [];
    total.value = 0;
    page.value = 1;
    errorMessage.value = '';
    status.value = 'idle';
  }

  async function loadPage(target: number, replacePending = false) {
    if (loading.value && !replacePending) return;
    const sequence = ++requestSequence;

    loading.value = true;
    errorMessage.value = '';
    status.value = 'loading';

    try {
      const result = await fetchPage(target, pageSize);
      // A new scan/filter supersedes an older request, even if it finishes later.
      if (sequence !== requestSequence) return;
      const records = result?.records || [];
      list.value = target === 1 ? records : list.value.concat(records);
      total.value = Number(result?.total) || 0;
      page.value = target;
      status.value = 'ready';
    } catch (error) {
      if (sequence !== requestSequence) return;
      if (target === 1) {
        list.value = [];
        total.value = 0;
      }
      status.value = target === 1 && !list.value.length ? 'error' : 'ready';
      errorMessage.value = error instanceof Error ? error.message : '数据加载失败';
      onError?.(error);
    } finally {
      if (sequence === requestSequence) loading.value = false;
    }
  }

  async function refresh() {
    await loadPage(1, true);
  }

  async function loadMore() {
    if (loading.value || finished.value) return;
    await loadPage(page.value + 1);
  }

  return {
    status,
    errorMessage,
    list,
    total,
    page,
    loading,
    finished,
    isEmpty,
    isInitialLoading,
    reset,
    loadPage,
    refresh,
    loadMore,
  };
}
