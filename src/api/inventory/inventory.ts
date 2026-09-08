import type { CreateInventory, InventoryQuery, InventoryVo, PageInventoryVo } from "@/types/inventory/inventory";
import {get, post} from "@/utils/request";

export function getDetailInventory (id:string) {
    return get<InventoryVo>(
        `/inventory/material-stock/${id}`
    )
}

export function getPageInventory (data:InventoryQuery) {
    return get<PageInventoryVo>(
        `/inventory/material-stock`,
        {...data}
    )
}

export function CreateInventory(data:CreateInventory){
    return post<void>(
        `/inventory/material-stock`,
        data
    )

}