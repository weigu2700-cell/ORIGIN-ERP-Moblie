import type { PageResult } from '@/types/common/pagination';
import type { EntityId } from '@/types/common/entity';

export type PurchaseInStockType = 0 | 1 | 2;
export type PurchaseInStockStatus = 0 | 1 | 2;

export interface PurchaseInStock {
  id: EntityId;
  purchaseInStockNo: string;
  purchaseOrderId: EntityId;
  purchaseOrderNo: string;
  supplierId: EntityId;
  supplierName: string;
  supplierCode: string;
  materialId: EntityId;
  materialName: string;
  materialCode: string;
  warehouseId?: EntityId | null;
  warehouseName?: string | null;
  warehouseCode?: string | null;
  storageLocation?: string | null;
  batchNo?: string | null;
  inType: PurchaseInStockType;
  status: PurchaseInStockStatus;
  remark?: string | null;
  inQuantity: number;
  unitPrice: number;
  totalAmount: number;
  productionDate?: string | null;
  deliveryDate?: string | null;
  expiryDate?: string | null;
  operator?: string | null;
  inDate?: string | null;
  createTime?: string | null;
  updateTime?: string | null;
}

export type PagePurchaseInStock = PageResult<PurchaseInStock>;

export interface PurchaseInStockQuery {
  pageNum: number;
  pageSize: number;
  purchaseInStockNo?: string;
  purchaseOrderNo?: string;
  materialId?: EntityId;
  supplierId?: EntityId;
  warehouseId?: EntityId;
  storageLocation?: string;
  operator?: string;
  inType?: PurchaseInStockType;
  status?: PurchaseInStockStatus;
  productionDate?: string;
  deliveryDate?: string;
}

export interface PurchaseInStockUpload {
  warehouseId?: EntityId;
  storageLocation: string;
  batchNo?: string;
  productionDate?: string;
  expiryDate?: string;
}
