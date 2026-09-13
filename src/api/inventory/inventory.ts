import type {
  CreateInventory as CreateInventoryPayload,
  InventoryQuery,
  InventoryVo,
  PageInventoryVo,
} from '@/types/inventory/inventory';
import { get, post } from '@/utils/request';

export function getDetailInventory(id: string) {
  return get<InventoryVo>(`/inventory/material-stock/${id}`);
}

export function getPageInventory(data: InventoryQuery) {
  const { keyword, ...query } = data;
  return get<PageInventoryVo>('/inventory/material-stock', {
    ...query,
    materialCode: query.materialCode || keyword,
  });
}

export function createInventory(data: CreateInventoryPayload) {
  return post<InventoryVo>('/inventory/material-stock', data);
}

/** @deprecated 请使用 createInventory。 */
export const CreateInventory = createInventory;
