<script setup lang="ts">
import { computed, ref } from "vue";
import { onPullDownRefresh, onShow } from "@dcloudio/uni-app";
import { useUserStore } from "@/stores/user";
import { useWorkbenchStore } from "@/stores/workbench";
import type { Warehouse } from "@/types/master/warehouse";

interface Shortcut {
  key: string;
  title: string;
  icon: string;
  tone: string;
  permissions: string[];
}

interface SummaryItem {
  key: string;
  label: string;
  value: number | null;
  icon: string;
  tone: string;
}

const userStore = useUserStore();
const workbenchStore = useWorkbenchStore();
const warehouseSheetVisible = ref(false);
const initialized = ref(false);

const shortcuts: Shortcut[] = [
  { key: "scan", title: "扫一扫", icon: "scan", tone: "navy", permissions: [] },
  { key: "stock", title: "库存查询", icon: "search", tone: "blue", permissions: ["inventory:stock:query", "inventory:material-stock:list"] },
  { key: "purchase-inbound", title: "采购入库", icon: "shop", tone: "amber", permissions: ["purchase:inbound"] },
  { key: "production-picking", title: "生产领料", icon: "goods", tone: "green", permissions: ["production:picking", "production"] },
  { key: "production-inbound", title: "成品入库", icon: "layers", tone: "cyan", permissions: ["production:inbound", "production"] },
  { key: "sales-outbound", title: "销售出库", icon: "cart", tone: "orange", permissions: ["sales:outbound", "sales:delivery:list"] },
  { key: "production-order", title: "生产订单", icon: "list", tone: "violet", permissions: ["production", "production:order:list"] },
  { key: "sales-order", title: "销售订单", icon: "a-rootlist", tone: "red", permissions: ["sales:order:list"] },
];

const visibleShortcuts = computed(() =>
  shortcuts.filter((item) => userStore.hasAnyPermission(item.permissions)),
);

const greeting = computed(() => {
  const hour = new Date().getHours();
  if (hour < 6) return "夜深了";
  if (hour < 11) return "早上好";
  if (hour < 14) return "中午好";
  if (hour < 18) return "下午好";
  return "晚上好";
});

const userMeta = computed(() =>
  [userStore.profile?.deptName, userStore.primaryRole].filter(Boolean).join(" · "),
);
const avatarText = computed(() => userStore.displayName.slice(0, 1).toUpperCase());

const summaryItems = computed<SummaryItem[]>(() => [
  { key: "purchase-inbound", label: "待采购入库", value: workbenchStore.summary.purchaseInboundPending, icon: "shop", tone: "amber" },
  { key: "production-picking", label: "待生产领料", value: workbenchStore.summary.productionPickingPending, icon: "goods", tone: "green" },
  { key: "sales-outbound", label: "待销售出库", value: workbenchStore.summary.salesOutboundPending, icon: "cart", tone: "orange" },
  { key: "production-order", label: "生产中", value: workbenchStore.summary.productionInProgress, icon: "setting", tone: "blue" },
]);

const todoItems = computed(() => summaryItems.value.filter((item) => (item.value || 0) > 0));
const warehouseActions = computed(() => workbenchStore.warehouses.map((warehouse) => ({
  name: warehouse.name,
  subname: warehouse.code,
})));

async function loadWorkbench() {
  try {
    await workbenchStore.initialize();
    initialized.value = true;
  } catch {
    uni.showToast({ title: "工作台加载失败，请下拉重试", icon: "none" });
  }
}

function openFeature(key: string, title: string, status?: string) {
  if (key === "scan") {
    uni.scanCode({
      scanType: ["barCode", "qrCode"],
      success: ({ result }) => {
        uni.navigateTo({
          url: `/pages/feature/index?title=${encodeURIComponent("扫码结果")}&value=${encodeURIComponent(result)}`,
        });
      },
      fail: (error) => {
        if (!/cancel/i.test(error.errMsg || "")) {
          uni.showToast({ title: "扫码失败，请重试", icon: "none" });
        }
      },
    });
    return;
  }

  const params = [`title=${encodeURIComponent(title)}`, `feature=${encodeURIComponent(key)}`];
  if (status) params.push(`status=${encodeURIComponent(status)}`);
  if (workbenchStore.currentWarehouse) params.push(`warehouseId=${workbenchStore.currentWarehouse.id}`);
  uni.navigateTo({ url: `/pages/feature/index?${params.join("&")}` });
}

function openSummary(item: SummaryItem) {
  openFeature(item.key, item.label, item.key === "production-order" ? "IN_PROGRESS" : undefined);
}

function openWarehouseSheet() {
  if (!workbenchStore.warehouses.length) {
    uni.showToast({ title: "暂无可用仓库", icon: "none" });
    return;
  }
  if (workbenchStore.canSelectWarehouse) warehouseSheetVisible.value = true;
}

