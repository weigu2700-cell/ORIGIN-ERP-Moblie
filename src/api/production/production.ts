import { get, post, put } from '@/utils/request';
import type {
  CreateProductionOrder,
  CreateProductionReport,
  MaterialRequirement,
  PageProductionOrder,
  PageProductionPicking,
  PageProductionReport,
  ProductionOrder,
  ProductionOrderQuery,
  ProductionPicking,
  ProductionPickingQuery,
  ProductionReport,
  ProductionReportQuery,
} from '@/types/production/production';

export function getPageProductionOrder(data: ProductionOrderQuery) {
  return get<PageProductionOrder>('/prd/order', { ...data });
}

export function getDetailProductionOrder(id: string) {
  return get<ProductionOrder>(`/prd/order/${id}`);
}

export function createProductionOrder(data: CreateProductionOrder) {
  return post<void>('/prd/order', data);
}

export function beginProductionOrder(id: string) {
  return put<void>(`/prd/order/${id}/start`);
}

export function releaseProductionOrder(id: string) {
  return put<MaterialRequirement[]>(`/prd/order/${id}/release`);
}

export function completeProductionOrder(id: string) {
  return put<void>(`/prd/order/${id}/complete`);
}

export function cancelProductionOrder(id: string) {
  return put<void>(`/prd/order/${id}/cancel`);
}

/** @deprecated 请使用 cancelProductionOrder。 */
export const cancelProduntionOrder = cancelProductionOrder;

export function getPageProductionPicking(data: ProductionPickingQuery) {
  return get<PageProductionPicking>('/prd/picking', { ...data });
}

export function approveProductionPicking(id: string) {
  return put<void>(`/prd/picking/${id}/approve`);
}

export function confirmProductionPicking(id: string) {
  return post<void>('/prd/picking/confirm', undefined, { query: { id } });
}

export function getDetailProductionPicking(id: string) {
  return get<ProductionPicking>(`/prd/picking/${id}`);
}

export function getPageProductionReport(data: ProductionReportQuery) {
  return get<PageProductionReport>('/prd/report', { ...data });
}

export function getDetailProductionReport(id: string) {
  return get<ProductionReport>(`/prd/report/${id}`);
}

export function createProductionReport(data: CreateProductionReport) {
  return post<void>('/prd/report', data);
}

export function approveProductionReport(id: string) {
  return put<void>(`/prd/report/${id}/approve`);
}

export function cancelProductionReport(id: string) {
  return put<void>(`/prd/report/${id}/cancel`);
}

export function rejectProductionReport(id: string) {
  return put<void>(`/prd/report/${id}/reject`);
}

export function finishProductionReport(id: string) {
  return put<void>(`/prd/report/${id}/finish`);
}