<script setup lang="ts">
import { computed, ref } from "vue";
import { onLoad, onPullDownRefresh } from "@dcloudio/uni-app";
import { getDetailInventory } from "@/api/inventory/inventory";
import type { InventoryVo } from "@/types/inventory/inventory";

const loading = ref(false);
const stockId = ref("");
const detail = ref<InventoryVo | null>(null);

const rows = computed(() => {
  const item = detail.value;
  if (!item) return [];

  return [
    { label: "库存 ID", value: item.id || "—" },
    { label: "物料 ID", value: item.materialId || "—" },
    { label: "物料编码", value: item.materialCode || "—" },
    { label: "所属仓库", value: item.warehouseName || "—" },
    { label: "在库数量", value: String(item.onHand ?? "—"), primary: false },
    { label: "预留数量", value: String(item.reserve ?? "—"), primary: false },
    { label: "可用数量", value: String(item.available ?? "—"), primary: true },
  ];
});

async function loadDetail() {
  if (!stockId.value) return;

  loading.value = true;
  try {
    detail.value = await getDetailInventory(stockId.value);
  } catch {
    detail.value = null;
  } finally {
    loading.value = false;
  }
}

onLoad((query) => {
  stockId.value = String(query?.id || "");
  uni.setNavigationBarTitle({ title: "库存明细" });
  loadDetail();
});

onPullDownRefresh(async () => {
  await loadDetail();
  uni.stopPullDownRefresh();
});
</script>

<template>
  <view class="detail-page">
    <view v-if="loading && !detail" class="state">正在加载明细...</view>

    <view v-else-if="!detail" class="state">
      <wd-icon name="search" size="24px" color="#98a4ac" />
      <text class="state-text">未找到该库存记录</text>
    </view>

    <template v-else>
      <view class="hero-card">
        <text class="hero-name">{{ detail.materialName }}</text>
        <text class="hero-code">{{ detail.materialCode || "—" }}</text>
        <view class="hero-tag">
          <wd-icon name="shop" size="13px" />
          <text class="hero-tag-text">{{ detail.warehouseName || "未指定仓库" }}</text>
        </view>
      </view>

      <view class="info-card">
        <view v-for="row in rows" :key="row.label" class="info-row">
          <text class="info-label">{{ row.label }}</text>
          <text class="info-value" :class="{ primary: row.primary }">{{ row.value }}</text>
        </view>
      </view>
    </template>
  </view>
</template>

<style scoped>
.detail-page {
  min-height: 100vh;
  padding: 16px;
  color: #162631;
  background: #f4f7f9;
  box-sizing: border-box;
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

.hero-card {
  padding: 20px;
  border-radius: 14px;
  color: #fff;
  background: #203f54;
}

.hero-name {
  display: block;
  font-size: 19px;
  font-weight: 650;
  line-height: 1.35;
}

.hero-code {
  display: block;
  margin-top: 6px;
  color: #cfdae0;
  font-size: 13px;
}

.hero-tag {
  margin-top: 14px;
  padding: 5px 10px;
  display: inline-flex;
  align-items: center;
  gap: 6px;
  border-radius: 8px;
  color: #f4bd5c;
  background: rgba(244, 189, 92, .12);
}

.hero-tag-text {
  color: #f4bd5c;
  font-size: 12px;
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
  min-height: 52px;
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

.info-value.primary {
  color: #245b78;
}
</style>
