<script setup lang="ts">
import { computed, ref } from 'vue';
import { onLoad } from '@dcloudio/uni-app';
import { FEATURE_CAPABILITIES, type FeatureKey } from '@/constants/capabilities';
import { useSessionGuard, bindPageGuard } from '@/core/auth';

const guard = useSessionGuard();
bindPageGuard(guard);

const title = ref('业务功能');
const value = ref('');
const feature = ref('');
const warehouseId = ref('');

const description = computed(() => {
  if (value.value)
    return '条码已读取，但当前尚不能据此提交业务操作。请核对内容后重扫，或返回工作台选择具体业务。';
  return '该业务正在建设，本页面不会提交或修改任何业务数据。';
});

const contextLabel = computed(() =>
  warehouseId.value ? '已携带当前仓库上下文' : '未携带仓库上下文',
);

function scanAgain() {
  uni.scanCode({
    scanType: ['barCode', 'qrCode'],
    success: ({ result }) => {
      value.value = result;
    },
    fail: (error) => {
      if (!/cancel/i.test(error.errMsg || '')) {
        uni.showToast({ title: '扫码失败，请检查相机权限后重试', icon: 'none' });
      }
    },
  });
}

function backToWorkbench() {
  uni.switchTab({ url: '/pages/workbench/index' });
}

onLoad((query) => {
  const requestedFeature = String(query?.feature || '') as FeatureKey;
  const capability = FEATURE_CAPABILITIES[requestedFeature];
  title.value = capability?.title || decodeURIComponent(String(query?.title || '业务功能'));
  value.value = decodeURIComponent(String(query?.value || ''));
  feature.value = requestedFeature;
  warehouseId.value = String(query?.warehouseId || '');
  uni.setNavigationBarTitle({ title: title.value });
});
</script>

<template>
  <view class="feature-page">
    <view class="feature-icon"><wd-icon :name="value ? 'scan' : 'setting'" size="30px" /></view>
    <text class="feature-title">{{ title }}</text>
    <text class="feature-description">{{ description }}</text>
    <view v-if="value" class="scan-result">
      <text class="result-label">扫码内容</text>
      <text class="result-value">{{ value }}</text>
    </view>
    <text v-if="feature" class="feature-code">{{ contextLabel }}</text>
    <view class="feature-actions">
      <wd-button
        v-if="value"
        type="primary"
        block
        size="large"
        aria-label="重新扫描条码"
        @click="scanAgain"
        >重新扫码</wd-button
      >
      <wd-button
        :type="value ? 'info' : 'primary'"
        :plain="Boolean(value)"
        block
        size="large"
        aria-label="返回移动工作台"
        @click="backToWorkbench"
        >返回工作台</wd-button
      >
    </view>
  </view>
</template>

<style scoped>
.feature-page {
  min-height: 100dvh;
  padding: 48px 20px;
  text-align: center;
  background: #eef3f5;
  box-sizing: border-box;
}
.feature-icon {
  width: 68px;
  height: 68px;
  margin: 0 auto;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 1px solid #d6e4e9;
  border-radius: 20px;
  color: #245b78;
  background: #fff;
  box-shadow: 0 8px 18px rgba(31, 75, 95, 0.07);
}
.feature-title {
  display: block;
  margin-top: 22px;
  color: #162631;
  font-size: 22px;
  font-weight: 650;
}
.feature-description {
  display: block;
  max-width: 320px;
  margin: 12px auto 0;
  color: #71818b;
  font-size: 14px;
  line-height: 1.7;
}
.scan-result {
  max-width: 360px;
  margin: 28px auto 0;
  padding: 18px;
  border: 1px solid #dbe4e9;
  border-radius: 16px;
  text-align: left;
  background: #fff;
  box-shadow: 0 8px 18px rgba(31, 75, 95, 0.05);
}
.result-label {
  display: block;
  color: #82919a;
  font-size: 12px;
}
.result-value {
  display: block;
  margin-top: 8px;
  color: #162631;
  font-size: 15px;
  word-break: break-all;
}
.feature-code {
  display: block;
  margin-top: 28px;
  color: #a0abb2;
  font-size: 11px;
  letter-spacing: 1px;
}
.feature-actions {
  max-width: 360px;
  margin: 28px auto 0;
  display: flex;
  flex-direction: column;
  gap: 12px;
}
</style>