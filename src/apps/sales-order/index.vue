<script setup lang="ts">
import { ref } from 'vue';
import { onLoad, onPullDownRefresh, onReachBottom } from '@dcloudio/uni-app';
import { getPageSalesOrder } from '@/api/sales/sales';
import { useSessionGuard, bindPageGuard } from '@/core/auth';
import { useListState } from '@/shared/composables/useListState';
import {
  SALES_ORDER_STATUS,
  SALES_ORDER_STATUS_LABEL,
} from '@/constants/domain-enums';
import OfflineBanner from '@/shared/components/OfflineBanner.vue';
import type { SalesOrder, SalesOrderQuery } from '@/types/sales/sales';

bindPageGuard(useSessionGuard());

const keyword = ref('');

const statusClass = (s: number) => {
  if (s === SALES_ORDER_STATUS.CONFIRMED) return 'tag-confirmed';
  if (s === SALES_ORDER_STATUS.COMPLETED) return 'tag-completed';
  return 'tag-draft';
};

function buildQuery(target: number): SalesOrderQuery {
  return {
    pageNum: target,
    pageSize: 20,
    orderNo: keyword.value.trim() || undefined,
    status: SALES_ORDER_STATUS.CONFIRMED,
  };
}

const listState = useListState<SalesOrder>({
  pageSize: 20,
  fetchPage: async (pageNum) => {
    const result = await getPageSalesOrder(buildQuery(pageNum));
    return { records: result?.records || [], total: Number(result?.total) || 0 };
  },
});

function search() {
  listState.refresh();
}

function clearKeyword() {
  keyword.value = '';
  listState.refresh();
}

function openDetail(item: SalesOrder) {
  uni.navigateTo({
    url: `/apps/sales-order/components/detail?id=${encodeURIComponent(item.id)}`,
  });
}

function handleRetry() {
  listState.refresh();
}

onLoad(() => {
  listState.loadPage(1);
});

onPullDownRefresh(async () => {
  await listState.refresh();
  uni.stopPullDownRefresh();
});

onReachBottom(() => {
  listState.loadMore();
});
</script>

<template>
  <view class="page">
    <OfflineBanner />

    <view class="toolbar">
      <view class="search-box">
        <wd-icon name="search" size="16px" color="#98a4ac" />
        <input
          v-model="keyword"
          class="search-input"
          placeholder="搜索销售订单号"
          placeholder-class="search-placeholder"
          confirm-type="search"
          @confirm="search"
        />
        <view
          v-if="keyword"
          class="clear-btn"
          role="button"
          aria-label="清除搜索"
          @click="clearKeyword"
        >
          <wd-icon name="close" size="14px" color="#98a4ac" />
        </view>
      </view>
    </view>

    <view class="list-meta">
      <text class="meta-total">共 {{ listState.total.value }} 条已确认订单</text>
    </view>

    <view v-if="listState.isInitialLoading.value" class="state">
      <text class="state-text">正在加载订单...</text>
    </view>

    <view v-else-if="listState.status.value === 'error'" class="state">
      <wd-icon name="warn" size="28px" color="#c94444" />
      <text class="state-text error-text">{{ listState.errorMessage.value || '加载失败' }}</text>
      <view class="retry-btn" hover-class="btn-pressed" @click="handleRetry">点击重试</view>
    </view>

    <view v-else-if="listState.isEmpty.value" class="state">
      <wd-icon name="check-outline" size="28px" color="#4caf50" />
      <text class="state-text">暂无已确认的销售订单</text>
    </view>

    <view v-else class="list">
      <view
        v-for="item in listState.list.value"
        :key="item.id"
        class="card"
        hover-class="card-pressed"
        role="button"
        @click="openDetail(item)"
      >
        <view class="card-head">
          <text class="card-no">{{ item.orderNo }}</text>
          <text class="status-tag" :class="statusClass(item.status)">
            {{ SALES_ORDER_STATUS_LABEL[item.status] || '未知' }}
          </text>
        </view>
        <view class="customer-row">
          <text class="customer-label">客户：</text>
          <text class="customer-value">{{ item.customerName || '--' }}</text>
        </view>
        <view class="bottom-row">
          <text class="qty-text">{{ item.items?.length || 0 }} 种物料</text>
          <text class="qty-text">{{ item.orderDate || '--' }}</text>
        </view>
      </view>

      <view class="list-footer">
        <text v-if="listState.loading.value">加载中...</text>
        <text v-else-if="listState.finished.value"
          >已加载全部 {{ listState.list.value.length }} 条</text
        >
        <text v-else>上拉加载更多</text>
      </view>
    </view>
  </view>
</template>

<style scoped>
.page {
  min-height: 100vh;
  padding: 12px 16px calc(env(safe-area-inset-bottom) + 24px);
  color: #162631;
  background: #f4f7f9;
  box-sizing: border-box;
}

.toolbar {
  display: flex;
  align-items: center;
  gap: 10px;
}

.search-box {
  flex: 1;
  min-width: 0;
  height: 44px;
  padding: 0 14px;
  display: flex;
  align-items: center;
  border: 1px solid #d6e0e6;
  border-radius: 10px;
  background: #fff;
  box-sizing: border-box;
}

.search-input {
  flex: 1;
  min-width: 0;
  margin-left: 8px;
  color: #162631;
  font-size: 15px;
}

.search-placeholder {
  color: #98a4ac;
  font-size: 15px;
}

.clear-btn {
  width: 44px;
  height: 44px;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-right: -8px;
}

.list-meta {
  margin: 14px 4px 10px;
}

.meta-total {
  color: #6f7f89;
  font-size: 12px;
}

.state {
  min-height: 240px;
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

.list {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.card {
  padding: 14px;
  border: 1px solid #e1e8ec;
  border-radius: 12px;
  background: #fff;
  box-sizing: border-box;
}

.card-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}

.card-no {
  color: #162631;
  font-size: 15px;
  font-weight: 600;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.status-tag {
  padding: 2px 8px;
  border-radius: 4px;
  font-size: 11px;
  font-weight: 550;
  flex-shrink: 0;
}

.tag-draft {
  color: #6f7f89;
  background: #eef2f4;
}

.tag-confirmed {
  color: #e67e22;
  background: #fef4e8;
}

.tag-completed {
  color: #27ae60;
  background: #eafaf1;
}

.customer-row {
  margin-top: 8px;
  display: flex;
  align-items: center;
  gap: 4px;
}

.customer-label {
  color: #6f7f89;
  font-size: 12px;
}

.customer-value {
  color: #162631;
  font-size: 12px;
}

.bottom-row {
  margin-top: 10px;
  padding-top: 10px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  border-top: 1px solid #eef2f4;
}

.qty-text {
  color: #6f7f89;
  font-size: 12px;
}

.card-pressed {
  opacity: 0.72;
}

.list-footer {
  padding: 16px 0 4px;
  text-align: center;
  color: #98a4ac;
  font-size: 12px;
}
</style>