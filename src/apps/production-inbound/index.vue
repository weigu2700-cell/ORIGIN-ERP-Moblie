<script setup lang="ts">
import { ref } from 'vue';
import { onLoad, onPullDownRefresh, onReachBottom } from '@dcloudio/uni-app';
import { getPageProductionReport } from '@/api/production/production';
import { useWorkbenchStore } from '@/stores/workbench';
import { useSessionGuard, bindPageGuard } from '@/core/auth';
import { useListState } from '@/shared/composables/useListState';
import {
  PRODUCTION_REPORT_STATUS,
  PRODUCTION_REPORT_STATUS_LABEL,
} from '@/constants/domain-enums';
import OfflineBanner from '@/shared/components/OfflineBanner.vue';
import type {
  ProductionReport,
  ProductionReportQuery,
} from '@/types/production/production';

bindPageGuard(useSessionGuard());

const workbenchStore = useWorkbenchStore();
const keyword = ref('');

const statusClass = (s: number) => {
  if (s === PRODUCTION_REPORT_STATUS.APPROVED) return 'tag-approved';
  if (s === PRODUCTION_REPORT_STATUS.FINISHED) return 'tag-finished';
  return 'tag-draft';
};

function buildQuery(target: number): ProductionReportQuery {
  return {
    pageNum: target,
    pageSize: 20,
    productionOrderId: keyword.value.trim() || undefined,
    status: PRODUCTION_REPORT_STATUS.APPROVED,
  };
}

const listState = useListState<ProductionReport>({
  pageSize: 20,
  fetchPage: async (pageNum) => {
    const result = await getPageProductionReport(buildQuery(pageNum));
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

function openDetail(item: ProductionReport) {
  uni.navigateTo({
    url: `/apps/production-inbound/components/detail?id=${encodeURIComponent(item.id)}`,
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

    <view v-if="workbenchStore.currentWarehouse" class="warehouse-bar">
      <wd-icon name="shop" size="14px" color="#245b78" />
      <text class="warehouse-bar-text">{{ workbenchStore.currentWarehouse.name }}</text>
    </view>

    <view class="toolbar">
      <view class="search-box">
        <wd-icon name="search" size="16px" color="#98a4ac" />
        <input
          v-model="keyword"
          class="search-input"
          placeholder="搜索生产订单号"
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
      <text class="meta-total">共 {{ listState.total.value }} 条待入库</text>
    </view>

    <view v-if="listState.isInitialLoading.value" class="state">
      <text class="state-text">正在加载待入库单据...</text>
    </view>

    <view v-else-if="listState.status.value === 'error'" class="state">
      <wd-icon name="warn" size="28px" color="#c94444" />
      <text class="state-text error-text">{{ listState.errorMessage.value || '加载失败' }}</text>
      <view class="retry-btn" hover-class="btn-pressed" @click="handleRetry">点击重试</view>
    </view>

    <view v-else-if="listState.isEmpty.value" class="state">
      <wd-icon name="check-outline" size="28px" color="#4caf50" />
      <text class="state-text">暂无待入库的成品报工单</text>
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
          <text class="card-no">{{ item.productionReportNo }}</text>
          <text class="status-tag" :class="statusClass(item.status)">
            {{ PRODUCTION_REPORT_STATUS_LABEL[item.status] || '未知' }}
          </text>
        </view>
        <text class="material-name">{{ item.materialName || '--' }}</text>
        <text class="material-code">{{ item.materialCode || '暂无编码' }}</text>
        <view class="order-row">
          <text class="order-label">生产订单：</text>
          <text class="order-value">{{ item.productionOrderNo || '--' }}</text>
        </view>
        <view class="bottom-row">
          <view class="qty-line">
            <text class="qty-text">合格 {{ item.qualifiedQuantity }}</text>
            <text class="qty-text">报废 {{ item.scrappedQuantity }}</text>
          </view>
          <wd-icon name="chevron-right" size="14px" color="#9aa7af" />
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

.warehouse-bar {
  margin-bottom: 10px;
  padding: 8px 12px;
  display: flex;
  align-items: center;
  gap: 6px;
  border: 1px solid #d6e0e6;
  border-radius: 8px;
  background: #eef5f8;
}

.warehouse-bar-text {
  color: #245b78;
  font-size: 13px;
  font-weight: 550;
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

.tag-approved {
  color: #e67e22;
  background: #fef4e8;
}

.tag-finished {
  color: #27ae60;
  background: #eafaf1;
}

.material-name {
  display: block;
  margin-top: 8px;
  color: #162631;
  font-size: 14px;
}

.material-code {
  display: block;
  margin-top: 2px;
  color: #98a4ac;
  font-size: 12px;
}

.order-row {
  margin-top: 8px;
  display: flex;
  align-items: center;
  gap: 4px;
}

.order-label {
  color: #6f7f89;
  font-size: 12px;
}

.order-value {
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

.qty-line {
  display: flex;
  gap: 16px;
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