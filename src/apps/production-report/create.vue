<script setup lang="ts">
import { computed, ref } from 'vue';
import { onLoad, onShow } from '@dcloudio/uni-app';
import { useSessionGuard, PERMISSION_CODES as P } from '@/core/auth';
import { useUserStore } from '@/stores/user';
import { useWorkbenchStore } from '@/stores/workbench';
import {
  getDetailProductionOrder,
  getPageProductionOrder,
  createProductionReport,
} from '@/api/production/production';
import { getEnabledWarehouses } from '@/api/master/warehouse';
import { buildReportPayload, isUncertainWrite } from '@/core/production/report-form';
import { useWriteAction } from '@/shared/composables/useWriteAction';
import OfflineBanner from '@/shared/components/OfflineBanner.vue';
import type { ProductionOrder } from '@/types/production/production';
import type { Warehouse } from '@/types/master/warehouse';

const user = useUserStore();
const workbench = useWorkbenchStore();
const guard = useSessionGuard();
const write = useWriteAction();
const keyword = ref('');
const order = ref<ProductionOrder>();
const orders = ref<ProductionOrder[]>([]);
const ordersTotal = ref(0);
const warehouses = ref<Warehouse[]>([]);
const warehouseId = ref('');
const warehousePage = ref(0);
const warehouseTotal = ref(0);
const loading = ref(false);
const error = ref('');
const submitted = ref(false);
const uncertain = ref(false);
const form = ref({ quantity: '', qualified: '', scrapped: '0', remark: '' });
const canCreate = computed(
  () =>
    user.hasAnyPermission([P.productionReportCreate]) &&
    user.hasAnyPermission([P.productionOrderDetail]),
);
const selectedWarehouse = computed(() =>
  warehouses.value.find((item) => item.id === warehouseId.value),
);
let initialOrderId = '';
let initialized = false;
let sequence = 0;

