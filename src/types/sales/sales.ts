import type { PageResult } from '@/types/common/pagination';
import type { EntityId } from '@/types/common/entity';

export type SalesOrderStatus = 0 | 1 | 2 | 3;
export type SalesDeliveryStatus = 0 | 1 | 2 | 3;

export interface SalesOrderItem {
  id: EntityId;
  lineNo: number;
  salesOrderId: EntityId;
  materialId: EntityId;
  materialCode: string;
  materialName: string;
  warehouseId: EntityId;
  warehouseName: string;
  quantity: number;
  unitPrice: number;
  amount: number;
  deliveredQuantity: number;
}

export interface SalesOrder {
  id: EntityId;
  orderNo: string;
  customerId: EntityId;
  customerName: string;
  orderDate: string;
  deliveryDate: string;
  totalAmount: number;
  remark: string;
  status: SalesOrderStatus;
  items: SalesOrderItem[];
}

export type PageSalesOrder = PageResult<SalesOrder>;

export interface CreateSalesOrderItem {
  materialId: EntityId;
  warehouseId: EntityId;
  quantity: number;
  unitPrice: number;
}

export interface CreateSalesOrder {
  customerId: EntityId;
  orderDate: string;
  deliveryDate: string;
  remark?: string;
  items: CreateSalesOrderItem[];
}

export interface UpdateSalesOrderItem extends CreateSalesOrderItem {
  id?: EntityId;
}

export interface UpdateSalesOrder {
  orderDate?: string;
  deliveryDate?: string;
  remark?: string;
  status?: SalesOrderStatus;
  items?: UpdateSalesOrderItem[];
}

export interface SalesOrderQuery {
  pageNum: number;
  pageSize: number;
  customerId?: EntityId;
  orderNo?: string;
  orderDate?: string;
  status?: SalesOrderStatus;
}

export interface SalesDeliveryItem {
  id: EntityId;
  deliveryId: EntityId;
  lineNo: number;
  salesOrderItemId: EntityId;
  materialId: EntityId;
  materialName: string;
  materialCode: string;
  warehouseId: EntityId;
  warehouseName: string;
  quantity: number;
  reservedQuantity: number;
}

export interface SalesDelivery {
  id: EntityId;
  deliveryNo: string;
  salesOrderId: EntityId;
  salesOrderNo: string;
  customerId: EntityId;
  customerName: string;
  deliveryDate: string;
  status: SalesDeliveryStatus;
  items: SalesDeliveryItem[];
  remark: string;
}

export type PageSalesDelivery = PageResult<SalesDelivery>;

export interface SalesDeliveryQuery {
  pageNum: number;
  pageSize: number;
  deliveryNo?: string;
  salesOrderId?: EntityId;
  customerId?: EntityId;
  status?: SalesDeliveryStatus;
}

export interface CreateSalesDeliveryItem {
  salesOrderItemId: EntityId;
  quantity: number;
}

export interface CreateSalesDelivery {
  salesOrderId: EntityId;
  deliveryDate: string;
  items: CreateSalesDeliveryItem[];
  remark?: string;
}
