import type { PageResult } from '@/types/common/pagination';

export type WarehousingStatus = 0 | 1 | 2 | 3;
export interface FinishWarehousing {
  id: string;
  warehousingNo: string;
  productionOrderId: string;
  productionReportId: string;
  productionOrderNo?: string;
  productionReportNo?: string;
  materialName?: string;
  materialCode?: string;
  warehouseId: string;
  warehouseName?: string;
  warehousingQuantity: number;
  warehousingUserName?: string;
  warehousingTime?: string;
  status: WarehousingStatus;
  remark?: string;
}
export interface WarehousingQuery {
  pageNum: number;
  pageSize: number;
  warehousingNo?: string;
  warehouseId?: string;
  productionOrderId?: string;
  // Spring 对此枚举按名称绑定；响应仍为数字码。
  status?: 'DRAFT' | 'APPROVED' | 'WAREHOUSED' | 'CANCEL';
}
export type WarehousingPage = PageResult<FinishWarehousing>;
