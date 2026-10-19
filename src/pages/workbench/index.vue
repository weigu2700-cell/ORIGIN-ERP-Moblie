<script setup lang="ts">
import { computed, ref } from 'vue';
import { onPullDownRefresh, onShow } from '@dcloudio/uni-app';
import { useUserStore } from '@/stores/user';
import { useWorkbenchStore } from '@/stores/workbench';
import type { Warehouse } from '@/types/master/warehouse';
import { FEATURE_CAPABILITIES, type FeatureKey } from '@/constants/capabilities';

interface Shortcut {
  key: FeatureKey;
  title: string;
  icon: string;
  tone: string;
  permissions: string[];
  available: boolean;
  route?: string;
}

interface SummaryItem {
  key: string;
  label: string;
  value: number | null;
  icon: string;
  tone: string;
  summaryKey: keyof typeof workbenchStore.summary;
}

const userStore = useUserStore();
const workbenchStore = useWorkbenchStore();
const warehouseSheetVisible = ref(false);
const initialized = ref(false);

const shortcuts: Shortcut[] = [
  { ...FEATURE_CAPABILITIES.scan, icon: 'scan', tone: 'navy' },
  { ...FEATURE_CAPABILITIES.stock, icon: 'search', tone: 'blue' },
  { ...FEATURE_CAPABILITIES['purchase-inbound'], icon: 'shop', tone: 'amber' },
  { ...FEATURE_CAPABILITIES['production-picking'], icon: 'goods', tone: 'green' },
  { ...FEATURE_CAPABILITIES['production-inbound'], icon: 'layers', tone: 'cyan' },
  { ...FEATURE_CAPABILITIES['sales-outbound'], icon: 'cart', tone: 'orange' },
  { ...FEATURE_CAPABILITIES['production-order'], icon: 'list', tone: 'violet' },
  { ...FEATURE_CAPABILITIES['sales-order'], icon: 'a-rootlist', tone: 'red' },
];

const visibleShortcuts = computed(() =>
  shortcuts.filter((item) => userStore.hasAnyPermission(item.permissions)),
);

const greeting = computed(() => {
  const hour = new Date().getHours();
  if (hour < 6) return '夜深了';
  if (hour < 11) return '早上好';
  if (hour < 14) return '中午好';
  if (hour < 18) return '下午好';
  return '晚上好';
});

const userMeta = computed(() =>
  [userStore.profile?.deptName, userStore.primaryRole].filter(Boolean).join(' · '),
);
const avatarText = computed(() => userStore.displayName.slice(0, 1).toUpperCase());

const summaryItems = computed<SummaryItem[]>(() => [
  {
    key: 'purchase-inbound',
    summaryKey: 'purchaseInboundPending',
    label: '待采购入库',
    value: workbenchStore.summary.purchaseInboundPending,
    icon: 'shop',
    tone: 'amber',
  },
  {
    key: 'production-picking',
    summaryKey: 'productionPickingPending',
    label: '待生产领料',
    value: workbenchStore.summary.productionPickingPending,
    icon: 'goods',
    tone: 'green',
  },
  {
    key: 'sales-outbound',
    summaryKey: 'salesOutboundPending',
    label: '待销售出库',
    value: workbenchStore.summary.salesOutboundPending,
    icon: 'cart',
    tone: 'orange',
  },
  {
    key: 'production-order',
    summaryKey: 'productionInProgress',
    label: '生产中',
    value: workbenchStore.summary.productionInProgress,
    icon: 'setting',
    tone: 'blue',
  },
]);

const todoItems = computed(() =>
  summaryItems.value.filter(
    (item) => workbenchStore.summaryStatus[item.summaryKey] === 'ready' && (item.value || 0) > 0,
  ),
);
const warehouseActions = computed(() =>
  workbenchStore.warehouses.map((warehouse) => ({
    name: warehouse.name,
  })),
);
const hasSummaryError = computed(() =>
  Object.values(workbenchStore.summaryStatus).includes('error'),
);
const lastSyncedLabel = computed(() => {
  const value = workbenchStore.lastSyncedAt;
  if (!value) return '尚未同步';
  return `更新于 ${value.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`;
});
const systemStatusText = computed(() => {
  if (workbenchStore.loading) return '正在同步';
  if (userStore.permissionsStatus === 'error' || hasSummaryError.value) return '部分数据未更新';
  return lastSyncedLabel.value;
});

