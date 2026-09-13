<script setup lang="ts">
import { ref } from 'vue';
import { onLoad, onPullDownRefresh } from '@dcloudio/uni-app';
import {
  getDetailPurchaseInStock,
  uploadPurchaseInStock,
} from '@/api/purchase/purchase-in-stock';
import { useSessionGuard, bindPageGuard } from '@/core/auth';
import { PURCHASE_IN_STOCK_STATUS } from '@/constants/domain-enums';
import OfflineBanner from '@/shared/components/OfflineBanner.vue';
import type { AsyncStatus } from '@/shared/types/async-state';
import type { PurchaseInStock, PurchaseInStockUpload } from '@/types/purchase/purchase-in-stock';

bindPageGuard(useSessionGuard());

const status = ref<AsyncStatus>('idle');
const errorMessage = ref('');
const stockId = ref('');
const detail = ref<PurchaseInStock | null>(null);
const uploading = ref(false);
const uploadFormVisible = ref(false);

const uploadForm = ref<PurchaseInStockUpload>({
  storageLocation: '',
  batchNo: '',
  productionDate: '',
  expiryDate: '',
});

const statusMap: Record<number, { label: string; class: string }> = {
  [PURCHASE_IN_STOCK_STATUS.DRAFT]: { label: '草稿', class: 's-draft' },
  [PURCHASE_IN_STOCK_STATUS.APPROVED]: { label: '已审核', class: 's-approved' },
  [PURCHASE_IN_STOCK_STATUS.UPLOADED]: { label: '已上架', class: 's-uploaded' },
};

const typeMap: Record<number, string> = {
  0: '常规入库',
  1: '退货入库',
  2: '赠送入库',
};

const canUpload = () =>
  detail.value?.status === PURCHASE_IN_STOCK_STATUS.APPROVED;

function formatDate(val?: string | null) {
  if (!val) return '--';
  return val;
}

function formatMoney(val?: number | null) {
  if (val === null || val === undefined) return '--';
  return val.toFixed(2);
}

async function loadDetail() {
  if (!stockId.value) return;

  status.value = 'loading';
  try {
    detail.value = await getDetailPurchaseInStock(stockId.value);
    status.value = 'ready';
  } catch (error) {
    detail.value = null;
    status.value = 'error';
    errorMessage.value = error instanceof Error ? error.message : '加载详情失败';
  }
}

function openUploadForm() {
  uploadForm.value = {
    storageLocation: detail.value?.storageLocation || '',
    batchNo: detail.value?.batchNo || '',
    productionDate: detail.value?.productionDate || '',
    expiryDate: detail.value?.expiryDate || '',
  };
  uploadFormVisible.value = true;
}

function closeUploadForm() {
  uploadFormVisible.value = false;
}

async function submitUpload() {
  if (!uploadForm.value.storageLocation.trim()) {
    uni.showToast({ title: '请输入上架库位', icon: 'none' });
    return;
  }

  uploading.value = true;
  try {
    await uploadPurchaseInStock(stockId.value, uploadForm.value);
    uni.showToast({ title: '上架成功', icon: 'success' });
    uploadFormVisible.value = false;
    await loadDetail();
  } catch (error) {
    uni.showToast({
      title: error instanceof Error ? error.message : '上架失败',
      icon: 'none',
    });
  } finally {
    uploading.value = false;
  }
}

