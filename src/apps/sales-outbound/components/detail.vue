<script setup lang="ts">
import { ref } from 'vue';
import { onLoad, onPullDownRefresh } from '@dcloudio/uni-app';
import {
  getDetailSalesDelivery,
  completeSalesDelivery,
} from '@/api/sales/sales';
import { useSessionGuard, bindPageGuard } from '@/core/auth';
import {
  SALES_DELIVERY_STATUS,
  SALES_DELIVERY_STATUS_LABEL,
} from '@/constants/domain-enums';
import OfflineBanner from '@/shared/components/OfflineBanner.vue';
import type { AsyncStatus } from '@/shared/types/async-state';
import type { SalesDelivery } from '@/types/sales/sales';

bindPageGuard(useSessionGuard());

const status = ref<AsyncStatus>('idle');
const errorMessage = ref('');
const deliveryId = ref('');
const detail = ref<SalesDelivery | null>(null);
const completing = ref(false);

const statusTagClass = (s: number) => {
  if (s === SALES_DELIVERY_STATUS.CONFIRMED) return 's-confirmed';
  if (s === SALES_DELIVERY_STATUS.COMPLETED) return 's-completed';
  return 's-draft';
};

const canComplete = () =>
  detail.value?.status === SALES_DELIVERY_STATUS.CONFIRMED;

async function loadDetail() {
  if (!deliveryId.value) return;

  status.value = 'loading';
  try {
    detail.value = await getDetailSalesDelivery(deliveryId.value);
    status.value = 'ready';
  } catch (error) {
    detail.value = null;
    status.value = 'error';
    errorMessage.value = error instanceof Error ? error.message : '加载详情失败';
  }
}

async function handleComplete() {
  completing.value = true;
  try {
    await completeSalesDelivery(deliveryId.value);
    uni.showToast({ title: '出库完成', icon: 'success' });
    await loadDetail();
  } catch (error) {
    uni.showToast({
      title: error instanceof Error ? error.message : '出库失败',
      icon: 'none',
    });
  } finally {
    completing.value = false;
  }
}

onLoad((query) => {
  deliveryId.value = String(query?.id || '');
  uni.setNavigationBarTitle({ title: '出库单详情' });
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
      <text class="state-text">未找到该出库单</text>
    </view>

    <template v-else-if="detail">
      <view class="hero-card">
        <view class="hero-head">
          <text class="hero-no">{{ detail.deliveryNo }}</text>
          <text
            class="hero-status"
            :class="statusTagClass(detail.status)"
          >
            {{ SALES_DELIVERY_STATUS_LABEL[detail.status] || '未知' }}
          </text>
        </view>
        <text class="hero-customer">{{ detail.customerName || '--' }}</text>
        <text class="hero-meta">{{ detail.salesOrderNo || '暂无订单号' }}</text>
      </view>

      <view class="info-card">
        <view class="info-row">
          <text class="info-label">交货日期</text>
          <text class="info-value">{{ detail.deliveryDate || '--' }}</text>
        </view>
        <view class="info-row">
          <text class="info-label">备注</text>
          <text class="info-value">{{ detail.remark || '--' }}</text>
        </view>
      </view>

      <view class="items-card">
        <text class="section-title">出库物料明细</text>
        <view
          v-for="item in detail.items"
          :key="item.id"
          class="item-row"
        >
          <view class="item-info">
            <text class="item-name">{{ item.materialName }}</text>
            <text class="item-code">{{ item.materialCode }}</text>
            <text class="item-warehouse">{{ item.warehouseName }}</text>
          </view>
          <view class="item-qty">
            <text class="item-qty-label">出库</text>
            <text class="item-qty-value">{{ item.quantity }}</text>
          </view>
        </view>
        <view v-if="!detail.items?.length" class="no-items">
          暂无物料明细
        </view>
      </view>

      <view v-if="canComplete()" class="action-bar">
        <view
          class="action-btn"
          :class="{ disabled: completing }"
          hover-class="btn-pressed"
          @click="handleComplete"
        >
          {{ completing ? '确认中...' : '确认出库' }}
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

.s-confirmed {
  color: #f4bd5c;
  background: rgba(244, 189, 92, 0.12);
}

.s-completed {
  color: #70c89b;
  background: rgba(112, 200, 155, 0.12);
}

.hero-customer {
  display: block;
  margin-top: 8px;
  font-size: 18px;
  font-weight: 650;
  line-height: 1.35;
}

.hero-meta {
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

.items-card {
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
  margin-bottom: 12px;
  display: block;
}

.item-row {
  padding: 12px 0;
  display: flex;
  align-items: center;
  justify-content: space-between;
  border-bottom: 1px solid #eef2f4;
}

.item-row:last-child {
  border-bottom: 0;
}

.item-info {
  flex: 1;
  min-width: 0;
}

.item-name {
  display: block;
  color: #162631;
  font-size: 14px;
  font-weight: 550;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.item-code {
  display: block;
  margin-top: 2px;
  color: #98a4ac;
  font-size: 11px;
}

.item-warehouse {
  display: block;
  margin-top: 2px;
  color: #6f7f89;
  font-size: 11px;
}

.item-qty {
  flex-shrink: 0;
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 2px;
}

.item-qty-label {
  color: #6f7f89;
  font-size: 11px;
}

.item-qty-value {
  color: #162631;
  font-size: 16px;
  font-weight: 650;
}

.no-items {
  text-align: center;
  color: #98a4ac;
  font-size: 13px;
  padding: 12px 0;
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