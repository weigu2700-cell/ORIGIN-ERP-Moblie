export const PERMISSIONS = Object.freeze({
  warehouseList: 'master:warehouse:list',
  inventoryList: 'inventory:material-stock:list',
  inventoryDetail: 'inventory:material-stock:get',
  inventoryCreate: 'inventory:material-stock:create',
  purchaseInboundList: 'purchase:in:stock:list',
  purchaseInboundDetail: 'purchase:in:stock:detail',
  purchaseInboundApprove: 'purchase:in:stock:approve',
  purchaseInboundUpload: 'purchase:in:stock:upload',
  productionPickingList: 'production:picking:list',
  productionPickingApprove: 'production:picking:approve',
  productionPickingConfirm: 'production:picking:confirm',
  finishedWarehousingList: 'inv:finish-warehousing:list',
  finishedWarehousingDetail: 'inv:finish-warehousing:get',
  finishedWarehousingUpdate: 'inv:finish-warehousing:update',
  salesDeliveryList: 'sales:delivery:list',
  salesDeliveryDetail: 'sales:delivery:get',
  salesDeliveryConfirm: 'sales:delivery:confirm',
  salesDeliveryComplete: 'sales:delivery:complete',
  salesDeliveryCancel: 'sales:delivery:cancel',
  productionOrderList: 'production:order:list',
  productionOrderDetail: 'production:order:get',
  salesOrderList: 'sales:order:list',
} as const);

export type FeatureKey =
  | 'scan'
  | 'stock'
  | 'purchase-inbound'
  | 'production-picking'
  | 'production-inbound'
  | 'sales-outbound'
  | 'production-order'
  | 'sales-order';

export interface FeatureCapability {
  key: FeatureKey;
  title: string;
  permissions: string[];
  route?: string;
  available: boolean;
}

export const FEATURE_CAPABILITIES: Record<FeatureKey, FeatureCapability> = {
  scan: { key: 'scan', title: '扫一扫', permissions: [], available: true },
  stock: {
    key: 'stock',
    title: '库存查询',
    permissions: [PERMISSIONS.inventoryList],
    route: '/apps/inventory/index',
    available: true,
  },
  'purchase-inbound': {
    key: 'purchase-inbound',
    title: '采购入库',
    permissions: [PERMISSIONS.purchaseInboundList],
    available: false,
  },
  'production-picking': {
    key: 'production-picking',
    title: '生产领料',
    permissions: [PERMISSIONS.productionPickingList],
    available: false,
  },
  'production-inbound': {
    key: 'production-inbound',
    title: '成品入库',
    permissions: [PERMISSIONS.finishedWarehousingList],
    available: false,
  },
  'sales-outbound': {
    key: 'sales-outbound',
    title: '销售出库',
    permissions: [PERMISSIONS.salesDeliveryList],
    available: false,
  },
  'production-order': {
    key: 'production-order',
    title: '生产订单',
    permissions: [PERMISSIONS.productionOrderList],
    available: false,
  },
  'sales-order': {
    key: 'sales-order',
    title: '销售订单',
    permissions: [PERMISSIONS.salesOrderList],
    available: false,
  },
};