function selectWarehouse(event: { index: number }) {
  const warehouse = workbenchStore.warehouses[event.index] as Warehouse | undefined;
  if (warehouse) workbenchStore.selectWarehouse(warehouse);
}

onShow(() => {
  userStore.restoreSession();
  if (!userStore.isLoggedIn) {
    uni.reLaunch({ url: "/pages/login/login" });
    return;
  }
  if (!initialized.value) loadWorkbench();
});

onPullDownRefresh(async () => {
  await loadWorkbench();
  uni.stopPullDownRefresh();
});
</script>

<template>
  <wd-config-provider :theme-vars="{ colorTheme: '#245b78' }">
    <view class="workbench-page">
      <view class="top-panel">
        <view class="top-line">
          <view>
            <text class="eyebrow">SMARTERP · WORKBENCH</text>
            <text class="greeting">{{ greeting }}，{{ userStore.displayName }}</text>
            <text class="user-meta">{{ userMeta }}</text>
          </view>
          <view class="avatar" aria-hidden="true">{{ avatarText }}</view>
        </view>

        <view class="warehouse-bar" :class="{ selectable: workbenchStore.canSelectWarehouse }" @click="openWarehouseSheet">
          <view class="warehouse-icon"><wd-icon name="shop" size="18px" /></view>
          <view class="warehouse-copy">
            <text class="warehouse-label">当前仓库</text>
            <text class="warehouse-name">{{ workbenchStore.currentWarehouse?.name || "暂未选择仓库" }}</text>
          </view>
          <wd-icon v-if="workbenchStore.canSelectWarehouse" name="chevron-right" size="18px" color="#a9bac4" />
        </view>
      </view>

      <view class="content">
        <view class="section-heading">
          <text class="section-title">今日业务</text>
          <text class="section-note">实时工作量</text>
        </view>

        <wd-skeleton v-if="workbenchStore.loading" animation="gradient" :row-col="[[{ width: '48%', height: '112px' }, { width: '48%', height: '112px', marginLeft: '4%' }], [{ width: '48%', height: '112px' }, { width: '48%', height: '112px', marginLeft: '4%' }]]" />
        <view v-else class="summary-grid">
          <view v-for="item in summaryItems" :key="item.key" class="summary-card" hover-class="card-pressed" @click="openSummary(item)">
            <view class="summary-top">
              <view class="summary-icon" :class="`tone-${item.tone}`"><wd-icon :name="item.icon" size="19px" /></view>
              <wd-icon name="chevron-right" size="16px" color="#9aa7af" />
            </view>
            <text class="summary-value">{{ item.value === null ? "—" : item.value }}</text>
            <text class="summary-label">{{ item.label }}</text>
          </view>
        </view>

        <view class="section-heading quick-heading">
          <text class="section-title">快捷功能</text>
          <text class="section-note">常用业务入口</text>
        </view>

        <view class="quick-panel">
          <wd-grid :column="4" :border="false" clickable bg-color="#ffffff">
            <wd-grid-item v-for="item in visibleShortcuts" :key="item.key" @itemclick="openFeature(item.key, item.title)">
              <view class="quick-item">
                <view class="quick-icon" :class="`tone-${item.tone}`"><wd-icon :name="item.icon" size="24px" /></view>
                <text class="quick-label">{{ item.title }}</text>
              </view>
            </wd-grid-item>
          </wd-grid>
        </view>

        <view class="section-heading todo-heading">
          <text class="section-title">我的待办</text>
          <text v-if="todoItems.length" class="todo-count">{{ todoItems.length }} 项</text>
        </view>

        <view class="todo-panel">
          <view v-if="workbenchStore.loading" class="todo-empty">正在加载待办...</view>
          <view v-else-if="!todoItems.length" class="todo-empty">
            <wd-icon name="check-circle" size="22px" color="#27845f" />
            <text>当前没有待处理业务</text>
          </view>
          <template v-else>
            <view v-for="item in todoItems" :key="item.key" class="todo-row" hover-class="row-pressed" @click="openSummary(item)">
              <view class="todo-dot" :class="`dot-${item.tone}`" />
              <text class="todo-title">{{ item.label }}</text>
              <text class="todo-value">{{ item.value }}</text>
              <wd-icon name="chevron-right" size="17px" color="#9aa7af" />
            </view>
          </template>
        </view>
      </view>

      <wd-action-sheet v-model="warehouseSheetVisible" title="选择当前仓库" cancel-text="取消" :actions="warehouseActions" @select="selectWarehouse" />
    </view>
  </wd-config-provider>
</template>

