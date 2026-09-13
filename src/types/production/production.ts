import type { PageResult } from '@/types/common/pagination';
import type { EntityId } from '@/types/common/entity';

export type ProductionOrderStatus = 0 | 1 | 2 | 3 | 4;
export type ProductionPickingStatus = 0 | 1 | 2 | 3;
export type ProductionReportStatus = 0 | 1 | 2 | 3 | 4;

export interface ProductionOrderQuery {
  pageNum: number;
  pageSize: number;
  productionOrderNo?: string;
  productionDemandNo?: string;
  materialId?: EntityId;
  status?: ProductionOrderStatus;
  plannedStartTime?: string;
  plannedEndTime?: string;
  actualStartTime?: string;
  actualEndTime?: string;
}

export interface ProductionOrder {
  id: EntityId;
  productionDemandId: EntityId;
  productionDemandNo: string;
  materialId: EntityId;
  materialCode: string;
  materialName: string;
  plannedQuantity: number;
  completedQuantity: number;
  plannedStartTime: string;
  plannedEndTime: string;
  actualStartTime?: string | null;
  actualEndTime?: string | null;
  remark?: string;
  productionOrderNo: string;
  status: ProductionOrderStatus;
}

export type PageProductionOrder = PageResult<ProductionOrder>;

export interface CreateProductionOrder {
  productionDemandId: EntityId;
  materialId: EntityId;
  plannedQuantity: number;
  plannedStartTime: string;
  plannedEndTime: string;
  remark?: string;
}

export interface MaterialRequirement {
  materialId: EntityId;
  materialCode: string;
  materialName: string;
  grossQuantity: number;
  stockUsedAvailableQuantity: number;
  shortageQuantity: number;
}

export interface ProductionPickingQuery {
  pageNum: number;
  pageSize: number;
  productionOrderId?: EntityId;
  purchaseDemandId?: EntityId;
  materialId?: EntityId;
  warehouseId?: EntityId;
  status?: ProductionPickingStatus;
  pickingTimeStart?: string;
  pickingTimeEnd?: string;
}

export interface ProductionPicking {
  id: EntityId;
  pickingNo: string;
  productionOrderId: EntityId;
  productionOrderNo: string;
  purchaseDemandId?: EntityId | null;
  purchaseDemandNo?: string | null;
  materialId: EntityId;
  materialCode: string;
  materialName: string;
  warehouseId?: EntityId | null;
  warehouseName?: string | null;
  plannedQuantity: number;
  actualQuantity: number;
  status: ProductionPickingStatus;
  pickingTime?: string | null;
  createTime?: string | null;
  updateTime?: string | null;
}

export type PageProductionPicking = PageResult<ProductionPicking>;

export interface ProductionReportQuery {
  pageNum: number;
  pageSize: number;
  productionOrderId?: EntityId;
  productionReportNo?: string;
  materialId?: EntityId;
  reportUserId?: EntityId;
  reportTime?: string;
  status?: ProductionReportStatus;
}

export interface ProductionReport {
  id: EntityId;
  productionReportNo: string;
  productionOrderId: EntityId;
  productionOrderNo?: string;
  materialId: EntityId;
  warehouseId: EntityId;
  warehouseName?: string;
  materialCode?: string;
  materialName?: string;
  reportUserId?: EntityId;
  reportUserName?: string;
  reportTime?: string;
  reportQuantity: number;
  qualifiedQuantity: number;
  scrappedQuantity: number;
  status: ProductionReportStatus;
  remark?: string;
}

export type PageProductionReport = PageResult<ProductionReport>;

export interface CreateProductionReport {
  productionOrderId: EntityId;
  materialId: EntityId;
  warehouseId: EntityId;
  reportQuantity: number;
  qualifiedQuantity: number;
  scrappedQuantity: number;
  reportTime?: string;
  remark?: string;
}
