import { PERMISSION_CODES } from '@/core/auth/permission-registry';

/** @deprecated 请改用 core/auth 中的 PERMISSION_CODES。 */
export const PERMISSIONS = PERMISSION_CODES;

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