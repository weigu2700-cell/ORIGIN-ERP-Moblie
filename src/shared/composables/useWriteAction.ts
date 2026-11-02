import { ref } from 'vue';
import { getOnlineStatus } from '@/core/connectivity';

export function useWriteAction(checkOnline = getOnlineStatus) {
  const busy = ref(false);
  const errorMessage = ref('');

  async function run(options: {
    allowed: () => boolean;
    prepare?: () => Promise<boolean | void>;
    execute: () => Promise<void>;
  }) {
    if (busy.value) return false;
    busy.value = true;
    errorMessage.value = '';
    try {
      if (!options.allowed()) throw new Error('没有此操作权限，请联系管理员授权');
      if (!(await checkOnline())) throw new Error('当前离线，请恢复网络后再操作');
      if ((await options.prepare?.()) === false) return false;
      if (!options.allowed()) throw new Error('操作权限已变更，请刷新后重试');
      await options.execute();
      return true;
    } catch (error) {
      errorMessage.value = error instanceof Error ? error.message : '操作失败，请刷新核对状态';
      throw error;
    } finally {
      busy.value = false;
    }
  }
  return { busy, errorMessage, run };
}

export function confirmOperation(title: string, content: string): Promise<boolean> {
  return new Promise((resolve) =>
    uni.showModal({
      title,
      content,
      confirmText: '确认',
      success: (result) => resolve(result.confirm),
      fail: () => resolve(false),
    }),
  );
}
