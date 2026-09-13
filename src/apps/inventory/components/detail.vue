<script setup lang="ts">
import { ref } from 'vue';
import { onLoad, onPullDownRefresh } from '@dcloudio/uni-app';
import { getDetailInventory } from '@/api/inventory/inventory';
import { useSessionGuard, bindPageGuard } from '@/core/auth';
import type { AsyncStatus } from '@/shared/types/async-state';
import type { InventoryVo } from '@/types/inventory/inventory';

bindPageGuard(useSessionGuard());

const status = ref<AsyncStatus>('idle');
const errorMessage = ref('');
const stockId = ref('');
const detail = ref<InventoryVo | null>(null);

const fields = [
  { key: 'id' as const, label: '库存 ID' },
  { key: 'materialId' as const, label: '物料 ID' },
  { key: 'materialCode' as const, label: '物料编码' },
] as const;

const qtyFields = [
  { key: 'onHand' as const, label: '在库数量' },
  { key: 'reserved' as const, label: '预留数量' },
  { key: 'available' as const, label: '可用数量', primary: true },
] as const;

function formatValue(value?: string | number | null) {
  if (value === null || value === undefined || value === '') return '--';
  return String(value);
}

async function loadDetail() {
  if (!stockId.value) return;

  status.value = 'loading';
  errorMessage.value = '';

  try {
    detail.value = await getDetailInventory(stockId.value);
    status.value = 'ready';
  } catch (error) {
    detail.value = null;
    status.value = 'error';
    errorMessage.value = error instanceof Error ? error.message : '加载库存明细失败';
  }
}

onLoad((query) => {
  stockId.value = String(query?.id || '');
  uni.setNavigationBarTitle({ title: '库存明细' });
  loadDetail();
});

onPullDownRefresh(async () => {
  await loadDetail();
  uni.stopPullDownRefresh();
});
</script>

<template>
  <view class="detail-page">
    <!-- 加载态 -->
    <view v-if="status === 'loading' && !detail" class="state">
      <text class="state-text">正在加载明细...</text>
    </view>

    <!-- 错误态 -->
    <view v-else-if="status === 'error'" class="state">
      <wd-icon name="warn" size="28px" color="#c94444" />
      <text class="state-text error-text">{{ errorMessage || '加载失败' }}</text>
      <view class="retry-btn" hover-class="btn-pressed" @click="loadDetail">点击重试</view>
    </view>

    <!-- 无数据 -->
    <view v-else-if="status === 'ready' && !detail" class="state">
      <wd-icon name="search" size="28px" color="#98a4ac" />
      <text class="state-text">未找到该库存记录</text>
    </view>

    <!-- 详情内容 -->
    <template v-else-if="detail">
      <view class="hero-card">
        <text class="hero-name">{{ detail.materialName }}</text>
        <text class="hero-code">{{ detail.materialCode || '暂无编码' }}</text>
        <view class="hero-tag">
          <wd-icon name="shop" size="13px" />
          <text class="hero-tag-text">{{ detail.warehouseName || '未指定仓库' }}</text>
        </view>
      </view>

      <view class="info-card">
        <view v-for="field in fields" :key="field.key" class="info-row">
          <text class="info-label">{{ field.label }}</text>
          <text class="info-value">{{ formatValue(detail[field.key]) }}</text>
        </view>
      </view>

      <view class="qty-card">
        <text class="section-title">库存数量</text>
        <view class="qty-grid">
          <view v-for="item in qtyFields" :key="item.key" class="qty-cell">
            <text class="qty-cell-label">{{ item.label }}</text>
            <text class="qty-cell-value" :class="{ primary: item.primary }">
              {{ formatValue(detail[item.key]) }}
            </text>
          </view>
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
  background: rgba(244, 189, 92, 0.12);
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

.btn-pressed {
  opacity: 0.72;
}
</style>