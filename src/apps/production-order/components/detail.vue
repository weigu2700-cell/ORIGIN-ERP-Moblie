<script setup lang="ts">
import { ref, computed } from 'vue';
import { onLoad, onPullDownRefresh } from '@dcloudio/uni-app';
import {
  getDetailProductionOrder,
  beginProductionOrder,
  completeProductionOrder,
} from '@/api/production/production';
import { useSessionGuard, bindPageGuard } from '@/core/auth';
import {
  PRODUCTION_ORDER_STATUS,
  PRODUCTION_ORDER_STATUS_LABEL,
} from '@/constants/domain-enums';
import OfflineBanner from '@/shared/components/OfflineBanner.vue';
import type { AsyncStatus } from '@/shared/types/async-state';
import type { ProductionOrder } from '@/types/production/production';

bindPageGuard(useSessionGuard());

const status = ref<AsyncStatus>('idle');
const errorMessage = ref('');
const orderId = ref('');
const detail = ref<ProductionOrder | null>(null);
const acting = ref(false);

const progressPercent = computed(() => {
  if (!detail.value || detail.value.plannedQuantity === 0) return 0;
  return Math.min(
    Math.round((detail.value.completedQuantity / detail.value.plannedQuantity) * 100),
    100,
  );
});

const statusTagClass = (s: number) => {
  if (s === PRODUCTION_ORDER_STATUS.RELEASED) return 's-released';
  if (s === PRODUCTION_ORDER_STATUS.IN_PROGRESS) return 's-progress';
  if (s === PRODUCTION_ORDER_STATUS.COMPLETED) return 's-completed';
  return 's-draft';
};

const canBegin = () => detail.value?.status === PRODUCTION_ORDER_STATUS.RELEASED;
const canComplete = () => detail.value?.status === PRODUCTION_ORDER_STATUS.IN_PROGRESS;

function formatDate(val?: string | null) {
  if (!val) return '--';
  return val;
}

async function loadDetail() {
  if (!orderId.value) return;
  status.value = 'loading';
  try {
    detail.value = await getDetailProductionOrder(orderId.value);
    status.value = 'ready';
  } catch (error) {
    detail.value = null;
    status.value = 'error';
    errorMessage.value = error instanceof Error ? error.message : '加载详情失败';
  }
}

async function handleBegin() {
  if (!detail.value) return;
  try {
    acting.value = true;
    await beginProductionOrder(orderId.value);
    uni.showToast({ title: '已开始生产', icon: 'success' });
    await loadDetail();
  } catch (error) {
    uni.showToast({
      title: error instanceof Error ? error.message : '操作失败',
      icon: 'none',
    });
  } finally {
    acting.value = false;
  }
}

async function handleComplete() {
  if (!detail.value) return;
  try {
    acting.value = true;
    await completeProductionOrder(orderId.value);
    uni.showToast({ title: '生产已完成', icon: 'success' });
    await loadDetail();
  } catch (error) {
    uni.showToast({
      title: error instanceof Error ? error.message : '操作失败',
      icon: 'none',
    });
  } finally {
    acting.value = false;
  }
}

onLoad((query) => {
  orderId.value = String(query?.id || '');
  uni.setNavigationBarTitle({ title: '生产订单详情' });
  loadDetail();
});

onPullDownRefresh(async () => {
  await loadDetail();
  uni.stopPullDownRefresh();
});
</script>

<template>
  <view class="page">
    <OfflineBanner />

    <view v-if="status === 'loading' && !detail" class="state">
      <text class="state-text">正在加载详情...</text>
    </view>

    <view v-else-if="status === 'error'" class="state">
      <wd-icon name="warn" size="28px" color="#c94444" />
      <text class="state-text error-text">{{ errorMessage || '加载失败' }}</text>
      <view class="retry-btn" hover-class="btn-pressed" @click="loadDetail">点击重试</view>
    </view>

    <view v-else-if="status === 'ready' && !detail" class="state">
      <wd-icon name="search" size="28px" color="#98a4ac" />
      <text class="state-text">未找到该生产订单</text>
    </view>

    <template v-else-if="detail">
      <view class="hero-card">
        <view class="hero-head">
          <text class="hero-no">{{ detail.productionOrderNo }}</text>
          <text class="hero-status" :class="statusTagClass(detail.status)">
            {{ PRODUCTION_ORDER_STATUS_LABEL[detail.status] || '未知' }}
          </text>
        </view>
        <text class="hero-material">{{ detail.materialName }}</text>
        <text class="hero-code">{{ detail.materialCode }}</text>
      </view>

      <view class="progress-card">
        <text class="section-title">生产进度</text>
        <view class="progress-bar">
          <view class="progress-track">
            <view
              class="progress-fill"
              :class="{
                'fill-in-progress': canComplete(),
                'fill-done': detail.status === PRODUCTION_ORDER_STATUS.COMPLETED,
              }"
              :style="{ width: `${progressPercent}%` }"
            />
          </view>
        </view>
        <view class="progress-label">
          <text class="progress-percent">{{ progressPercent }}%</text>
          <text class="progress-ratio"
            >{{ detail.completedQuantity }} / {{ detail.plannedQuantity }}</text
          >
        </view>
      </view>

      <view class="info-card">
        <view class="info-row">
          <text class="info-label">需求单号</text>
          <text class="info-value">{{ detail.productionDemandNo || '--' }}</text>
        </view>
        <view class="info-row">
          <text class="info-label">计划开始</text>
          <text class="info-value">{{ formatDate(detail.plannedStartTime) }}</text>
        </view>
        <view class="info-row">
          <text class="info-label">计划结束</text>
          <text class="info-value">{{ formatDate(detail.plannedEndTime) }}</text>
        </view>
        <view class="info-row">
          <text class="info-label">实际开始</text>
          <text class="info-value" :class="{ muted: !detail.actualStartTime }">
            {{ formatDate(detail.actualStartTime) }}
          </text>
        </view>
        <view class="info-row">
          <text class="info-label">实际结束</text>
          <text class="info-value" :class="{ muted: !detail.actualEndTime }">
            {{ formatDate(detail.actualEndTime) }}
          </text>
        </view>
        <view class="info-row">
          <text class="info-label">备注</text>
          <text class="info-value">{{ detail.remark || '--' }}</text>
        </view>
      </view>

      <view v-if="canBegin() || canComplete()" class="action-bar">
        <view
          v-if="canBegin()"
          class="action-btn begin-btn"
          :class="{ disabled: acting }"
          hover-class="btn-pressed"
          @click="handleBegin"
        >
          {{ acting ? '处理中...' : '开始生产' }}
        </view>
        <view
          v-if="canComplete()"
          class="action-btn complete-btn"
          :class="{ disabled: acting }"
          hover-class="btn-pressed"
          @click="handleComplete"
        >
          {{ acting ? '处理中...' : '完成生产' }}
        </view>
      </view>
    </template>
  </view>