async function loadWorkbench() {
  try {
    await workbenchStore.initialize();
    initialized.value = true;
  } catch {
    uni.showToast({ title: '工作台加载失败，请下拉重试', icon: 'none' });
  }
}

function summaryStateLabel(item: SummaryItem) {
  const state = workbenchStore.summaryStatus[item.summaryKey];
  if (state === 'loading') return '正在加载';
  if (state === 'error') return '加载失败，点击重试';
  if (state === 'forbidden') return '无查看权限';
  if (item.value === null) return '尚未同步';
  return item.value > 0 ? '需要处理' : '已清空';
}

function summaryValue(item: SummaryItem) {
  const state = workbenchStore.summaryStatus[item.summaryKey];
  if (state === 'loading') return '…';
  if (state === 'error') return '!';
  if (state === 'forbidden') return '—';
  return item.value === null ? '—' : item.value;
}

function openFeature(item: Shortcut, status?: string) {
  if (item.route) {
    uni.navigateTo({ url: item.route });
    return;
  }

  const params = [
    `title=${encodeURIComponent(item.title)}`,
    `feature=${encodeURIComponent(item.key)}`,
  ];
  if (status) params.push(`status=${encodeURIComponent(status)}`);
  if (workbenchStore.currentWarehouse)
    params.push(`warehouseId=${workbenchStore.currentWarehouse.id}`);
  uni.navigateTo({ url: `/pages/feature/index?${params.join('&')}` });
}

async function openSummary(item: SummaryItem) {
  const state = workbenchStore.summaryStatus[item.summaryKey];
  if (state === 'error') {
    await workbenchStore.loadSummaryItem(item.summaryKey);
    return;
  }
  if (state !== 'ready') return;
  const feature = shortcuts.find((entry) => entry.key === item.key);
  if (feature) openFeature(feature, item.key === 'production-order' ? '2' : undefined);
}

function openWarehouseSheet() {
  if (!workbenchStore.warehouses.length) {
    uni.showToast({ title: '暂无可用仓库', icon: 'none' });
    return;
  }
  if (workbenchStore.canSelectWarehouse) warehouseSheetVisible.value = true;
}

async function selectWarehouse(event: { index: number }) {
  const warehouse = workbenchStore.warehouses[event.index] as Warehouse | undefined;
  if (warehouse) await workbenchStore.selectWarehouse(warehouse);
}

