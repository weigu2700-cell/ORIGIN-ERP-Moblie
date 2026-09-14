<script setup lang="ts">
import { computed, ref } from 'vue';
import { onLoad, onPullDownRefresh, onReachBottom } from '@dcloudio/uni-app';
import { getPageInventory } from '@/api/inventory/inventory';
import { useWorkbenchStore } from '@/stores/workbench';
import { useSessionGuard, bindPageGuard } from '@/core/auth';
import { useListState } from '@/shared/composables/useListState';
import OfflineBanner from '@/shared/components/OfflineBanner.vue';
import type { InventoryQuery, InventoryVo } from '@/types/inventory/inventory';
import type { Warehouse } from '@/types/master/warehouse';

bindPageGuard(useSessionGuard());

const workbenchStore = useWorkbenchStore();
const keyword = ref('');
const warehouseSheetVisible = ref(false);

const warehouseActions = computed(() =>
  workbenchStore.warehouses.map((warehouse) => ({
    name: warehouse.name,
    subname: warehouse.code,
  })),
);

function buildQuery(target: number): InventoryQuery {
  return {
    pageNum: target,
    pageSize: 20,
    keyword: keyword.value.trim() || undefined,
    warehouseId: workbenchStore.currentWarehouse?.id,
  };
}

const listState = useListState<InventoryVo>({
  pageSize: 20,
  fetchPage: async (pageNum, _pSize) => {
    const result = await getPageInventory(buildQuery(pageNum));
    return { records: result?.records || [], total: Number(result?.total) || 0 };
  },
});

function formatQty(value?: number | null) {
  return value === null || value === undefined ? '--' : String(value);
}

function search() {
  listState.refresh();
}

function clearKeyword() {
  keyword.value = '';
  listState.refresh();
}

function openDetail(item: InventoryVo) {
  uni.navigateTo({
    url: `/apps/inventory/components/detail?id=${encodeURIComponent(item.id)}`,
  });
}

function handleScan() {
  uni.scanCode({
    scanType: ['barCode', 'qrCode'],
    success: ({ result }) => {
      keyword.value = result;
      uni.showToast({ title: `已识别：${result}`, icon: 'none' });
      listState.refresh();
    },
    fail: (error) => {
      if (!/cancel/i.test(error.errMsg || '')) {
        uni.showToast({ title: '扫码失败，请重试', icon: 'none' });
      }
    },
  });
}

function handleRetry() {
  listState.refresh();
}

function openWarehouseSheet() {
  if (!workbenchStore.warehouses.length) {
    uni.showToast({ title: '暂无可用仓库', icon: 'none' });
    return;
  }
  if (workbenchStore.canSelectWarehouse) warehouseSheetVisible.value = true;
}

async function selectWarehouse(event: { index: number }) {
  const warehouse = workbenchStore.warehouses[event.index] as Warehouse | undefined;
  if (warehouse) {
    await workbenchStore.selectWarehouse(warehouse);
    listState.refresh();
  }
}