</template>

<style scoped>
.page {
  min-height: 100vh;
  padding: 16px;
  color: #162631;
  background: #f4f7f9;
  box-sizing: border-box;
}

.state {
  min-height: 260px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 10px;
}

.state-text {
  color: #6f7f89;
  font-size: 14px;
  text-align: center;
  padding: 0 16px;
}

.error-text {
  color: #c94444;
}

.retry-btn {
  margin-top: 6px;
  padding: 8px 24px;
  color: #fff;
  font-size: 14px;
  background: #245b78;
  border-radius: 8px;
}

.hero-card {
  padding: 20px;
  border-radius: 14px;
  color: #fff;
  background: #203f54;
}

.hero-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}

.hero-no {
  font-size: 17px;
  font-weight: 650;
}

.hero-status {
  padding: 3px 10px;
  border-radius: 6px;
  font-size: 11px;
  font-weight: 550;
  flex-shrink: 0;
}

.s-draft {
  color: #cfdae0;
  background: rgba(207, 218, 224, 0.18);
}

.s-released {
  color: #7dbeff;
  background: rgba(125, 190, 255, 0.12);
}

.s-progress {
  color: #f4bd5c;
  background: rgba(244, 189, 92, 0.12);
}

.s-completed {
  color: #70c89b;
  background: rgba(112, 200, 155, 0.12);
}

.hero-material {
  display: block;
  margin-top: 8px;
  font-size: 18px;
  font-weight: 650;
  line-height: 1.35;
}

.hero-code {
  display: block;
  margin-top: 4px;
  color: #cfdae0;
  font-size: 13px;
}

.progress-card {
  margin-top: 14px;
  padding: 16px 14px;
  border: 1px solid #e1e8ec;
  border-radius: 12px;
  background: #fff;
  box-sizing: border-box;
}

.section-title {
  color: #6f7f89;
  font-size: 12px;
  font-weight: 550;
  display: block;
  margin-bottom: 10px;
}

.progress-track {
  height: 8px;
  border-radius: 4px;
  background: #eef2f4;
  overflow: hidden;
}

.progress-fill {
  height: 100%;
  border-radius: 4px;
  background: #3498db;
  transition: width 0.4s ease;
}

.fill-in-progress {
  background: #e67e22;
}

.fill-done {
  background: #27ae60;
}

.progress-label {
  margin-top: 8px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.progress-percent {
  color: #245b78;
  font-size: 18px;
  font-weight: 650;
}

.progress-ratio {
  color: #6f7f89;
  font-size: 13px;
}

.info-card {
  margin-top: 14px;
  padding: 0 14px;
  border: 1px solid #e1e8ec;
  border-radius: 12px;
  background: #fff;
  box-sizing: border-box;
}

.info-row {
  min-height: 50px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  border-bottom: 1px solid #eef2f4;
}

.info-row:last-child {
  border-bottom: 0;
}

.info-label {
  color: #6f7f89;
  font-size: 13px;
}

.info-value {
  color: #162631;
  font-size: 14px;
  font-weight: 550;
}

.info-value.muted {
  color: #98a4ac;
}

.action-bar {
  margin-top: 20px;
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding-bottom: calc(env(safe-area-inset-bottom) + 16px);
}

.action-btn {
  width: 100%;
  height: 48px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 12px;
  color: #fff;
  font-size: 16px;
  font-weight: 600;
  box-sizing: border-box;
}

.begin-btn {
  background: #3498db;
}

.complete-btn {
  background: #27ae60;
}

.action-btn.disabled {
  opacity: 0.6;
}

.btn-pressed {
  opacity: 0.72;
}
</style>