onShow(async () => {
  userStore.restoreSession();
  if (!userStore.hasToken) {
    uni.reLaunch({ url: '/pages/login/login' });
    return;
  }
  if (!initialized.value) {
    await loadWorkbench();
    return;
  }
  try {
    const authenticated = await userStore.validateSession(true);
    if (!authenticated) {
      uni.reLaunch({ url: '/pages/login/login' });
      return;
    }
    await workbenchStore.loadSummary();
  } catch {
    userStore.restoreSession();
    if (!userStore.hasToken) uni.reLaunch({ url: '/pages/login/login' });
  }
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
            <view class="brand-line">
              <text class="eyebrow">ORIGIN MANUFACTURING</text>
              <view
                class="system-status"
                :class="{
                  'system-status-warning':
                    hasSummaryError || userStore.permissionsStatus === 'error',
                }"
                :aria-label="systemStatusText"
              >
                <view class="status-dot" />{{ systemStatusText }}
              </view>
            </view>
            <text class="greeting">{{ greeting }}，{{ userStore.displayName }}</text>
            <text class="user-meta">{{ userMeta }}</text>
          </view>
          <view class="avatar" aria-hidden="true">{{ avatarText }}</view>
        </view>

        <view
          class="warehouse-bar"
          :class="{ selectable: workbenchStore.canSelectWarehouse }"
          :role="workbenchStore.canSelectWarehouse ? 'button' : undefined"
          :aria-label="
            workbenchStore.canSelectWarehouse
              ? `当前仓库 ${workbenchStore.currentWarehouse?.name || '未选择'}，点击切换`
              : `当前仓库 ${workbenchStore.currentWarehouse?.name || '未选择'}`
          "
          @click="openWarehouseSheet"
        >
          <view class="warehouse-icon"><wd-icon name="shop" size="18px" /></view>
          <view class="warehouse-copy">
            <text class="warehouse-label">当前仓库</text>
            <text class="warehouse-name">{{
              workbenchStore.currentWarehouse?.name || '暂未选择仓库'
            }}</text>
          </view>
          <wd-icon
            v-if="workbenchStore.canSelectWarehouse"
            name="chevron-right"
            size="18px"
            color="#a9bac4"
          />
        </view>
        <view class="focus-strip">
          <wd-icon name="clock" size="15px" color="#f2c16a" />
          <text>{{
            hasSummaryError
              ? '部分数据未更新，可点击失败卡片重试'
              : '数据在进入页面和完成业务后同步'
          }}</text>
        </view>
      </view>

      <view class="content">
        <wd-notice-bar
          v-if="userStore.permissionsStatus === 'error'"
          type="warning"
          prefix="warning"
          wrapable
          :scrollable="false"
          text="权限信息加载失败，业务入口可能不完整。请下拉重试。"
          custom-style="margin-bottom: 18px; border-radius: 10px;"
        />
        <view class="section-heading">
          <text class="section-title">今日业务</text>
          <text class="section-note">{{ lastSyncedLabel }}</text>
        </view>

        <wd-skeleton
          v-if="workbenchStore.loading"
          animation="gradient"
          :row-col="[
            [
              { width: '48%', height: '112px' },
              { width: '48%', height: '112px', marginLeft: '4%' },
            ],
            [
              { width: '48%', height: '112px' },
              { width: '48%', height: '112px', marginLeft: '4%' },
            ],
          ]"
        />
        <view v-else class="summary-grid">
          <view
            v-for="item in summaryItems"
            :key="item.key"
            class="summary-card"
            :class="{
              'summary-card-active':
                workbenchStore.summaryStatus[item.summaryKey] === 'ready' && (item.value || 0) > 0,
              'summary-card-error': workbenchStore.summaryStatus[item.summaryKey] === 'error',
            }"
            role="button"
            :aria-label="`${item.label}，${summaryStateLabel(item)}`"
            hover-class="card-pressed"
            @click="openSummary(item)"
          >
            <view class="summary-top">
              <view class="summary-icon" :class="`tone-${item.tone}`"
                ><wd-icon :name="item.icon" size="19px"
              /></view>
              <wd-icon name="chevron-right" size="16px" color="#9aa7af" />
            </view>
            <text class="summary-value">{{ summaryValue(item) }}</text>
            <text class="summary-label">{{ item.label }}</text>
            <text class="summary-state">{{ summaryStateLabel(item) }}</text>
          </view>
        </view>

        <view class="section-heading quick-heading">
          <text class="section-title">快捷功能</text>
          <text class="section-note">常用业务入口</text>
        </view>

        <view class="quick-panel">
          <wd-grid :column="4" :border="false" clickable bg-color="#ffffff">
            <wd-grid-item
              v-for="item in visibleShortcuts"
              :key="item.key"
              @itemclick="openFeature(item)"
            >
              <view
                class="quick-item"
                role="button"
                :aria-label="`${item.title}${item.available ? '' : '，正在建设'}`"
              >
                <view class="quick-icon" :class="`tone-${item.tone}`"
                  ><wd-icon :name="item.icon" size="24px"
                /></view>
                <text class="quick-label">{{ item.title }}</text>
                <text v-if="!item.available" class="quick-state">建设中</text>
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
            <wd-icon
              :name="hasSummaryError ? 'warning' : 'check-circle'"
              size="22px"
              :color="hasSummaryError ? '#b47520' : '#27845f'"
            />
            <text>{{
              hasSummaryError ? '部分待办加载失败，请在上方重试' : '当前没有待处理业务'
            }}</text>
          </view>
          <template v-else>
            <view
              v-for="item in todoItems"
              :key="item.key"
              class="todo-row"
              role="button"
              :aria-label="`${item.label} ${item.value} 条`"
              hover-class="row-pressed"
              @click="openSummary(item)"
            >
              <view class="todo-dot" :class="`dot-${item.tone}`" />
              <text class="todo-title">{{ item.label }}</text>
              <text class="todo-value">{{ item.value }}</text>
              <wd-icon name="chevron-right" size="17px" color="#9aa7af" />
            </view>
          </template>
        </view>
      </view>

      <wd-action-sheet
        v-model="warehouseSheetVisible"
        title="选择当前仓库"
        cancel-text="取消"
        :actions="warehouseActions"
        @select="selectWarehouse"
      />
    </view>
  </wd-config-provider>