<style scoped>
.workbench-page { min-height: 100vh; color: #162631; background: #f3f6f8; }
.top-panel { padding: calc(env(safe-area-inset-top) + 24px) 20px 22px; background: #203f54; }
.top-line { display: flex; align-items: flex-start; justify-content: space-between; gap: 20px; }
.eyebrow, .greeting, .user-meta, .warehouse-label, .warehouse-name, .section-title, .section-note, .summary-value, .summary-label, .quick-label { display: block; }
.eyebrow { color: #9fb3c0; font-size: 10px; letter-spacing: 1.2px; }
.greeting { margin-top: 10px; color: #fff; font-size: 24px; font-weight: 650; line-height: 1.25; }
.user-meta { margin-top: 7px; color: #cfdae0; font-size: 13px; }
.avatar { width: 46px; height: 46px; flex: 0 0 46px; display: flex; align-items: center; justify-content: center; border: 1px solid rgba(255, 255, 255, .22); border-radius: 14px; color: #203f54; background: #e8b354; font-size: 18px; font-weight: 700; }
.warehouse-bar { min-height: 62px; margin-top: 24px; padding: 0 14px; display: flex; align-items: center; border: 1px solid rgba(255, 255, 255, .12); border-radius: 12px; background: rgba(255, 255, 255, .08); box-sizing: border-box; }
.warehouse-bar.selectable:active { background: rgba(255, 255, 255, .13); }
.warehouse-icon { width: 34px; height: 34px; display: flex; align-items: center; justify-content: center; border-radius: 9px; color: #f4bd5c; background: rgba(244, 189, 92, .12); }
.warehouse-copy { min-width: 0; flex: 1; margin-left: 11px; }
.warehouse-label { color: #9fb3c0; font-size: 11px; }
.warehouse-name { margin-top: 3px; overflow: hidden; color: #fff; font-size: 14px; font-weight: 550; text-overflow: ellipsis; white-space: nowrap; }
.content { padding: 24px 16px calc(env(safe-area-inset-bottom) + 28px); }
.section-heading { display: flex; align-items: baseline; justify-content: space-between; margin: 0 4px 13px; }
.section-title { font-size: 17px; font-weight: 650; }
.section-note { color: #82919a; font-size: 12px; }
.summary-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 10px; }
.summary-card { min-height: 112px; padding: 14px; border: 1px solid #e1e8ec; border-radius: 12px; background: #fff; box-sizing: border-box; }
.summary-top { display: flex; align-items: center; justify-content: space-between; }
.summary-icon, .quick-icon { display: flex; align-items: center; justify-content: center; }
.summary-icon { width: 34px; height: 34px; border-radius: 9px; }
.summary-value { margin-top: 10px; font-size: 25px; font-weight: 680; line-height: 1; }
.summary-label { margin-top: 7px; color: #71818b; font-size: 12px; }
.card-pressed, .row-pressed { opacity: .72; }
.quick-heading, .todo-heading { margin-top: 28px; }
.quick-panel, .todo-panel { overflow: hidden; border: 1px solid #e1e8ec; border-radius: 14px; background: #fff; }
.quick-item { min-height: 92px; display: flex; flex-direction: column; align-items: center; justify-content: center; }
.quick-icon { width: 42px; height: 42px; border-radius: 12px; }
.quick-label { margin-top: 9px; color: #263843; font-size: 12px; line-height: 1.2; }
.todo-count { color: #245b78; font-size: 12px; }
.todo-empty { min-height: 76px; display: flex; align-items: center; justify-content: center; gap: 9px; color: #71818b; font-size: 13px; }
.todo-row { min-height: 58px; padding: 0 14px; display: flex; align-items: center; border-bottom: 1px solid #edf1f3; }
.todo-row:last-child { border-bottom: 0; }
.todo-dot { width: 7px; height: 7px; margin-right: 11px; border-radius: 50%; }
.todo-title { min-width: 0; flex: 1; font-size: 14px; }
.todo-value { margin-right: 9px; color: #203f54; font-size: 16px; font-weight: 650; }
.tone-navy, .tone-blue { color: #245b78; background: #e8f1f5; }
.tone-amber { color: #9a6612; background: #fff4de; }
.tone-green { color: #23785a; background: #e8f5ef; }
.tone-cyan { color: #16728a; background: #e7f5f8; }
.tone-orange { color: #ad5e19; background: #fff0e2; }
.tone-violet { color: #6650a4; background: #f0ecfa; }
.tone-red { color: #ad4848; background: #fbecec; }
.dot-amber { background: #d99a2b; }
.dot-green { background: #27845f; }
.dot-orange { background: #d97828; }
.dot-blue { background: #2b759b; }
@media screen and (min-width: 600px) { .top-panel, .content { max-width: 520px; margin-right: auto; margin-left: auto; } .top-panel { border-radius: 0 0 18px 18px; } }
</style>
