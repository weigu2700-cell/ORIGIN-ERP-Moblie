export interface SalesOrderItem {
    id: string
    lineNo: number
    salesOrderId: string
    materialId: string
    materialCode: string
    materialName: string
    warehouseId: string
    warehouseName: string
    quantity: number
    unitPrice: number
    amount: number
}

export interface SalesOrder {
    id: string
    orderNo: string
    customerId: string
    customerName: string
    orderDate: string
    deliveryDate: string
    totalAmount: number
    remark: string
    status: string
}

export interface PageSalesOrder {
    records: SalesOrder[]
    total: number
    size: number
    current: number
    optimizeCountSql: string
    searchCount: string
}

export interface CreateSalesOrder {
    customerId: string
    orderDate: string
    deliveryDate: string
    remark: string
}

export interface CreateSalesOrderItem {
    materialId: string
    warehouseId: string
    quantity: number
    unitPrice: number
}

export interface SalesOrderQuery {

    pageNum: number
    pageSize: number
    customerId?: string
    orderNo?: string
    orderDate?: string
    status?: string
}

