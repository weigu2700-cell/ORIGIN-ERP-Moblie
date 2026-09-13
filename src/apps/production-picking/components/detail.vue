<script setup lang="ts">
import { ref } from 'vue';
import { onLoad, onPullDownRefresh } from '@dcloudio/uni-app';
import {
  getDetailProductionPicking,
  confirmProductionPicking,
} from '@/api/production/production';
import { useSessionGuard, bindPageGuard } from '@/core/auth';
import { PRODUCTION_PICKING_STATUS } from '@/constants/domain-enums';
import OfflineBanner from '@/shared/components/OfflineBanner.vue';
import type { AsyncStatus } from '@/shared/types/async-state';
import type { ProductionPicking } from '@/types/production/production';

bindPageGuard(useSessionGuard());

const status = ref<AsyncStatus>('idle');
const errorMessage = ref('');
const pickingId = ref('');
const detail = ref<ProductionPicking | null>(null);
const confirming = ref(false);

const statusMap: Record<number, { label: string; class: string }> = {
  [PRODUCTION_PICKING_STATUS.DRAFT]: { label: '草稿', class: 's-draft' },
  [PRODUCTION_PICKING_STATUS.APPROVED]: { label: '已审批', class: 's-approved' },
  [PRODUCTION_PICKING_STATUS.PICKED]: { label: '已领料', class: 's-picked' },
  [PRODUCTION_PICKING_STATUS.CANCELLED]: { label: '已取消', class: 's-cancelled' },
};

const canConfirm = () =>
  detail.value?.status === PRODUCTION_PICKING_STATUS.APPROVED;

function formatDate(val?: string | null) {
  if (!val) return '--';
  return val;
}

async function loadDetail() {
  if (!pickingId.value) return;

  status.value = 'loading';
  try {
    detail.value = await getDetailProductionPicking(pickingId.value);
    status.value = 'ready';
  } catch (error) {
    detail.value = null;
    status.value = 'error';
    errorMessage.value = error instanceof Error ? error.message : '加载详情失败';
  }
}

async function handleConfirm() {
  confirming.value = true;
  try {
    await confirmProductionPicking(pickingId.value);
    uni.showToast({ title: '领料确认成功', icon: 'success' });
    await loadDetail();
  } catch (error) {
    uni.showToast({
      title: error instanceof Error ? error.message : '确认失败',
      icon: 'none',
    });
  } finally {
    confirming.value = false;
  }
}

onLoad((query) => {
  pickingId.value = String(query?.id || '');
  uni.setNavigationBarTitle({ title: '领料单详情' });
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
      <text class="state-text">未找到该领料单</text>
    </view>

    <template v-else-if="detail">
      <view class="hero-card">
        <view class="hero-head">
          <text class="hero-no">{{ detail.pickingNo }}</text>
          <text
            v-if="statusMap[detail.status]"
            class="hero-status"
            :class="statusMap[detail.status].class"
          >
            {{ statusMap[detail.status].label }}
          </text>
        </view>
        <text class="hero-material">{{ detail.materialName }}</text>
        <text class="hero-code">{{ detail.materialCode }}</text>
      </view>

      <view class="info-card">
        <view class="info-row">
          <text class="info-label">生产订单号</text>
          <text class="info-value">{{ detail.productionOrderNo || '--' }}</text>
        </view>
        <view class="info-row">
          <text class="info-label">仓库</text>
          <text class="info-value">{{ detail.warehouseName || '未指定' }}</text>
        </view>
        <view class="info-row">
          <text class="info-label">领料时间</text>
          <text class="info-value">{{ formatDate(detail.pickingTime) }}</text>
        </view>
        <view class="info-row">
          <text class="info-label">创建时间</text>
          <text class="info-value">{{ formatDate(detail.createTime) }}</text>
        </view>
        <view class="info-row">
          <text class="info-label">更新时间</text>
          <text class="info-value">{{ formatDate(detail.updateTime) }}</text>
        </view>
      </view>

      <view class="qty-card">
        <text class="section-title">领料数量</text>
        <view class="qty-grid">
          <view class="qty-cell">
            <text class="qty-cell-label">计划数量</text>
            <text class="qty-cell-value">{{ detail.plannedQuantity }}</text>
          </view>
          <view class="qty-cell">
            <text class="qty-cell-label">实际领料</text>
            <text class="qty-cell-value primary">{{ detail.actualQuantity }}</text>
          </view>
        </view>
      </view>

      <view v-if="canConfirm()" class="action-bar">
        <view
          class="action-btn"
          :class="{ disabled: confirming }"
          hover-class="btn-pressed"
          @click="handleConfirm"
        >
          {{ confirming ? '确认中...' : '确认领料' }}
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

.s-approved {
  color: #f4bd5c;
  background: rgba(244, 189, 92, 0.12);
}

.s-picked {
  color: #70c89b;
  background: rgba(112, 200, 155, 0.12);
}

.s-cancelled {
  color: #cfdae0;
  background: rgba(207, 218, 224, 0.18);
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

.qty-card {
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
}

.qty-grid {
  margin-top: 14px;
  display: flex;
  align-items: flex-start;
}

.qty-cell {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.qty-cell-label {
  color: #6f7f89;
  font-size: 12px;
}

.qty-cell-value {
  color: #162631;
  font-size: 20px;
  font-weight: 650;
}

.qty-cell-value.primary {
  color: #245b78;
}

.action-bar {
  margin-top: 20px;
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
  background: #245b78;
  box-sizing: border-box;
}

.action-btn.disabled {
  opacity: 0.6;
}

.btn-pressed {
  opacity: 0.72;
}
</style>