onLoad((query) => {
  stockId.value = String(query?.id || '');
  uni.setNavigationBarTitle({ title: '入库单详情' });
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
      <text class="state-text">未找到该入库单</text>
    </view>

    <template v-else-if="detail">
      <view class="hero-card">
        <view class="hero-head">
          <text class="hero-no">{{ detail.purchaseInStockNo }}</text>
          <text
            v-if="statusMap[detail.status]"
            class="hero-status"
            :class="statusMap[detail.status].class"
          >
            {{ statusMap[detail.status].label }}
          </text>
        </view>
        <text class="hero-material">{{ detail.materialName }}</text>
        <text class="hero-code">{{ detail.materialCode || '暂无编码' }}</text>
      </view>

      <view class="info-card">
        <view class="info-row">
          <text class="info-label">采购订单号</text>
          <text class="info-value">{{ detail.purchaseOrderNo || '--' }}</text>
        </view>
        <view class="info-row">
          <text class="info-label">供应商</text>
          <text class="info-value">{{ detail.supplierName || '--' }}</text>
        </view>
        <view class="info-row">
          <text class="info-label">入库类型</text>
          <text class="info-value">{{ typeMap[detail.inType] || '--' }}</text>
        </view>
        <view class="info-row">
          <text class="info-label">仓库</text>
          <text class="info-value">{{ detail.warehouseName || '未指定' }}</text>
        </view>
        <view class="info-row">
          <text class="info-label">库位</text>
          <text class="info-value">{{ detail.storageLocation || '--' }}</text>
        </view>
        <view class="info-row">
          <text class="info-label">批次号</text>
          <text class="info-value">{{ detail.batchNo || '--' }}</text>
        </view>
      </view>

      <view class="qty-card">
        <text class="section-title">入库明细</text>
        <view class="qty-grid">
          <view class="qty-cell">
            <text class="qty-cell-label">入库数量</text>
            <text class="qty-cell-value">{{ detail.inQuantity }}</text>
          </view>
          <view class="qty-cell">
            <text class="qty-cell-label">单价</text>
            <text class="qty-cell-value">{{ formatMoney(detail.unitPrice) }}</text>
          </view>
          <view class="qty-cell">
            <text class="qty-cell-label">总金额</text>
            <text class="qty-cell-value primary">{{ formatMoney(detail.totalAmount) }}</text>
          </view>
        </view>
      </view>

      <view class="info-card">
        <view class="info-row">
          <text class="info-label">生产日期</text>
          <text class="info-value">{{ formatDate(detail.productionDate) }}</text>
        </view>
        <view class="info-row">
          <text class="info-label">到货日期</text>
          <text class="info-value">{{ formatDate(detail.deliveryDate) }}</text>
        </view>
        <view class="info-row">
          <text class="info-label">到期日期</text>
          <text class="info-value">{{ formatDate(detail.expiryDate) }}</text>
        </view>
        <view class="info-row">
          <text class="info-label">操作人</text>
          <text class="info-value">{{ detail.operator || '--' }}</text>
        </view>
        <view class="info-row">
          <text class="info-label">上架时间</text>
          <text class="info-value">{{ formatDate(detail.inDate) }}</text>
        </view>
        <view class="info-row">
          <text class="info-label">备注</text>
          <text class="info-value">{{ detail.remark || '--' }}</text>
        </view>
      </view>

      <view v-if="canUpload()" class="action-bar">
        <view class="action-btn" hover-class="btn-pressed" @click="openUploadForm">
          确认上架
        </view>
      </view>
    </template>

    <!-- 上架表单弹层 -->
    <view v-if="uploadFormVisible" class="sheet-overlay" @click="closeUploadForm">
      <view class="sheet-panel" @click.stop>
        <view class="sheet-head">
          <text class="sheet-title">确认上架信息</text>
          <view class="sheet-close" @click="closeUploadForm">
            <wd-icon name="close" size="18px" color="#6f7f89" />
          </view>
        </view>

        <view class="form">
          <view class="form-item">
            <text class="form-label">上架库位 *</text>
            <input
              v-model="uploadForm.storageLocation"
              class="form-input"
              placeholder="请输入上架库位"
              placeholder-class="form-placeholder"
            />
          </view>
          <view class="form-item">
            <text class="form-label">批次号</text>
            <input
              v-model="uploadForm.batchNo"
              class="form-input"
              placeholder="请输入批次号"
              placeholder-class="form-placeholder"
            />
          </view>
          <view class="form-item">
            <text class="form-label">生产日期</text>
            <input
              v-model="uploadForm.productionDate"
              class="form-input"
              placeholder="如 2024-01-01"
              placeholder-class="form-placeholder"
            />
          </view>
          <view class="form-item">
            <text class="form-label">到期日期</text>
            <input
              v-model="uploadForm.expiryDate"
              class="form-input"
              placeholder="如 2025-12-31"
              placeholder-class="form-placeholder"
            />
          </view>
        </view>

        <view class="sheet-footer">
          <view class="cancel-btn" hover-class="btn-pressed" @click="closeUploadForm">取消</view>
          <view
            class="confirm-btn"
            :class="{ disabled: uploading }"
            hover-class="btn-pressed"
            @click="submitUpload"
          >
            {{ uploading ? '提交中...' : '确认上架' }}
          </view>
        </view>
      </view>
    </view>
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

.s-uploaded {
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

.btn-pressed {
  opacity: 0.72;
}

/* 上架表单弹层 */
.sheet-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 999;
  display: flex;
  align-items: flex-end;
  background: rgba(0, 0, 0, 0.45);
}

.sheet-panel {
  width: 100%;
  max-height: 80vh;
  padding: 24px 20px calc(env(safe-area-inset-bottom) + 20px);
  border-radius: 20px 20px 0 0;
  background: #fff;
  box-sizing: border-box;
  overflow-y: auto;
}

.sheet-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 20px;
}

.sheet-title {
  font-size: 17px;
  font-weight: 650;
  color: #162631;
}

.sheet-close {
  width: 36px;
  height: 36px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.form {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.form-item {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.form-label {
  color: #162631;
  font-size: 14px;
  font-weight: 550;
}

.form-input {
  height: 44px;
  padding: 0 14px;
  border: 1px solid #d6e0e6;
  border-radius: 10px;
  font-size: 14px;
  color: #162631;
  background: #f8fafb;
  box-sizing: border-box;
}

.form-placeholder {
  color: #98a4ac;
  font-size: 14px;
}

.sheet-footer {
  margin-top: 24px;
  display: flex;
  gap: 12px;
}

.cancel-btn {
  flex: 1;
  height: 46px;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 1px solid #d6e0e6;
  border-radius: 12px;
  color: #6f7f89;
  font-size: 15px;
  font-weight: 550;
}

.confirm-btn {
  flex: 2;
  height: 46px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 12px;
  color: #fff;
  font-size: 15px;
  font-weight: 600;
  background: #245b78;
}

.confirm-btn.disabled {
  opacity: 0.6;
}
</style>