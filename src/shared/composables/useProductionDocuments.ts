import { computed, ref } from 'vue';
import { onLoad, onShow, onPullDownRefresh, onReachBottom } from '@dcloudio/uni-app';
import { useSessionGuard } from '@/core/auth';
import { useUserStore } from '@/stores/user';
import { useWorkbenchStore } from '@/stores/workbench';
import { useListState } from './useListState';
import { confirmOperation, useWriteAction } from './useWriteAction';
import { documentFlows } from '@/core/production/documents';
import type { DocumentKind, DocumentAction, ProductionDocument } from '@/core/production/documents';

export function useProductionDocumentList(kind: DocumentKind) {
  const flow = documentFlows[kind];
  const user = useUserStore();
  const warehouse = useWorkbenchStore();
  const guard = useSessionGuard();
  const keyword = ref('');
  const selectedStatus = ref<number>();
  const orderId = ref<string>();
  const canRead = computed(() => user.hasAnyPermission([flow.listPermission]));
  const state = useListState<ProductionDocument>({
    fetchPage: (pageNum) =>
      flow.list(
        pageNum,
        keyword.value.trim(),
        selectedStatus.value,
        kind === 'inbound' ? warehouse.currentWarehouse?.id : undefined,
        orderId.value,
      ),
  });
  async function refresh() {
    if (!(await guard.runGuard())) return;
    if (!canRead.value) {
      state.reset();
      return;
    }
    await state.refresh();
  }
  function open(item: ProductionDocument) {
    if (!user.hasAnyPermission([flow.detailPermission])) {
      uni.showToast({ title: '没有查看详情权限，请联系管理员', icon: 'none' });
      return;
    }
    uni.navigateTo({ url: `${flow.base}/detail?id=${encodeURIComponent(item.id)}` });
  }
  function filter(value?: number) {
    selectedStatus.value = value;
    void refresh();
  }
  onLoad((query) => {
    if (query?.orderId) orderId.value = String(query.orderId);
  });
  onShow(() => void refresh());
  onPullDownRefresh(async () => {
    try {
      await refresh();
    } finally {
      uni.stopPullDownRefresh();
    }
  });
  onReachBottom(() => {
    if (canRead.value) void state.loadMore();
  });
  return {
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
  };
}

export function useProductionDocumentDetail(kind: DocumentKind) {
  const flow = documentFlows[kind];
  const user = useUserStore();
  const guard = useSessionGuard();
  const id = ref('');
  const detail = ref<ProductionDocument>();
  const loading = ref(false);
  const error = ref('');
  const write = useWriteAction();
  let sequence = 0;
  const actions = computed(() =>
    flow.actions.filter(
      (action) =>
        action.status === detail.value?.status && user.hasAnyPermission([action.permission]),
    ),
  );
  async function load() {
    if (write.busy.value) return;
    if (!(await guard.runGuard())) return;
    const current = ++sequence;
    error.value = '';
    if (!id.value) {
      error.value = '缺少单据编号，请返回列表重新选择';
      return;
    }
    if (!user.hasAnyPermission([flow.detailPermission])) {
      detail.value = undefined;
      error.value = '没有查看详情权限，请联系管理员';
      return;
    }
    loading.value = true;
    try {
      const result = await flow.detail(id.value);
      if (current === sequence) detail.value = result;
    } catch (failure) {
      if (current === sequence) {
        detail.value = undefined;
        error.value = failure instanceof Error ? failure.message : '加载失败，请重试';
      }
    } finally {
      if (current === sequence) loading.value = false;
    }
  }
  async function act(action: DocumentAction) {
    try {
      const completed = await write.run({
        allowed: () =>
          user.isLoggedIn &&
          user.hasAnyPermission([action.permission]) &&
          user.hasAnyPermission([flow.detailPermission]),
        prepare: async () => {
          if (!(await confirmOperation(action.label, `${detail.value?.no || ''}\n${action.hint}`)))
            return false;
          detail.value = await flow.detail(id.value);
          if (detail.value.status !== action.status)
            throw new Error('单据状态已变化，已刷新详情，请重新核对');
          if (kind === 'report' && action.label === '完成报工' && !detail.value.qualified)
            throw new Error('合格数量为零，无法完成报工');
        },
        execute: async () => {
          if ((await action.execute(id.value)) === false)
            throw new Error('操作未成功，请刷新核对单据状态');
        },
      });
      if (completed) {
        uni.showToast({ title: `${action.label}成功`, icon: 'success' });
        await load();
      }
    } catch (failure) {
      uni.showToast({
        title: failure instanceof Error ? failure.message : '操作失败，请刷新核对',
        icon: 'none',
      });
    }
  }
  onLoad((query) => {
    id.value = String(query?.id || '');
  });
  onShow(() => void load());
  onPullDownRefresh(async () => {
    try {
      await load();
    } finally {
      uni.stopPullDownRefresh();
    }
  });
  return { flow, detail, loading, error, write, actions, load, act };
}
