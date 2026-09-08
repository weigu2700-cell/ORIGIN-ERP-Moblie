/** 生产订单分页查询条件 */
export interface PageProductionOrder {
  records: ProductionOrder[]
  total: number
  size: number
  current: number
  optimizeCountSql?: string
  searchCount?: string
}



export interface ProductionOrderQuery {
  pageNum: number;
  pageSize: number;
  productionOrderNo: string;
  productionDemandNo: string;
  materialId: string;
  status: string;
  plannedStartTime: string;
  plannedEndTime: string;
  actualStartTime: string;
  actualEndTime: string;
}

/** 生产订单 */
export interface ProductionOrder {
  id: string;
  productionDemandId: string;
  productionDemandNo: string;
  materialId: string;
  materialCode: string;
  materialName: string;
  plannedQuantity: number;
  completedQuantity: number;
  plannedStartTime: string;
  plannedEndTime: string;
  actualStartTime: string;
  actualEndTime: string;
  remark: string;
  productionOrderNo: string;
  status: number;
}

/** 新增生产订单入参 */
export interface CreateProductionOrder {
  productionDemandId?: string;
  materialId: string;
  plannedQuantity: number;
  plannedStartTime: string;
  plannedEndTime: string;
  remark: string;
}
