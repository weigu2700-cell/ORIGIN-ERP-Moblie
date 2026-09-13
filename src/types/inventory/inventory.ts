import type { PageResult } from '@/types/common/pagination';
import type { EntityId } from '@/types/common/entity';

export interface InventoryVo {
  id: EntityId;
  materialId: EntityId;
  materialName: string;
  materialCode: string;
  warehouseId: EntityId;
  warehouseName: string;
  onHand: number;
  reserved: number;
  available: number;
}

export type PageInventoryVo = PageResult<InventoryVo>;

/** 对应 MaterialStockPageDto。 */
export interface InventoryQuery {
  pageNum: number;
  pageSize: number;
  materialId?: EntityId;
  warehouseId?: EntityId;
  materialCode?: string;
  /** 兼容现有搜索框；API 层会映射为后端支持的 materialCode。 */
  keyword?: string;
}

/** 对应 MaterialStockAddDto。 */
export interface CreateInventory {
  materialId: EntityId;
  warehouseId: EntityId;
}
