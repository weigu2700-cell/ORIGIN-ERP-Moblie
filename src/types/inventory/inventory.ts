export interface InventoryVo {
    id: string
    materialId: string
    materialName: string
    materialCode: string
    warehouseId: number,
    warehouseName: string,
    onHand: number,
    reserved: number,
    available: number
}

export interface PageInventoryVo {
    records :InventoryVo[]
    total: number,
    size: number,
    current: number,
    optimizeCountSql: string,
    searchCount: string
}

export interface InventoryQuery {
    pageNum: number,
    pageSize: number,
    keyword?: string,
    materialCode?: string,
    materialName?: string,
    warehouseId?: number
}

export interface InventoryItem {
 
      "salesOrderItemId": 0,
      "quantity": 1
    
}

export interface CreateInventory {
    "salesOrderId": 0,
  "deliveryDate": "2026-09-08T06:56:24.156Z",
  "items": InventoryItem[]
  "remark": "string"
}