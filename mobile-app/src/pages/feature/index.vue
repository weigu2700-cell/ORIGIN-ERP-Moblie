<script setup lang="ts">
import { computed, ref } from "vue";
import { onLoad } from "@dcloudio/uni-app";

const title = ref("业务功能");
const value = ref("");
const feature = ref("");
const status = ref("");

const description = computed(() => {
  if (value.value) return "已识别条码，可在库存查询功能接入后自动查询物料。";
  if (status.value) return `已携带筛选状态：${status.value}`;
  return "入口和业务上下文已就绪，后续将在这里接入完整作业流程。";
});

onLoad((query) => {
  title.value = decodeURIComponent(String(query?.title || "业务功能"));
  value.value = decodeURIComponent(String(query?.value || ""));
  feature.value = String(query?.feature || "");
  status.value = String(query?.status || "");
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
    <text v-if="feature" class="feature-code">{{ feature }}</text>
  </view>
</template>

<style scoped>
.feature-page { min-height: 100vh; padding: 72px 24px; text-align: center; background: #f3f6f8; box-sizing: border-box; }
.feature-icon { width: 62px; height: 62px; margin: 0 auto; display: flex; align-items: center; justify-content: center; border-radius: 18px; color: #245b78; background: #e4eef3; }
.feature-title { display: block; margin-top: 22px; color: #162631; font-size: 22px; font-weight: 650; }
.feature-description { display: block; max-width: 320px; margin: 12px auto 0; color: #71818b; font-size: 14px; line-height: 1.7; }
.scan-result { margin-top: 28px; padding: 16px; border: 1px solid #dbe4e9; border-radius: 12px; text-align: left; background: #fff; }
.result-label { display: block; color: #82919a; font-size: 12px; }
.result-value { display: block; margin-top: 8px; color: #162631; font-size: 15px; word-break: break-all; }
.feature-code { display: block; margin-top: 28px; color: #a0abb2; font-size: 11px; letter-spacing: 1px; }
</style>
