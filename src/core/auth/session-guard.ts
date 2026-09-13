/**
 * 全局会话守卫 —— 文档 P0 #7 产物。
 * 提供 useSessionGuard 组合函数，各业务页面调用即可获得统一的登录/权限检查。
 */
import { ref } from 'vue';
import { onShow } from '@dcloudio/uni-app';
import { useUserStore } from '@/stores/user';
import type { AsyncStatus } from '@/shared/types/async-state';

export interface SessionGuardResult {
  guardStatus: { value: AsyncStatus };
  runGuard: () => Promise<boolean>;
}

export function useSessionGuard(): SessionGuardResult {
  const userStore = useUserStore();
  const guardStatus = ref<AsyncStatus>('idle');

  async function runGuard(): Promise<boolean> {
    userStore.restoreSession();

    if (!userStore.hasToken) {
      guardStatus.value = 'idle';
      uni.reLaunch({ url: '/pages/login/login' });
      return false;
    }

    if (userStore.isLoggedIn) {
      guardStatus.value = 'ready';
      return true;
    }

    guardStatus.value = 'loading';
    try {
      const authenticated = await userStore.validateSession(true);
      if (!authenticated) {
        guardStatus.value = 'idle';
        uni.reLaunch({ url: '/pages/login/login' });
        return false;
      }
      guardStatus.value = 'ready';
      return true;
    } catch {
      userStore.restoreSession();
      if (!userStore.hasToken) {
        guardStatus.value = 'idle';
        uni.reLaunch({ url: '/pages/login/login' });
      } else {
        guardStatus.value = 'error';
      }
      return false;
    }
  }

  return { guardStatus, runGuard };
}

/**
 * 为页面绑定 onShow 守卫。
 * 在页面 setup 中调用即可自动在每次 onShow 时检查登录状态。
 */
export function bindPageGuard(guard: SessionGuardResult) {
  onShow(async () => {
    await guard.runGuard();
  });
}