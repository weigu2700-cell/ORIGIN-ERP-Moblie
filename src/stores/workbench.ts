import { computed, ref } from "vue";
import { defineStore } from "pinia";
import { getEnabledWarehouses } from "@/api/master/warehouse";
import { workbenchApi } from "@/api/workbench";
import { STORAGE_KEYS } from "@/constants/storage";
import type { Warehouse } from "@/types/master/warehouse";
import type { WorkbenchSummary } from "@/types/workbench";
import { useUserStore } from "@/stores/user";

const emptySummary = (): WorkbenchSummary => ({
  purchaseInboundPending: null,
  productionPickingPending: null,
  salesOutboundPending: null,
  productionInProgress: null,
});

export const useWorkbenchStore = defineStore("workbench", () => {
  const userStore = useUserStore();
  const loading = ref(false);
  const summary = ref<WorkbenchSummary>(emptySummary());
  const warehouses = ref<Warehouse[]>([]);
  const currentWarehouse = ref<Warehouse | null>(null);

  const canSelectWarehouse = computed(() => warehouses.value.length > 1);

  function restoreWarehouse() {
    const saved = uni.getStorageSync(STORAGE_KEYS.currentWarehouse) as Warehouse | "";
    currentWarehouse.value = saved && typeof saved === "object" ? saved : null;
  }

  function selectWarehouse(warehouse: Warehouse) {
    currentWarehouse.value = warehouse;
    uni.setStorageSync(STORAGE_KEYS.currentWarehouse, warehouse);
  }

  async function loadWarehouses() {
    if (!userStore.hasAnyPermission(["master:warehouse:list", "inventory:stock:query"])) return;
    try {
      const page = await getEnabledWarehouses();
      warehouses.value = page.records || [];
      const savedId = currentWarehouse.value?.id;
      const savedWarehouse = warehouses.value.find((item) => item.id === savedId);
      if (savedWarehouse) selectWarehouse(savedWarehouse);
      else if (warehouses.value.length === 1) selectWarehouse(warehouses.value[0]);
      else if (currentWarehouse.value && !savedWarehouse) currentWarehouse.value = null;
    } catch {
      warehouses.value = [];
    }
  }

  async function loadSummary() {
    summary.value = emptySummary();
    const tasks: Promise<void>[] = [];

    if (userStore.hasAnyPermission(["production:picking", "production", "production:order:list"])) {
      tasks.push(workbenchApi.getProductionPickingPending()
        .then((value) => { summary.value.productionPickingPending = value; })
        .catch(() => undefined));
      tasks.push(workbenchApi.getProductionInProgress()
        .then((value) => { summary.value.productionInProgress = value; })
        .catch(() => undefined));
    }

    if (userStore.hasAnyPermission(["sales:outbound", "sales:delivery:list"])) {
      tasks.push(workbenchApi.getSalesOutboundPending()
        .then((value) => { summary.value.salesOutboundPending = value; })
        .catch(() => undefined));
    }

    await Promise.all(tasks);
  }

  async function initialize() {
    loading.value = true;
    restoreWarehouse();
    try {
      await userStore.loadUserContext();
      await Promise.all([loadWarehouses(), loadSummary()]);
    } finally {
      loading.value = false;
    }
  }

  return {
    loading,
    summary,
    warehouses,
    currentWarehouse,
    canSelectWarehouse,
    initialize,
    loadSummary,
    selectWarehouse,
  };
});
