import { get, put } from '@/utils/request';
import type {
  PagePurchaseInStock,
  PurchaseInStock,
  PurchaseInStockQuery,
  PurchaseInStockUpload,
} from '@/types/purchase/purchase-in-stock';

export function getPagePurchaseInStock(data: PurchaseInStockQuery) {
  return get<PagePurchaseInStock>('/purchase/in/stock', { ...data });
}

export function getDetailPurchaseInStock(id: string) {
  return get<PurchaseInStock>(`/purchase/in/stock/${id}`);
}

export function approvePurchaseInStock(id: string) {
  return put<void>(`/purchase/in/stock/${id}/approve`);
}

export function uploadPurchaseInStock(id: string, data: PurchaseInStockUpload) {
  return put<void>(`/purchase/in/stock/${id}/upload`, data);
}
