<script setup lang="ts">
import { computed, nextTick, ref, onMounted, onBeforeUnmount } from 'vue';
import { onHide, onLoad, onUnload } from '@dcloudio/uni-app';
import { useSessionGuard, bindPageGuard } from '@/core/auth';
import { useUserStore } from '@/stores/user';
import { useWorkbenchStore } from '@/stores/workbench';
import {
  decodeScanQuery,
  getScanErrorMessage,
  normalizeScanValue,
  SCAN_TARGETS,
} from '@/core/scan';
import OfflineBanner from '@/shared/components/OfflineBanner.vue';
// #ifdef H5
import { createBrowserScanner } from '@/core/scan/browser';
const browserScanner = createBrowserScanner();
// #endif

const guard = useSessionGuard();
bindPageGuard(guard);
const userStore = useUserStore();
const workbenchStore = useWorkbenchStore();
const value = ref('');
const errorMessage = ref('');
const scanning = ref(false);
const submitting = ref(false);
const returnMode = ref(false);
const title = ref('扫一扫');
const selectedCode = ref('stock');
const targetSheet = ref(false);
let active = true;
let scanAttempt = 0;
const targets = computed(() =>
  userStore.permissionsStatus === 'ready'
    ? SCAN_TARGETS.filter((item) => userStore.hasAnyPermission([...item.permissions]))
    : [],
);
const selected = computed(
  () => targets.value.find((item) => item.code === selectedCode.value) || targets.value[0],
);
const targetActions = computed(() => targets.value.map((item) => ({ name: item.title })));
const canSubmit = computed(
  () => Boolean(value.value.trim()) && !scanning.value && !submitting.value,
);

function stopScan() {
  scanAttempt++;
  scanning.value = false;
  // #ifdef H5
  browserScanner.stop();
  // #endif
}

function acceptResult(raw: string) {
  if (!active) return;
  stopScan();
  try {
    value.value = normalizeScanValue(raw);
    errorMessage.value = '';
  } catch (error) {
    errorMessage.value = (error as Error).message;
  }
}

async function startScan() {
  if (scanning.value) return;
  active = true;
  if (!(await guard.runGuard()) || scanning.value || !active) return;
  errorMessage.value = '';
  scanning.value = true;
  const attempt = ++scanAttempt;
  // #ifdef H5
  try {
    await nextTick();
    const preview = document.getElementById('erp-scan-preview');
    const element = (
      preview?.tagName === 'VIDEO' ? preview : preview?.querySelector('video')
    ) as HTMLVideoElement | null;
    if (!element) throw new Error('相机预览未就绪，请重试');
    await browserScanner.start(element, acceptResult, (error) => {
      if (!active || attempt !== scanAttempt) return;
      stopScan();
      errorMessage.value = getScanErrorMessage(error);
    });
  } catch (error) {
    if (!active || attempt !== scanAttempt) return;
    stopScan();
    errorMessage.value =
      error instanceof Error && /HTTPS|预览/.test(error.message)
        ? error.message
        : getScanErrorMessage(error);
  }
  // #endif
  // #ifndef H5
  try {
    uni.scanCode({
      scanType: ['barCode', 'qrCode'],
      success: ({ result }) => {
        if (active && attempt === scanAttempt) acceptResult(result);
      },
      fail: (error) => {
        if (!active || attempt !== scanAttempt) return;
        stopScan();
        errorMessage.value = getScanErrorMessage(error);
      },
    });
  } catch (error) {
    stopScan();
    errorMessage.value = getScanErrorMessage(error);
  }
  // #endif
}

function selectTarget(event: { index: number }) {
  const target = targets.value[event.index];
  if (target) selectedCode.value = target.code;
}

async function submit() {
  if (!canSubmit.value) return;
  if (!(await guard.runGuard()) || submitting.value || !active) return;
  let code: string;
  try {
    code = normalizeScanValue(value.value);
  } catch (error) {
    errorMessage.value = (error as Error).message;
    return;
  }
  errorMessage.value = '';
  if (returnMode.value) {
    // Emit only after the user confirms; cancellation never changes the original filter.
    const page = getCurrentPages().slice(-1)[0] as unknown as {
      getOpenerEventChannel: () => { emit: (name: string, data: unknown) => void };
    };
    page.getOpenerEventChannel().emit('scanResult', { value: code });
    submitting.value = true;
    uni.navigateBack({
      fail: () => {
        submitting.value = false;
        errorMessage.value = '返回失败，请重试';
      },
    });
    return;
  }
  if (!selected.value?.route) {
    errorMessage.value = '暂无可查询的业务权限，请联系管理员开通';
    return;
  }
  submitting.value = true;
  uni.navigateTo({
    url: `${selected.value.route}?keyword=${encodeURIComponent(code)}`,
    complete: () => {
      submitting.value = false;
    },
    fail: () => {
      errorMessage.value = '无法打开查询页面，请重试';
    },
  });
}

// #ifdef H5
function handleVisibility() {
  if (document.hidden) stopScan();
}
onMounted(() => document.addEventListener('visibilitychange', handleVisibility));
onBeforeUnmount(() => document.removeEventListener('visibilitychange', handleVisibility));
// #endif

onLoad((query) => {
  returnMode.value = query?.mode === 'return';
  title.value = decodeScanQuery(query?.title) || '扫一扫';
  value.value = decodeScanQuery(query?.value);
  uni.setNavigationBarTitle({ title: title.value });
});
onHide(() => {
  // Native scanner overlays can trigger onHide; let their callbacks complete.
  // #ifdef H5
  stopScan();
  // #endif
});
onUnload(() => {
  active = false;
  stopScan();
});
</script>

