import { get } from "@/utils/request";
import type { PageResult } from "@/types/common/pagination";

interface UnknownRecord {
  id: number;
}

function getProductionOrderCount(status: "RELEASED" | "IN_PROGRESS") {
  return get<PageResult<UnknownRecord>>("/production/order", {
    pageNum: 1,
    pageSize: 1,
    status,
  }, { showError: false }).then((page) => page.total);
}

function getSalesDeliveryCount(status: "CONFIRMED") {
  return get<PageResult<UnknownRecord>>("/sales/delivery", {
    pageNum: 1,
    pageSize: 1,
    status,
  }, { showError: false }).then((page) => page.total);
}

export const workbenchApi = {
  getProductionPickingPending: () => getProductionOrderCount("RELEASED"),
  getProductionInProgress: () => getProductionOrderCount("IN_PROGRESS"),
  getSalesOutboundPending: () => getSalesDeliveryCount("CONFIRMED"),
};
