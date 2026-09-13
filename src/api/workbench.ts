import { get } from '@/utils/request';
import type { PageResult } from '@/types/common/pagination';
import type { PurchaseInStock } from '@/types/purchase/purchase-in-stock';
import type { ProductionOrder, ProductionPicking } from '@/types/production/production';
import type { SalesDelivery } from '@/types/sales/sales';
import {
  PRODUCTION_ORDER_STATUS,
  PRODUCTION_PICKING_STATUS,
  PURCHASE_IN_STOCK_STATUS,
  SALES_DELIVERY_STATUS,
} from '@/constants/domain-enums';

function getPageTotal<T>(url: string, query: Record<string, unknown>) {
  return get<PageResult<T>>(
    url,
    {
      pageNum: 1,
      pageSize: 1,
      ...query,
    },
    { showError: false },
  ).then((page) => page.total);
}

export const workbenchApi = {
  // 已审核、尚未上架的采购入库单。
  getPurchaseInboundPending: () =>
    getPageTotal<PurchaseInStock>('/purchase/in/stock', {
      status: PURCHASE_IN_STOCK_STATUS.APPROVED,
    }),
  // 已审批、尚未确认领料的领料单。
  getProductionPickingPending: () =>
    getPageTotal<ProductionPicking>('/prd/picking', {
      status: PRODUCTION_PICKING_STATUS.APPROVED,
    }),
  // 已确认、尚未完成出库的销售出库单。
  getSalesOutboundPending: () =>
    getPageTotal<SalesDelivery>('/sales/delivery', {
      status: SALES_DELIVERY_STATUS.CONFIRMED,
    }),
  getProductionInProgress: () =>
    getPageTotal<ProductionOrder>('/prd/order', {
      status: PRODUCTION_ORDER_STATUS.IN_PROGRESS,
    }),
};
