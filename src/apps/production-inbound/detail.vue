<script setup lang="ts">
import OfflineBanner from '@/shared/components/OfflineBanner.vue';
import { useProductionDocumentDetail } from '@/shared/composables/useProductionDocuments';
const { flow, detail, loading, error, write, actions, load, act } =
  useProductionDocumentDetail('inbound');
</script>
<template>
  <view class="production-page"
    ><OfflineBanner />
    <text class="heading">{{ flow.title }}详情</text>
    <view v-if="loading" class="state" aria-live="polite">正在核对单据…</view>
    <view v-else-if="error" class="state error" role="alert"
      >{{ error }}<button role="button" @click="load">重新加载</button></view
    >
    <template v-else-if="detail">
      <view class="doc-card"
        ><text class="no">{{ detail.no }}</text
        ><view class="row"
          ><text>{{ detail.materialName || '--' }}</text
          ><text>{{ flow.labels[detail.status] || '未知状态' }}</text></view
        ><text class="hint">{{ detail.materialCode }}</text></view
      >
      <view class="doc-card">
        <view class="row"
          ><text class="label">生产订单</text><text>{{ detail.orderNo || '--' }}</text></view
        >
        <view v-if="detail.reportNo" class="row"
          ><text class="label">来源报工单</text><text>{{ detail.reportNo }}</text></view
        >
        <view class="row"
          ><text class="label">仓库</text
          ><text>{{ detail.warehouseName || '请核对来源单据仓库' }}</text></view
        >
        <view class="row"
          ><text class="label">{{ flow.title === '生产报工' ? '报工数量' : '入库数量' }}</text
          ><text>{{ detail.quantity }}</text></view
        >
        <view v-if="detail.qualified !== undefined" class="row"
          ><text class="label">合格 / 报废</text
          ><text>{{ detail.qualified }} / {{ detail.scrapped }}</text></view
        >
        <view class="row"
          ><text class="label">经办人</text><text>{{ detail.userName || '--' }}</text></view
        ><view class="row"
          ><text class="label">时间</text><text>{{ detail.time || '尚未执行' }}</text></view
        ><view class="row"
          ><text class="label">备注</text><text>{{ detail.remark || '--' }}</text></view
        >
      </view>
      <text class="hint">{{ flow.hint }}</text>
      <text v-if="write.errorMessage.value" class="error" role="alert">{{
        write.errorMessage.value
      }}</text>
      <view class="actions"
        ><button role="button"
          v-for="(action, index) in actions"
          :key="action.label"
          :class="index === 0 ? 'primary' : 'secondary'"
          :disabled="write.busy.value"
          :loading="write.busy.value"
          @click="act(action)"
        >
          {{ action.label }}
        </button></view
      >
      <text v-if="!actions.length" class="hint"
        >此状态暂无可用操作；如需处理，请核对账号权限。</text
      >
    </template>
  </view>
</template>
<style scoped lang="scss">
@use '@/shared/styles/production.scss';
</style>
