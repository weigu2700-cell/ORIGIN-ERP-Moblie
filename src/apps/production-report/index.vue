<script setup lang="ts">
import OfflineBanner from '@/shared/components/OfflineBanner.vue';
import { useProductionDocumentList } from '@/shared/composables/useProductionDocuments';
import { PERMISSION_CODES as P } from '@/core/auth';
const {
  flow,
  user,
  warehouse,
  guard,
  keyword,
  selectedStatus,
  canRead,
  state,
  refresh,
  open,
  filter,
} = useProductionDocumentList('report');
function create() {
  uni.navigateTo({ url: '/apps/production-report/create' });
}
</script>
<template>
  <view class="production-page">
    <OfflineBanner />
    <view class="page-head"
      ><text class="heading">{{ flow.title }}</text>
      <button role="button"
        v-if="flow.title === '生产报工' && user.hasAnyPermission([P.productionReportCreate])"
        class="primary"
        @click="create"
      >
        登记报工
      </button>
    </view>
    <text class="hint">{{ flow.hint }}</text>
    <view v-if="flow.title === '成品入库' && warehouse.currentWarehouse" class="hint"
      >当前仓库：{{ warehouse.currentWarehouse.name }}</view
    >
    <view v-if="guard.guardStatus.value === 'error'" class="state error"
      >会话校验失败，请恢复网络后重试<button role="button" @click="refresh">重试</button></view
    >
    <view v-else-if="!canRead" class="state">没有查询权限，请联系管理员授权。</view>
    <template v-else>
      <view class="controls"
        ><input
          v-model="keyword"
          :placeholder="flow.title === '生产报工' ? '搜索报工单号' : '搜索入库单号'"
          aria-label="搜索单号"
          confirm-type="search"
          @confirm="refresh"
        /><button role="button" class="secondary" @click="refresh">查询</button></view
      >
      <view class="tabs"
        ><button role="button" :class="{ selected: selectedStatus === undefined }" @click="filter()">全部</button
        ><button role="button"
          v-for="(label, index) in flow.labels"
          :key="label"
          :class="{ selected: selectedStatus === index }"
          @click="filter(index)"
        >
          {{ label }}
        </button></view
      >
      <view v-if="state.isInitialLoading.value" class="state" aria-live="polite"
        >正在加载单据…</view
      >
      <view v-else-if="state.status.value === 'error'" class="state error" role="alert"
        >{{ state.errorMessage.value }}<button role="button" @click="refresh">重新加载</button></view
      >
      <view v-else-if="state.isEmpty.value" class="state"
        >暂无符合条件的单据，请切换状态或查询其他单号。</view
      >
      <button role="button"
        v-for="item in state.list.value"
        :key="item.id"
        class="doc-card"
        :aria-label="'查看' + item.no"
        @click="open(item)"
      >
        <text class="no">{{ item.no }}</text
        ><view class="row"
          ><text>{{ item.materialName || '--' }}</text
          ><text>{{ flow.labels[item.status] || '未知状态' }}</text></view
        >
        <view class="row"
          ><text class="label">数量 {{ item.quantity }}</text
          ><text>{{ item.warehouseName || '仓库待核对' }}</text></view
        ><text class="hint">{{ item.orderNo || '生产订单' }}</text>
      </button>
      <text v-if="state.errorMessage.value && state.list.value.length" class="error" role="alert">{{
        state.errorMessage.value
      }}</text>
      <button role="button"
        v-if="state.list.value.length && !state.finished.value"
        :disabled="state.loading.value"
        @click="state.loadMore"
      >
        {{ state.loading.value ? '加载中…' : '加载更多' }}
      </button>
      <text v-else-if="state.list.value.length" class="hint"
        >已加载全部 {{ state.total.value }} 条</text
      >
    </template>
  </view>
</template>
<style scoped lang="scss">
@use '@/shared/styles/production.scss';
</style>
