import { del, get, post, put } from '@/utils/request';
import type {
  CreateSalesDelivery,
  CreateSalesOrder,
  PageSalesDelivery,
  PageSalesOrder,
  SalesDelivery,
  SalesDeliveryQuery,
  SalesOrder,
  SalesOrderQuery,
  UpdateSalesOrder,
} from '@/types/sales/sales';

export function getPageSalesOrder(data: SalesOrderQuery) {
  return get<PageSalesOrder>('/sales/order', { ...data });
}

export function getDetailSalesOrder(id: string) {
  return get<SalesOrder>(`/sales/order/${id}`);
}

export function createSalesOrder(data: CreateSalesOrder) {
  return post<SalesOrder>('/sales/order', data);
}

export function updateSalesOrder(id: string, data: UpdateSalesOrder) {
  return put<SalesOrder>(`/sales/order/${id}`, data);
}

export function deleteSalesOrder(id: string) {
  return del<void>(`/sales/order/${id}`);
}

export function confirmSalesOrder(id: string, data?: UpdateSalesOrder) {
  return put<SalesOrder>(`/sales/order/${id}/confirm`, data);
}

export function cancelSalesOrder(id: string, data?: UpdateSalesOrder) {
  return put<SalesOrder>(`/sales/order/${id}/cancel`, data);
}

export function getPageSalesDelivery(data: SalesDeliveryQuery) {
  return get<PageSalesDelivery>('/sales/delivery', { ...data });
}

export function getDetailSalesDelivery(id: string) {
  return get<SalesDelivery>(`/sales/delivery/${id}`);
}

export function createSalesDelivery(data: CreateSalesDelivery) {
  return post<SalesDelivery>('/sales/delivery', data);
}

export function confirmSalesDelivery(id: string) {
  return put<SalesDelivery>(`/sales/delivery/${id}/confirm`);
}

export function completeSalesDelivery(id: string) {
  return put<SalesDelivery>(`/sales/delivery/${id}/complete`);
}

export function cancelSalesDelivery(id: string) {
  return put<SalesDelivery>(`/sales/delivery/${id}/cancel`);
}