<template>
  <view class="scan-page">
    <OfflineBanner />
    <view class="scan-content">
      <text class="page-title">{{ title }}</text>
      <text class="hint">对准物料条码或单据二维码，识别后核对编码再查询</text>
      <view v-if="!returnMode" class="context-card">
        <text class="label">查询业务</text>
        <button
          class="target-button"
          role="button"
          aria-label="选择查询业务"
          :disabled="!targets.length"
          @click="targetSheet = true"
        >
          {{ selected?.title || '暂无可查询业务' }} <wd-icon name="chevron-down" size="16px" />
        </button>
        <text class="hint">{{
          workbenchStore.currentWarehouse
            ? `当前仓库：${workbenchStore.currentWarehouse.name}`
            : '未选择仓库，将按业务默认范围查询'
        }}</text>
        <text v-if="!targets.length" class="hint">权限尚未加载或未开通，请返回工作台刷新权限</text>
      </view>
      <view class="camera-card">
        <!-- #ifdef H5 -->
        <video
          v-show="scanning"
          id="erp-scan-preview"
          class="preview"
          autoplay
          muted
          playsinline
          :controls="false"
          :show-center-play-btn="false"
          aria-label="扫码相机预览"
        />
        <!-- #endif -->
        <view v-if="!scanning && !value" class="camera-idle">
          <wd-icon name="scan" size="48px" />
          <text class="camera-title">支持条形码和二维码</text>
          <text class="hint">将编码放入镜头，保持清晰、避免反光</text>
        </view>
        <text v-if="scanning" class="hint">正在识别，请将编码完整放入镜头</text>
        <wd-button
          v-if="scanning"
          role="button"
          aria-label="停止扫码"
          block
          type="info"
          @click="stopScan"
          >停止扫码</wd-button
        >
        <wd-button
          v-else
          role="button"
          aria-label="打开相机扫码"
          block
          :type="value ? 'info' : 'primary'"
          size="large"
          @click="startScan"
        >
          {{ value ? '重新扫码' : '打开相机扫码' }}
        </wd-button>
      </view>
      <view class="input-card">
        <text class="label">{{ value ? '核对编码' : '也可手动输入 / PDA 扫码输入' }}</text>
        <input
          v-model="value"
          class="code-input"
          :maxlength="200"
          aria-label="物料编码或单据编号"
          placeholder="输入或粘贴编码"
          confirm-type="search"
          :disabled="scanning"
          @confirm="submit"
        />
        <text class="hint">请使用纯编码；网页链接和复杂二维码暂不支持</text>
      </view>
      <view v-if="errorMessage" class="error-box" role="alert">{{ errorMessage }}</view>
      <view class="submit-panel">
        <wd-button
          role="button"
          aria-label="使用当前编码查询"
          :aria-disabled="!canSubmit"
          block
          size="large"
          :disabled="!canSubmit"
          :loading="submitting"
          @click="submit"
        >
          {{ returnMode ? '使用编码查询' : `查询${selected?.title.replace(/查询$/, '') || ''}` }}
        </wd-button>
        <text class="hint footnote">扫码仅用于查询，不会自动入库、领料或出库</text>
      </view>
    </view>
    <wd-action-sheet
      v-model="targetSheet"
      title="选择查询业务"
      cancel-text="取消"
      :actions="targetActions"
      @select="selectTarget"
    />
  </view>
</template>

<style scoped lang="scss">
.scan-page {
  min-height: 100vh;
  background: $app-color-canvas;
  color: $app-color-text;
  padding: 16px 16px calc(env(safe-area-inset-bottom) + 132px);
  --wot-color-theme: #{$app-color-primary};
  box-sizing: border-box;
}
.scan-content {
  max-width: 480px;
  margin: 0 auto;
  display: flex;
  flex-direction: column;
  gap: 12px;
}
.page-title {
  font-size: 22px;
  font-weight: 650;
}
.hint {
  display: block;
  font-size: 14px;
  color: $app-color-text-secondary;
  line-height: 1.6;
  overflow-wrap: anywhere;
}
.label {
  display: block;
  font-size: 14px;
  font-weight: 600;
  margin-bottom: 8px;
}
.context-card,
.camera-card,
.input-card {
  background: $app-color-surface;
  border: 1px solid $app-color-border;
  border-radius: $app-radius-control;
  padding: 16px;
  min-width: 0;
}
.target-button {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  background: $app-color-surface;
  color: $app-color-primary;
  margin: 0 0 8px;
  padding: 0 12px;
  min-height: 44px;
  font-size: 16px;
  text-align: left;
}
.camera-idle {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  padding: 8px 0 16px;
  color: $app-color-primary;
  text-align: center;
}
.camera-title {
  font-weight: 600;
  font-size: 16px;
}
.preview {
  width: 100%;
  height: 220px;
  object-fit: cover;
  border-radius: 8px;
  background: $app-color-text;
  margin-bottom: 12px;
}
.code-input {
  min-height: 48px;
  font-size: 16px;
  border-bottom: 1px solid $app-color-border;
  margin-bottom: 8px;
}
.error-box {
  color: $app-color-danger;
  background: $app-color-surface;
  border: 1px solid $app-color-danger;
  padding: 12px;
  border-radius: 8px;
  font-size: 14px;
  line-height: 1.6;
  overflow-wrap: anywhere;
}
.submit-panel {
  position: fixed;
  bottom: 0;
  left: 50%;
  transform: translateX(-50%);
  width: calc(100% - 32px);
  max-width: 480px;
  padding: 12px 0 calc(env(safe-area-inset-bottom) + 12px);
  background: $app-color-canvas;
  z-index: 3;
}
.footnote {
  margin-top: 8px;
  text-align: center;
  font-size: 12px;
}
</style>
