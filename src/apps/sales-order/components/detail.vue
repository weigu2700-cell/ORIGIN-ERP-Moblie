<script setup lang="ts">
import { ref, computed } from 'vue';
import { onLoad, onPullDownRefresh } from '@dcloudio/uni-app';
import { getDetailSalesOrder } from '@/api/sales/sales';
import { useSessionGuard, bindPageGuard } from '@/core/auth';
import {
  SALES_ORDER_STATUS,
  SALES_ORDER_STATUS_LABEL,
} from '@/constants/domain-enums';
import OfflineBanner from '@/shared/components/OfflineBanner.vue';
import type { AsyncStatus } from '@/shared/types/async-state';
import type { SalesOrder } from '@/types/sales/sales';

bindPageGuard(useSessionGuard());

const status = ref<AsyncStatus>('idle');
const errorMessage = ref('');
const orderId = ref('');
const detail = ref<SalesOrder | null>(null);

const totalQuantity = computed(() =>
  (detail.value?.items || []).reduce((sum, item) => sum + (item.quantity || 0), 0),
);

const statusTagClass = (s: number) => {
  if (s === SALES_ORDER_STATUS.CONFIRMED) return 's-confirmed';
  if (s === SALES_ORDER_STATUS.COMPLETED) return 's-completed';
  return 's-draft';
};

async function loadDetail() {
  if (!orderId.value) return;
  status.value = 'loading';
  try {
    detail.value = await getDetailSalesOrder(orderId.value);
    status.value = 'ready';
  } catch (error) {
    detail.value = null;
    status.value = 'error';
    errorMessage.value = error instanceof Error ? error.message : '加载详情失败';
  }
}

onLoad((query) => {
  orderId.value = String(query?.id || '');
  uni.setNavigationBarTitle({ title: '销售订单详情' });
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
      <text class="state-text">未找到该销售订单</text>
    </view>

    <template v-else-if="detail">
      <view class="hero-card">
        <view class="hero-head">
          <text class="hero-no">{{ detail.orderNo }}</text>
          <text class="hero-status" :class="statusTagClass(detail.status)">
            {{ SALES_ORDER_STATUS_LABEL[detail.status] || '未知' }}
          </text>
        </view>
        <text class="hero-customer">{{ detail.customerName || '--' }}</text>
        <view class="hero-meta-row">
          <text class="hero-meta">{{ detail.orderDate || '--' }}</text>
          <text class="hero-meta">{{ detail.deliveryDate || '--' }}</text>
        </view>
      </view>

      <view class="summary-card">
        <view class="summary-row">
          <view class="summary-cell">
            <text class="summary-label">物料品种</text>
            <text class="summary-value">{{ detail.items?.length || 0 }}</text>
          </view>
          <view class="summary-cell">
            <text class="summary-label">总数量</text>
            <text class="summary-value primary">{{ totalQuantity }}</text>
          </view>
        </view>
      </view>

      <view class="items-card">
        <text class="section-title">物料明细</text>
        <view
          v-for="item in detail.items"
          :key="item.id"
          class="item-row"
        >
          <view class="item-info">
            <text class="item-name">{{ item.materialName }}</text>
            <text class="item-code">{{ item.materialCode }}</text>
          </view>
          <view class="item-qty">
            <text class="item-qty-label">数量</text>
            <text class="item-qty-value">{{ item.quantity }}</text>
          </view>
        </view>
        <view v-if="!detail.items?.length" class="no-items">
          暂无物料明细
        </view>
      </view>

      <view class="info-card">
        <view class="info-row">
          <text class="info-label">备注</text>
          <text class="info-value">{{ detail.remark || '--' }}</text>
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

.hero-meta-row {
  margin-top: 6px;
  display: flex;
  justify-content: space-between;
}

.hero-meta {
  color: #cfdae0;
  font-size: 12px;
}

.summary-card {
  margin-top: 14px;
  padding: 16px 14px;
  border: 1px solid #e1e8ec;
  border-radius: 12px;
  background: #fff;
  box-sizing: border-box;
}

.summary-row {
  display: flex;
}

.summary-cell {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.summary-label {
  color: #6f7f89;
  font-size: 12px;
}

.summary-value {
  color: #162631;
  font-size: 22px;
  font-weight: 650;
}

.summary-value.primary {
  color: #245b78;
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
</style>