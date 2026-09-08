<script setup lang="ts">
import { computed, ref } from "vue";
import { onLoad, onPullDownRefresh, onReachBottom } from "@dcloudio/uni-app";
import { getPageInventory } from "@/api/inventory/inventory";
import { useWorkbenchStore } from "@/stores/workbench";
import type { InventoryQuery, InventoryVo } from "@/types/inventory/inventory";

const PAGE_SIZE = 20;

const workbenchStore = useWorkbenchStore();
const keyword = ref("");
const list = ref<InventoryVo[]>([]);
const total = ref(0);
const page = ref(1);
const loading = ref(false);

const finished = computed(() => list.value.length >= total.value);
const isEmpty = computed(() => !loading.value && !list.value.length);

function formatQty(value?: number | null) {
  return value === null || value === undefined ? "—" : String(value);
}

function buildQuery(target: number): InventoryQuery {
  return {
    pageNum: target,
    pageSize: PAGE_SIZE,
    keyword: keyword.value.trim() || undefined,
    warehouseId: workbenchStore.currentWarehouse?.id,
  };
}

async function loadPage(target: number) {
  if (loading.value) return;

  loading.value = true;
  try {
    const result = await getPageInventory(buildQuery(target));
    const records = result?.records || [];
    list.value = target === 1 ? records : list.value.concat(records);
    total.value = Number(result?.total) || 0;
    page.value = target;
  } catch {
    if (target === 1) {
      list.value = [];
      total.value = 0;
    }
  } finally {
    loading.value = false;
  }
}

function search() {
  loadPage(1);
}

function clearKeyword() {
  keyword.value = "";
  loadPage(1);
}

function loadMore() {
  if (loading.value || finished.value) return;
  loadPage(page.value + 1);
}

function openDetail(item: InventoryVo) {
  uni.navigateTo({
    url: `/apps/inventory/components/detail?id=${encodeURIComponent(item.id)}`,
  });
}

function scanForCreate() {
  uni.scanCode({
    scanType: ["barCode", "qrCode"],
    success: ({ result }) => {
      // 新增流程待接入，这里先保留扫码结果。
      keyword.value = result;
      uni.showToast({ title: `已识别：${result}`, icon: "none" });
      loadPage(1);
    },
    fail: (error) => {
      if (!/cancel/i.test(error.errMsg || "")) {
        uni.showToast({ title: "扫码失败，请重试", icon: "none" });
      }
    },
  });
}

onLoad(() => {
  loadPage(1);
});

onPullDownRefresh(async () => {
  await loadPage(1);
  uni.stopPullDownRefresh();
});

onReachBottom(() => {
  loadMore();
});
</script>

<template>
  <view class="inventory-page">
    <view class="toolbar">
      <view class="search-box">
        <wd-icon name="search" size="16px" color="#98a4ac" />
        <input
          v-model="keyword"
          class="search-input"
          placeholder="搜索物料名称 / 编码"
          placeholder-class="search-placeholder"
          confirm-type="search"
          @confirm="search"
        />
        <view v-if="keyword" class="clear-btn" @click="clearKeyword">
          <wd-icon name="close" size="14px" color="#98a4ac" />
        </view>
      </view>
      <view class="scan-btn" hover-class="btn-pressed" @click="scanForCreate">
        <wd-icon name="scan" size="18px" />
        <text class="scan-text">扫码</text>
      </view>
    </view>

    <view class="list-meta">
      <text class="meta-total">共 {{ total }} 条库存</text>
      <text v-if="workbenchStore.currentWarehouse" class="meta-warehouse">
        {{ workbenchStore.currentWarehouse.name }}
      </text>
    </view>

    <view v-if="loading && !list.length" class="state">正在加载库存...</view>
    <view v-else-if="isEmpty" class="state">
      <wd-icon name="search" size="24px" color="#98a4ac" />
      <text class="state-text">没有找到匹配的库存记录</text>
    </view>

    <view v-else class="list">
      <view
        v-for="item in list"
        :key="item.id"
        class="stock-card"
        hover-class="card-pressed"
        @click="openDetail(item)"
      >
        <view class="card-head">
          <text class="material-name">{{ item.materialName }}</text>
          <wd-icon name="chevron-right" size="16px" color="#9aa7af" />
        </view>
        <text class="material-code">{{ item.materialCode || "—" }}</text>
        <view class="warehouse-row">
          <wd-icon name="shop" size="13px" color="#71818b" />
          <text class="warehouse-text">{{ item.warehouseName || "未指定仓库" }}</text>
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
        <text v-if="loading">加载中...</text>
        <text v-else-if="finished">已加载全部 {{ list.length }} 条</text>
        <text v-else>上拉加载更多</text>
      </view>
    </view>
  </view>
</template>

<style scoped>
.inventory-page {
  min-height: 100vh;
  padding: 12px 16px calc(env(safe-area-inset-bottom) + 20px);
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
  height: 40px;
  padding: 0 12px;
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
  font-size: 14px;
}

.search-placeholder {
  color: #98a4ac;
  font-size: 14px;
}

.clear-btn {
  width: 20px;
  height: 20px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.scan-btn {
  height: 40px;
  padding: 0 14px;
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
  font-size: 14px;
}

.btn-pressed {
  opacity: .72;
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

.meta-warehouse {
  color: #245b78;
  font-size: 12px;
}

.state {
  min-height: 220px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 10px;
  color: #6f7f89;
  font-size: 14px;
}

.state-text {
  color: #6f7f89;
  font-size: 14px;
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
  opacity: .72;
}

.list-footer {
  padding: 16px 0 4px;
  text-align: center;
  color: #98a4ac;
  font-size: 12px;
}
</style>