import { captureSession, isSessionCurrent, onSessionChange } from '@/utils/auth';
import { computed, ref, onScopeDispose } from 'vue';
import { defineStore } from 'pinia';
import { getEnabledWarehouses } from '@/api/master/warehouse';
import { workbenchApi } from '@/api/workbench';
import { STORAGE_KEYS } from '@/constants/storage';
import type { Warehouse } from '@/types/master/warehouse';
import type { WorkbenchSummary } from '@/types/workbench';
import { useUserStore } from '@/stores/user';
import { PERMISSIONS } from '@/constants/capabilities';

type SummaryKey = keyof WorkbenchSummary;
type LoadStatus = 'idle' | 'loading' | 'ready' | 'error' | 'forbidden';

const summaryKeys: SummaryKey[] = [
  'purchaseInboundPending',
  'productionPickingPending',
  'salesOutboundPending',
  'productionInProgress',
];

const emptySummary = (): WorkbenchSummary => ({
  purchaseInboundPending: null,
  productionPickingPending: null,
  salesOutboundPending: null,
  productionInProgress: null,
});

export const useWorkbenchStore = defineStore('workbench', () => {
  const userStore = useUserStore();
  const loading = ref(false);
  const summary = ref<WorkbenchSummary>(emptySummary());
  const warehouses = ref<Warehouse[]>([]);
  const currentWarehouse = ref<Warehouse | null>(null);
  const restoredWarehouseId = ref('');
  const warehouseStatus = ref<LoadStatus>('idle');
  const summaryStatus = ref<Record<SummaryKey, LoadStatus>>({
    purchaseInboundPending: 'idle',
    productionPickingPending: 'idle',
    salesOutboundPending: 'idle',
    productionInProgress: 'idle',
  });
  const summaryErrors = ref<Partial<Record<SummaryKey, string>>>({});
  const lastSyncedAt = ref<Date | null>(null);

  const canSelectWarehouse = computed(() => warehouses.value.length > 1);

  function restoreWarehouse() {
    const savedId = uni.getStorageSync(STORAGE_KEYS.currentWarehouseId);
    const legacy = uni.getStorageSync(STORAGE_KEYS.currentWarehouse) as Warehouse | '';
    restoredWarehouseId.value = savedId
      ? String(savedId)
      : legacy && typeof legacy === 'object' && legacy.id
        ? String(legacy.id)
        : '';
    if (restoredWarehouseId.value) {
      uni.setStorageSync(STORAGE_KEYS.currentWarehouseId, restoredWarehouseId.value);
    }
    uni.removeStorageSync(STORAGE_KEYS.currentWarehouse);
  }

  async function selectWarehouse(warehouse: Warehouse) {
    currentWarehouse.value = warehouse;
    restoredWarehouseId.value = String(warehouse.id);
    uni.setStorageSync(STORAGE_KEYS.currentWarehouseId, restoredWarehouseId.value);
    await loadSummary();
  }

  async function loadWarehouses() {
    const snapshot = captureSession();
    if (userStore.permissionsStatus === 'error') {
      warehouseStatus.value = 'error';
      return;
    }
    if (!userStore.hasAnyPermission([PERMISSIONS.warehouseList])) {
      warehouseStatus.value = 'forbidden';
      warehouses.value = [];
      currentWarehouse.value = null;
      return;
    }
    warehouseStatus.value = 'loading';
    try {
      const page = await getEnabledWarehouses();
      if (!isSessionCurrent(snapshot)) return;
      warehouses.value = page.records || [];
      const savedWarehouse = warehouses.value.find(
        (item) => String(item.id) === restoredWarehouseId.value,
      );
      if (savedWarehouse) currentWarehouse.value = savedWarehouse;
      else if (warehouses.value.length === 1) {
        currentWarehouse.value = warehouses.value[0];
        restoredWarehouseId.value = String(warehouses.value[0].id);
        uni.setStorageSync(STORAGE_KEYS.currentWarehouseId, restoredWarehouseId.value);
      } else {
        currentWarehouse.value = null;
        restoredWarehouseId.value = '';
        uni.removeStorageSync(STORAGE_KEYS.currentWarehouseId);
      }
      warehouseStatus.value = 'ready';
    } catch {
      if (!isSessionCurrent(snapshot)) return;
      warehouses.value = [];
      currentWarehouse.value = null;
      warehouseStatus.value = 'error';
    }
  }

  function getErrorMessage(error: unknown) {
    return error instanceof Error ? error.message : '数据加载失败';
  }

  async function loadSummaryItem(key: SummaryKey) {
    const snapshot = captureSession();
    const definitions = {
      purchaseInboundPending: {
        permission: PERMISSIONS.purchaseInboundList,
        load: workbenchApi.getPurchaseInboundPending,
      },
      productionPickingPending: {
        permission: PERMISSIONS.productionPickingList,
        load: workbenchApi.getProductionPickingPending,
      },
      salesOutboundPending: {
        permission: PERMISSIONS.salesDeliveryList,
        load: workbenchApi.getSalesOutboundPending,
      },
      productionInProgress: {
        permission: PERMISSIONS.productionOrderList,
        load: workbenchApi.getProductionInProgress,
      },
    } as const;

    if (userStore.permissionsStatus === 'error') {
      summaryStatus.value[key] = 'error';
      summaryErrors.value[key] = '权限信息加载失败，请重试';
      return false;
    }

    const definition = definitions[key];
    if (!userStore.hasAnyPermission([definition.permission])) {
      summary.value[key] = null;
      summaryStatus.value[key] = 'forbidden';
      delete summaryErrors.value[key];
      return false;
    }

    summaryStatus.value[key] = 'loading';
    delete summaryErrors.value[key];
    try {
      const value = await definition.load();
      if (!isSessionCurrent(snapshot)) return false;
      summary.value[key] = value;
      summaryStatus.value[key] = 'ready';
      return true;
    } catch (error) {
      if (!isSessionCurrent(snapshot)) return false;
      summaryStatus.value[key] = 'error';
      summaryErrors.value[key] = getErrorMessage(error);
      return false;
    }
  }

  async function loadSummary() {
    if (userStore.businessAvailable === false) { reset(); return; }
    const snapshot = captureSession();
    const results = await Promise.all(summaryKeys.map((key) => loadSummaryItem(key)));
    if (isSessionCurrent(snapshot) && results.some(Boolean)) lastSyncedAt.value = new Date();
  }

  async function initialize() {
    const snapshot = captureSession();
    loading.value = true;
    restoreWarehouse();
    try {
      const authenticated = await userStore.validateSession();
      if (!authenticated || !isSessionCurrent(snapshot)) return;
      if (userStore.businessAvailable === false) { reset(); return; }
      await Promise.all([loadWarehouses(), loadSummary()]);
    } finally {
      if (isSessionCurrent(snapshot)) loading.value = false;
    }
  }

  function reset() {
    loading.value = false; summary.value = emptySummary(); warehouses.value = []; currentWarehouse.value = null;
    restoredWarehouseId.value = ''; warehouseStatus.value = 'idle'; summaryErrors.value = {}; lastSyncedAt.value = null;
    for (const key of summaryKeys) summaryStatus.value[key] = 'idle';
  }
  onScopeDispose(onSessionChange(reset));

  return {
    reset,
    loading,
    summary,
    warehouses,
    currentWarehouse,
    warehouseStatus,
    summaryStatus,
    summaryErrors,
    lastSyncedAt,
    canSelectWarehouse,
    initialize,
    loadWarehouses,
    loadSummary,
    loadSummaryItem,
    selectWarehouse,
  };
});
