import type { WarehouseStatus } from '@/types/master/warehouse';
import type {
  ProductionOrderStatus,
  ProductionPickingStatus,
  ProductionReportStatus,
} from '@/types/production/production';
import type {
  PurchaseInStockStatus,
  PurchaseInStockType,
} from '@/types/purchase/purchase-in-stock';
import type { SalesDeliveryStatus, SalesOrderStatus } from '@/types/sales/sales';

/** API 枚举只交换 code；对象 key 和中文 label 仅供客户端逻辑及展示。 */
export const WAREHOUSE_STATUS = {
  DISABLED: 0,
  ENABLED: 1,
} as const satisfies Record<string, WarehouseStatus>;

export const PURCHASE_IN_STOCK_TYPE = {
  NORMAL: 0,
  RETURN: 1,
  GIFT: 2,
} as const satisfies Record<string, PurchaseInStockType>;

export const PURCHASE_IN_STOCK_STATUS = {
  DRAFT: 0,
  APPROVED: 1,
  UPLOADED: 2,
} as const satisfies Record<string, PurchaseInStockStatus>;

export const PRODUCTION_ORDER_STATUS = {
  DRAFT: 0,
  RELEASED: 1,
  IN_PROGRESS: 2,
  COMPLETED: 3,
  CANCELLED: 4,
} as const satisfies Record<string, ProductionOrderStatus>;

export const PRODUCTION_PICKING_STATUS = {
  DRAFT: 0,
  APPROVED: 1,
  PICKED: 2,
  CANCELLED: 3,
} as const satisfies Record<string, ProductionPickingStatus>;

export const PRODUCTION_REPORT_STATUS = {
  DRAFT: 0,
  APPROVED: 1,
  CANCELLED: 2,
  REJECTED: 3,
  FINISHED: 4,
} as const satisfies Record<string, ProductionReportStatus>;

export const SALES_ORDER_STATUS = {
  DRAFT: 0,
  CONFIRMED: 1,
  COMPLETED: 2,
  CANCELLED: 3,
} as const satisfies Record<string, SalesOrderStatus>;

export const SALES_DELIVERY_STATUS = {
  DRAFT: 0,
  CONFIRMED: 1,
  CANCELLED: 2,
  COMPLETED: 3,
} as const satisfies Record<string, SalesDeliveryStatus>;

export const PURCHASE_IN_STOCK_STATUS_LABEL: Record<PurchaseInStockStatus, string> = {
  [PURCHASE_IN_STOCK_STATUS.DRAFT]: '草稿',
  [PURCHASE_IN_STOCK_STATUS.APPROVED]: '已审核',
  [PURCHASE_IN_STOCK_STATUS.UPLOADED]: '已上架',
};

export const PURCHASE_IN_STOCK_TYPE_LABEL: Record<PurchaseInStockType, string> = {
  [PURCHASE_IN_STOCK_TYPE.NORMAL]: '采购入库',
  [PURCHASE_IN_STOCK_TYPE.RETURN]: '采购退货',
  [PURCHASE_IN_STOCK_TYPE.GIFT]: '赠品入库',
};

export const PRODUCTION_PICKING_STATUS_LABEL: Record<ProductionPickingStatus, string> = {
  [PRODUCTION_PICKING_STATUS.DRAFT]: '草稿',
  [PRODUCTION_PICKING_STATUS.APPROVED]: '已审批',
  [PRODUCTION_PICKING_STATUS.PICKED]: '已领料',
  [PRODUCTION_PICKING_STATUS.CANCELLED]: '已取消',
};

export const PRODUCTION_ORDER_STATUS_LABEL: Record<ProductionOrderStatus, string> = {
  [PRODUCTION_ORDER_STATUS.DRAFT]: '草稿',
  [PRODUCTION_ORDER_STATUS.RELEASED]: '已下达',
  [PRODUCTION_ORDER_STATUS.IN_PROGRESS]: '生产中',
  [PRODUCTION_ORDER_STATUS.COMPLETED]: '已完成',
  [PRODUCTION_ORDER_STATUS.CANCELLED]: '已取消',
};

export const PRODUCTION_REPORT_STATUS_LABEL: Record<ProductionReportStatus, string> = {
  [PRODUCTION_REPORT_STATUS.DRAFT]: '草稿',
  [PRODUCTION_REPORT_STATUS.APPROVED]: '已审批',
  [PRODUCTION_REPORT_STATUS.CANCELLED]: '已取消',
  [PRODUCTION_REPORT_STATUS.REJECTED]: '已驳回',
  [PRODUCTION_REPORT_STATUS.FINISHED]: '已完成',
};

export const SALES_ORDER_STATUS_LABEL: Record<SalesOrderStatus, string> = {
  [SALES_ORDER_STATUS.DRAFT]: '草稿',
  [SALES_ORDER_STATUS.CONFIRMED]: '已确认',
  [SALES_ORDER_STATUS.COMPLETED]: '已完成',
  [SALES_ORDER_STATUS.CANCELLED]: '已取消',
};

export const SALES_DELIVERY_STATUS_LABEL: Record<SalesDeliveryStatus, string> = {
  [SALES_DELIVERY_STATUS.DRAFT]: '草稿',
  [SALES_DELIVERY_STATUS.CONFIRMED]: '已确认',
  [SALES_DELIVERY_STATUS.CANCELLED]: '已取消',
  [SALES_DELIVERY_STATUS.COMPLETED]: '已完成',
};