</template>

<style scoped>
.workbench-page {
  min-height: 100dvh;
  color: #162631;
  background: #eef3f5;
}

.top-panel {
  padding: calc(env(safe-area-inset-top) + 22px) 20px 18px;
  background: linear-gradient(145deg, #18384b 0%, #203f54 52%, #2b6178 100%);
  box-shadow: 0 10px 24px rgba(20, 57, 76, 0.12);
}

.top-line {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 20px;
}

.eyebrow,
.greeting,
.user-meta,
.warehouse-label,
.warehouse-name,
.section-title,
.section-note,
.summary-value,
.summary-label,
.quick-label {
  display: block;
}

.brand-line {
  display: flex;
  align-items: center;
  gap: 10px;
}

.eyebrow {
  color: #b7c8d1;
  font-size: 10px;
  letter-spacing: 1.35px;
}

.system-status {
  height: 22px;
  padding: 0 8px;
  display: flex;
  align-items: center;
  gap: 5px;
  border: 1px solid rgba(255, 255, 255, 0.14);
  border-radius: 11px;
  color: #d8e8e2;
  background: rgba(255, 255, 255, 0.08);
  font-size: 10px;
}

.status-dot {
  width: 5px;
  height: 5px;
  border-radius: 50%;
  background: #70c89b;
}

.system-status-warning {
  color: #ffe0a3;
}

.system-status-warning .status-dot {
  background: #f2c16a;
}

.greeting {
  margin-top: 12px;
  color: #fff;
  font-size: 25px;
  font-weight: 700;
  line-height: 1.25;
}

.user-meta {
  margin-top: 7px;
  color: #cfdae0;
  font-size: 13px;
}

.avatar {
  width: 46px;
  height: 46px;
  flex: 0 0 46px;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 1px solid rgba(255, 255, 255, 0.22);
  border-radius: 14px;
  color: #203f54;
  background: #e8b354;
  font-size: 18px;
  font-weight: 700;
}

.warehouse-bar {
  min-height: 62px;
  margin-top: 22px;
  padding: 0 14px;
  display: flex;
  align-items: center;
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.08);
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.08);
  box-sizing: border-box;
}

.warehouse-bar.selectable:active {
  background: rgba(255, 255, 255, 0.13);
}

.warehouse-icon {
  width: 34px;
  height: 34px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 9px;
  color: #f4bd5c;
  background: rgba(244, 189, 92, 0.12);
}

.warehouse-copy {
  min-width: 0;
  flex: 1;
  margin-left: 11px;
}

.warehouse-label {
  color: #9fb3c0;
  font-size: 11px;
}

