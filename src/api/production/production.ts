import {get,post,put}  from '@/utils/request'
import type {CreateProductionOrder, PageProductionOrder, ProductionOrder, ProductionOrderQuery,} from '@/types/production/production'

export function getPageProductionOrder(data:ProductionOrderQuery) {
    return get<PageProductionOrder>(
        '/production/order',
        {params:data}
    )
  
}

export function getDetailProductionOrder(id:string) {
    return get<ProductionOrder>(
        `/production/order/${id}`
    )
}

export function createProductionOrder(data:CreateProductionOrder) {
    return post<ProductionOrder>(
        '/production/order',
        data
    )
}

export function beginProductionOrder(id:string){
    return put<void>(
        `/production/order/${id}/start`
    )
}

export function releaseProductionOrder(id:string){
    return put<void>(
        `/production/order/${id}/release`
    )
}


export function completeProductionOrder(id:string){
    return put<void>(
        `/production/order/${id}/complete`
    )
}

export function cancelProduntionOrder(id:string){
    return put<void>(
        `/production/order/${id}/cancel`
    )
}
