import { ref, onUnmounted } from 'vue';

const browserOnline = () => typeof navigator === 'undefined' || navigator.onLine !== false;

/** 使用原生网络结果；不能用 || 把明确的离线结果覆盖成在线。 */
export function getOnlineStatus(): Promise<boolean> {
  if (typeof uni === 'undefined' || !uni.getNetworkType) return Promise.resolve(browserOnline());
  return new Promise((resolve) => {
    uni.getNetworkType({
      success: (result) => resolve(result.networkType !== 'none'),
      fail: () => resolve(browserOnline()),
    });
  });
}

export function useConnectivity() {
  const online = ref(true);
  let unsubscribe: (() => void) | null = null;
  let active = false;
  let updateSequence = 0;

  async function checkConnection() {
    const sequence = ++updateSequence;
    const value = await getOnlineStatus();
    if (sequence === updateSequence) online.value = value;
    return online.value;
  }

  function startListening() {
    if (active) return;
    active = true;
    void checkConnection();
    if (typeof uni !== 'undefined' && uni.onNetworkStatusChange) {
      const listener = (result: UniApp.OnNetworkStatusChangeSuccess) => {
        if (active) {
          updateSequence++;
          online.value = result.isConnected;
        }
      };
      uni.onNetworkStatusChange(listener);
      unsubscribe = () => uni.offNetworkStatusChange?.(listener);
    } else if (typeof window !== 'undefined') {
      const listener = () => {
        updateSequence++;
        online.value = browserOnline();
      };
      window.addEventListener('online', listener);
      window.addEventListener('offline', listener);
      unsubscribe = () => {
        window.removeEventListener('online', listener);
        window.removeEventListener('offline', listener);
      };
    }
  }

  function stopListening() {
    active = false;
    updateSequence++;
    unsubscribe?.();
    unsubscribe = null;
  }

  onUnmounted(stopListening);
  return { online, startListening, stopListening, checkConnection };
}
