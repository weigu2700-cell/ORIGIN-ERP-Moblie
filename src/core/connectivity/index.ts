/**
 * 网络连接检测 —— 文档 4.2 节要求。
 * 读取请求可重试；写请求不自动重试。
 */
import { ref, onUnmounted } from 'vue';

export function useConnectivity() {
  const online = ref(true);
  let unsubscribe: (() => void) | null = null;

  async function updateStatus() {
    online.value = (uni.getNetworkType && (await uni.getNetworkType({})).networkType !== 'none')
      || navigator.onLine !== false;
  }

  function startListening() {
    updateStatus();
    if (typeof uni !== 'undefined' && uni.onNetworkStatusChange) {
      uni.onNetworkStatusChange((res) => {
        online.value = res.isConnected;
      });
    } else if (typeof window !== 'undefined') {
      const onOnline = () => { online.value = true; };
      const onOffline = () => { online.value = false; };
      window.addEventListener('online', onOnline);
      window.addEventListener('offline', onOffline);
      unsubscribe = () => {
        window.removeEventListener('online', onOnline);
        window.removeEventListener('offline', onOffline);
      };
    }
  }

  function stopListening() {
    if (unsubscribe) {
      unsubscribe();
      unsubscribe = null;
    }
  }

  function checkConnection() {
    updateStatus();
    return online.value;
  }

  onUnmounted(stopListening);

  return {
    online,
    startListening,
    stopListening,
    checkConnection,
  };
}