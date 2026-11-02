import { get, put } from '@/utils/request';
import type {
  FinishWarehousing,
  WarehousingPage,
  WarehousingQuery,
} from '@/types/production/warehousing';

const endpoint = '/inv/finish-warehousing';
export const getPageFinishWarehousing = (query: WarehousingQuery) =>
  get<WarehousingPage>(endpoint, { ...query });
export const getDetailFinishWarehousing = (id: string) =>
  get<FinishWarehousing>(`${endpoint}/${id}`);
export const approveFinishWarehousing = (id: string) => put<boolean>(`${endpoint}/${id}/approve`);
export const warehouseFinishWarehousing = (id: string) =>
  put<boolean>(`${endpoint}/${id}/warehouse`);
export const cancelFinishWarehousing = (id: string) => put<boolean>(`${endpoint}/${id}/cancel`);
