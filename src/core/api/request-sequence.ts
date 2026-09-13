/**
 * 请求序列号管理 —— 文档 4.2 节要求。
 * 页面切换、重复搜索时取消或忽略旧请求，使用递增请求序号避免慢响应覆盖新结果。
 */
import { ref } from 'vue';

export function useRequestSequence() {
  const currentSequence = ref(0);
  const pendingRequests = new Set<number>();

  function nextSequence() {
    cancelAllPending();
    currentSequence.value += 1;
    pendingRequests.add(currentSequence.value);
    return currentSequence.value;
  }

  function isLatest(sequence: number) {
    return sequence === currentSequence.value;
  }

  function markComplete(sequence: number) {
    pendingRequests.delete(sequence);
  }

  function cancelAllPending() {
    pendingRequests.clear();
  }

  function createAbortController(sequence: number) {
    const controller = new AbortController();
    const originalSignal = controller.signal;

    const check = () => {
      if (!isLatest(sequence) || originalSignal.aborted) {
        controller.abort();
      }
    };

    return { controller, check };
  }

  return {
    nextSequence,
    isLatest,
    markComplete,
    cancelAllPending,
    createAbortController,
  };
}