.warehouse-name {
  margin-top: 3px;
  overflow: hidden;
  color: #fff;
  font-size: 14px;
  font-weight: 550;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.focus-strip {
  margin: 13px 2px 0;
  display: flex;
  align-items: center;
  gap: 7px;
  color: #c2d2da;
  font-size: 11px;
}

.content {
  padding: 23px 16px calc(env(safe-area-inset-bottom) + 32px);
}

.section-heading {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  margin: 0 4px 13px;
}

.section-title {
  font-size: 17px;
  font-weight: 650;
}

.section-note {
  color: #82919a;
  font-size: 12px;
}

.summary-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px;
}

.summary-card {
  min-height: 112px;
  padding: 14px 14px 12px;
  border: 1px solid #e1e8ec;
  border-radius: 14px;
  background: #fff;
  box-sizing: border-box;
}

.summary-card-active {
  border-color: #d6e4e9;
  box-shadow: 0 5px 12px rgba(31, 75, 95, 0.05);
}

.summary-card-error {
  border-color: #ecd4aa;
  background: #fffaf1;
}

.summary-card-error .summary-state {
  color: #9a6612;
}

.summary-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.summary-icon,
.quick-icon {
  display: flex;
  align-items: center;
  justify-content: center;
}

.summary-icon {
  width: 34px;
  height: 34px;
  border-radius: 9px;
}

.summary-value {
  margin-top: 10px;
  font-size: 27px;
  font-weight: 720;
  line-height: 1;
}

.summary-label {
  margin-top: 7px;
  color: #71818b;
  font-size: 12px;
}

.summary-state {
  display: block;
  margin-top: 6px;
  color: #99a7af;
  font-size: 10px;
}

.summary-card-active .summary-state {
  color: #b47520;
}

.card-pressed,
.row-pressed {
  opacity: 0.72;
}

.quick-heading,
.todo-heading {
  margin-top: 28px;
}

.quick-panel,
.todo-panel {
  overflow: hidden;
  border: 1px solid #e1e8ec;
  border-radius: 16px;
  background: #fff;
  box-shadow: 0 6px 16px rgba(31, 75, 95, 0.035);
}

.quick-item {
  min-height: 96px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
}

.quick-icon {
  width: 42px;
  height: 42px;
  border-radius: 14px;
}

.quick-label {
  margin-top: 9px;
  color: #263843;
  font-size: 12px;
  line-height: 1.2;
}

.quick-state {
  margin-top: 4px;
  color: #98a4ac;
  font-size: 10px;
}

.todo-count {
  color: #245b78;
  font-size: 12px;
}

.todo-empty {
  min-height: 76px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 9px;
  color: #71818b;
  font-size: 13px;
}

.todo-row {
  min-height: 58px;
  padding: 0 14px;
  display: flex;
  align-items: center;
  border-bottom: 1px solid #edf1f3;
}

.todo-row:last-child {
  border-bottom: 0;
}

.todo-dot {
  width: 7px;
  height: 7px;
  margin-right: 11px;
  border-radius: 50%;
}

.todo-title {
  min-width: 0;
  flex: 1;
  font-size: 14px;
}

.todo-value {
  margin-right: 9px;
  color: #203f54;
  font-size: 16px;
  font-weight: 650;
}

.tone-navy,
.tone-blue {
  color: #245b78;
  background: #e8f1f5;
}

.tone-amber {
  color: #9a6612;
  background: #fff4de;
}

.tone-green {
  color: #23785a;
  background: #e8f5ef;
}

.tone-cyan {
  color: #16728a;
  background: #e7f5f8;
}

.tone-orange {
  color: #ad5e19;
  background: #fff0e2;
}

.tone-violet {
  color: #6650a4;
  background: #f0ecfa;
}

.tone-red {
  color: #ad4848;
  background: #fbecec;
}

.dot-amber {
  background: #d99a2b;
}

.dot-green {
  background: #27845f;
}

.dot-orange {
  background: #d97828;
}

.dot-blue {
  background: #2b759b;
}

@media screen and (min-width: 600px) {
  .top-panel,
  .content {
    max-width: 520px;
    margin-right: auto;
    margin-left: auto;
  }

  .top-panel {
    border-radius: 0 0 18px 18px;
  }
}
</style>