async function searchOrders() {
  if (!user.hasAnyPermission([P.productionOrderList])) {
    error.value = '没有生产订单查询权限，请从已授权的生产订单详情进入报工';
    return;
  }
  const current = ++sequence;
  loading.value = true;
  error.value = '';
  try {
    const result = await getPageProductionOrder({
      pageNum: 1,
      pageSize: 10,
      status: 2,
      productionOrderNo: keyword.value.trim() || undefined,
    });
    if (current === sequence) {
      orders.value = result.records;
      ordersTotal.value = result.total;
    }
  } catch (failure) {
    if (current === sequence)
      error.value = failure instanceof Error ? failure.message : '订单查询失败';
  } finally {
    if (current === sequence) loading.value = false;
  }
}
async function loadWarehouses() {
  if (loading.value || !user.hasAnyPermission([P.warehouseList])) return;
  loading.value = true;
  try {
    const page = await getEnabledWarehouses(warehousePage.value + 1);
    warehouses.value = warehouses.value.concat(page.records);
    warehousePage.value++;
    warehouseTotal.value = page.total;
    if (
      !warehouseId.value &&
      warehouses.value.some((item) => item.id === workbench.currentWarehouse?.id)
    )
      warehouseId.value = workbench.currentWarehouse!.id;
  } catch (failure) {
    error.value = failure instanceof Error ? failure.message : '仓库查询失败，请重试';
  } finally {
    loading.value = false;
  }
}
async function selectOrder(id: string) {
  if (write.busy.value) return;
  const current = ++sequence;
  loading.value = true;
  error.value = '';
  try {
    const fresh = await getDetailProductionOrder(id);
    if (current !== sequence) return;
    if (fresh.status !== 2) throw new Error('该订单不在生产中，请选择其他订单');
    order.value = fresh;
    warehouseId.value = fresh.warehouseId || '';
  } catch (failure) {
    if (current === sequence)
      error.value = failure instanceof Error ? failure.message : '订单详情加载失败';
  } finally {
    if (current === sequence) loading.value = false;
  }
  if (order.value && !order.value.warehouseId && !warehouses.value.length) await loadWarehouses();
}
function chooseWarehouse(event: { detail: { value: string | number } }) {
  warehouseId.value = warehouses.value[Number(event.detail.value)]?.id || '';
}
async function initialize() {
  if (!(await guard.runGuard()) || !canCreate.value || initialized) return;
  initialized = true;
  if (initialOrderId) await selectOrder(initialOrderId);
  else await searchOrders();
}
function viewRecords() {
  if (!user.hasAnyPermission([P.productionReportList])) {
    uni.showToast({ title: '请联系有报工查询权限的人员核对提交结果', icon: 'none' });
    return;
  }
  uni.navigateTo({
    url: `/apps/production-report/index?orderId=${encodeURIComponent(order.value?.id || '')}`,
  });
}
async function submit() {
  if (submitted.value || uncertain.value || loading.value) return;
  error.value = '';
  try {
    const completed = await write.run({
      allowed: () => user.isLoggedIn && canCreate.value,
      prepare: async () => {
        if (!order.value) throw new Error('请先选择生产订单');
        buildReportPayload(order.value, warehouseId.value, form.value);
        const fresh = await getDetailProductionOrder(order.value.id);
        if (fresh.materialId !== order.value.materialId)
          throw new Error('生产物料已变化，请重新选择订单');
        order.value = fresh;
        buildReportPayload(fresh, warehouseId.value, form.value);
      },
      execute: async () => {
        try {
          await createProductionReport(
            buildReportPayload(order.value!, warehouseId.value, form.value),
          );
        } catch (failure) {
          if (isUncertainWrite(failure)) uncertain.value = true;
          throw failure;
        }
      },
    });
    if (completed) submitted.value = true;
  } catch (failure) {
    error.value = failure instanceof Error ? failure.message : '提交失败，输入已保留';
  }
}
onLoad((query) => {
  initialOrderId = String(query?.orderId || '');
});
onShow(() => void initialize());
</script>
<template>
  <view class="production-page"
    ><OfflineBanner /><text class="heading">登记生产报工</text>
    <view v-if="guard.guardStatus.value === 'error'" class="state error"
      >会话校验失败<button role="button" @click="initialize">重试</button></view
    >
    <view v-else-if="!canCreate" class="state"
      >需要报工登记及生产订单详情权限，请联系管理员授权。</view
    >
    <view v-else-if="submitted" class="doc-card" role="status"
      ><text class="no success">报工已提交，等待审批</text
      ><text class="hint">完成审批与报工后生成成品入库单，再执行入库。请勿重复提交本次报工。</text
      ><button role="button" @click="viewRecords">查看本订单报工记录</button></view
    >
    <template v-else>
      <text class="hint"
        >选择生产中的订单，核对物料、目标仓库和本次数量。累计数量由服务端校验。</text
      >
      <view v-if="error" class="error" role="alert">{{ error }}</view>
      <view v-if="uncertain" class="doc-card"
        ><text class="error"
          >提交结果尚未确认。请先核对报工记录，避免重复报工；本页不会自动重试。</text
        ><button role="button" @click="viewRecords">查看报工记录</button></view
      >
      <template v-if="!order">
        <view class="controls"
          ><input
            v-model="keyword"
            placeholder="搜索生产订单号"
            aria-label="生产订单号"
            @confirm="searchOrders"
          /><button role="button" :disabled="loading" @click="searchOrders">查询</button></view
        >
        <view v-if="loading" class="state">正在查询生产订单…</view>
        <button role="button" v-else-if="initialOrderId" class="secondary" @click="selectOrder(initialOrderId)">
          重新加载指定订单
        </button>
        <button role="button"
          v-for="item in orders"
          :key="item.id"
          class="doc-card"
          :disabled="loading"
          @click="selectOrder(item.id)"
        >
          <text class="no">{{ item.productionOrderNo }}</text
          ><text>{{ item.materialName }} · 计划 {{ item.plannedQuantity }}</text>
        </button>
        <text v-if="!loading && !orders.length" class="hint"
          >暂无匹配的生产中订单，请检查单号或先完成领料、开工。</text
        >
        <text v-if="ordersTotal > orders.length" class="hint"
          >共 {{ ordersTotal }} 个匹配订单，显示前 10 个，请输入更完整的单号。</text
        >
      </template>
      <template v-else>
        <view class="doc-card"
          ><text class="no">{{ order.productionOrderNo }}</text
          ><text class="hint"
            >{{ order.materialName }} · {{ order.materialCode }} · 计划
            {{ order.plannedQuantity }}</text
          ><button role="button"
            v-if="!initialOrderId"
            :disabled="write.busy.value || uncertain"
            @click="order = undefined"
          >
            更换订单
          </button></view
        >
        <view v-if="order.warehouseId" class="doc-card"
          >入库仓库沿用生产订单的目标仓库，不可更换。</view
        >
        <view v-else class="field"
          ><text class="label">成品入库仓库（必选）</text>
          <picker
            :range="warehouses"
            range-key="name"
            :disabled="write.busy.value || loading || uncertain"
            @change="chooseWarehouse"
            ><view class="picker-value">{{ selectedWarehouse?.name || '请选择仓库' }}</view></picker
          >
          <text v-if="!user.hasAnyPermission([P.warehouseList])" class="error"
            >未配置目标仓库且没有仓库查询权限，请联系管理员处理。</text
          >
          <button role="button"
            v-if="warehousePage === 0 || warehouses.length < warehouseTotal"
            :disabled="loading"
            @click="loadWarehouses"
          >
            {{ loading ? '加载中…' : warehousePage ? '加载更多仓库' : '加载可用仓库' }}
          </button>
        </view>
        <view
          v-for="field in [
            { key: 'quantity', title: '报工数量' },
            { key: 'qualified', title: '合格数量' },
            { key: 'scrapped', title: '报废数量' },
          ]"
          :key="field.key"
          class="field"
        >
          <text class="label">{{ field.title }}（必填）</text
          ><input
            v-model="form[field.key as 'quantity' | 'qualified' | 'scrapped']"
            type="digit"
            :aria-label="field.title"
            :disabled="write.busy.value || uncertain"
            placeholder="最多四位小数"
          />
        </view>
        <text class="hint">合格与报废数量之和不能超过报工数量；零合格量的报工单无法完成报工。</text>
        <view class="field"
          ><text class="label">备注（选填）</text
          ><textarea
            v-model="form.remark"
            maxlength="255"
            :disabled="write.busy.value || uncertain"
            aria-label="报工备注"
            placeholder="填写本次生产情况"
          />
        </view>
        <button role="button"
          class="primary"
          :disabled="write.busy.value || loading || uncertain"
          :loading="write.busy.value"
          @click="submit"
        >
          {{ write.busy.value ? '提交中…' : '提交报工' }}
        </button>
      </template>
    </template>
  </view>
</template>
<style scoped lang="scss">
@use '@/shared/styles/production.scss';
</style>
