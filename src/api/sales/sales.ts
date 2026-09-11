import {get,post,put}  from '@/utils/request'
import type {CreateSalesOrder, CreateSalesOrderItem, PageSalesOrder, SalesOrder, SalesOrderQuery,} from '@/types/sales/sales'

export function getPageSalesOrder (data:SalesOrderQuery) {
    return get<PageSalesOrder>(
        '/sales/order',
        {params:data}
    )
}

export function getDetailSalesOrder (id:string) {
    return get<SalesOrder>(
        `/sales/order/${id}`
    )
}

export function createSalesOrder (data:CreateSalesOrder) {
    return post<SalesOrder>(
        '/sales/order',
        data
    )
}

export function updateSalesOrder (id:string, data:CreateSalesOrder) {
    return put<SalesOrder>(
        `/sales/order/${id}`,
        data
    )
}

export function confirmSalesOrder (id:string) {
    return put<void>(
        `/sales/order/${id}/confirm`
    )
}

export function cancelSalesOrder (id:string) {
    return put<void>(
        `/sales/order/${id}/cancel`
    )
}