onLoad((query) => {
  keyword.value = decodeURIComponent(String(query?.keyword || ''));
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
  <view class="inventory-page">
    <OfflineBanner />

    <!-- 仓库上下文栏 -->
    <view
      v-if="workbenchStore.currentWarehouse"
      class="warehouse-bar"
      :class="{ selectable: workbenchStore.canSelectWarehouse }"
      :role="workbenchStore.canSelectWarehouse ? 'button' : undefined"
      :aria-label="`当前仓库 ${workbenchStore.currentWarehouse.name}${workbenchStore.canSelectWarehouse ? '，点击切换' : ''}`"
      @click="openWarehouseSheet"
    >
      <wd-icon name="shop" size="14px" color="#245b78" />
      <text class="warehouse-bar-text">{{ workbenchStore.currentWarehouse.name }}</text>
      <wd-icon
        v-if="workbenchStore.canSelectWarehouse"
        name="chevron-down"
        size="14px"
        color="#9aa7af"
      />
    </view>

    <!-- 搜索 + 扫码工具栏 -->
    <view class="toolbar">
      <view class="search-box">
        <wd-icon name="search" size="16px" color="#98a4ac" />
        <input
          v-model="keyword"
          class="search-input"
          placeholder="搜索物料编码"
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
      <view
        class="scan-btn"
        hover-class="btn-pressed"
        role="button"
        aria-label="扫码搜索"
        @click="handleScan"
      >
        <wd-icon name="scan" size="18px" />
        <text class="scan-text">扫码</text>
      </view>
    </view>

    <!-- 列表元信息 -->
    <view class="list-meta">
      <text class="meta-total">共 {{ listState.total.value }} 条库存</text>
    </view>

    <!-- 首次加载态 -->
    <view v-if="listState.isInitialLoading.value" class="state">
      <text class="state-text">正在加载库存...</text>
    </view>

    <!-- 加载失败态 -->
    <view v-else-if="listState.status.value === 'error'" class="state">
      <wd-icon name="warn" size="28px" color="#c94444" />
      <text class="state-text error-text">{{ listState.errorMessage.value || '加载失败' }}</text>
      <view class="retry-btn" hover-class="btn-pressed" @click="handleRetry">点击重试</view>
    </view>

    <!-- 空数据态 -->
    <view v-else-if="listState.isEmpty.value" class="state">
      <wd-icon name="search" size="28px" color="#98a4ac" />
      <text class="state-text">
        {{ keyword ? '没有找到匹配的库存记录' : '当前仓库暂无库存数据' }}
      </text>
      <view v-if="keyword" class="clear-filter-btn" hover-class="btn-pressed" @click="clearKeyword">
        清除筛选
      </view>
    </view>

    <!-- 列表内容 -->
    <view v-else class="list">
      <view
        v-for="item in listState.list.value"
        :key="item.id"
        class="stock-card"
        hover-class="card-pressed"
        role="button"
        :aria-label="`查看 ${item.materialName} 详情`"
        @click="openDetail(item)"
      >
        <view class="card-head">
          <text class="material-name">{{ item.materialName }}</text>
          <wd-icon name="chevron-right" size="16px" color="#9aa7af" />
        </view>
        <text class="material-code">{{ item.materialCode || '暂无编码' }}</text>
        <view class="warehouse-row">
          <wd-icon name="shop" size="13px" color="#71818b" />
          <text class="warehouse-text">{{ item.warehouseName || '未指定仓库' }}</text>
        </view>
        <view class="qty-row">
          <view class="qty-item">
            <text class="qty-label">在库</text>
            <text class="qty-value">{{ formatQty(item.onHand) }}</text>
          </view>
          <view class="qty-item">
            <text class="qty-label">预留</text>
            <text class="qty-value">{{ formatQty(item.reserved) }}</text>
          </view>
          <view class="qty-item">
            <text class="qty-label">可用</text>
            <text class="qty-value primary">{{ formatQty(item.available) }}</text>
          </view>
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

    <wd-action-sheet
      v-model="warehouseSheetVisible"
      title="切换仓库"
      cancel-text="取消"
      :actions="warehouseActions"
      @select="selectWarehouse"
    />
  </view>
</template>

<style scoped>
.inventory-page {
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

.warehouse-bar.selectable {
  cursor: pointer;
}

.warehouse-bar-text {
  flex: 1;
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

.scan-btn {
  height: 44px;
  padding: 0 16px;
  flex: 0 0 auto;
  display: flex;
  align-items: center;
  gap: 6px;
  border-radius: 10px;
  color: #fff;
  background: #245b78;
  box-sizing: border-box;
}

.scan-text {
  font-size: 15px;
}

.btn-pressed {
  opacity: 0.72;
}

.list-meta {
  margin: 14px 4px 10px;
  display: flex;
  align-items: center;
  justify-content: space-between;
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

.clear-filter-btn {
  margin-top: 6px;
  padding: 8px 24px;
  color: #245b78;
  font-size: 14px;
  border: 1px solid #245b78;
  border-radius: 8px;
}

.list {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.stock-card {
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

.material-name {
  min-width: 0;
  flex: 1;
  overflow: hidden;
  color: #162631;
  font-size: 15px;
  font-weight: 600;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.material-code {
  display: block;
  margin-top: 4px;
  color: #98a4ac;
  font-size: 12px;
}

.warehouse-row {
  margin-top: 10px;
  display: flex;
  align-items: center;
  gap: 6px;
}

.warehouse-text {
  color: #6f7f89;
  font-size: 12px;
}

.qty-row {
  margin-top: 12px;
  padding-top: 12px;
  display: flex;
  align-items: center;
  border-top: 1px solid #eef2f4;
}

.qty-item {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.qty-label {
  color: #6f7f89;
  font-size: 11px;
}

.qty-value {
  color: #162631;
  font-size: 16px;
  font-weight: 650;
}

.qty-value.primary {
  color: #245b78;
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
