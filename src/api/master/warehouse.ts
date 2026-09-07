import { get } from "@/utils/request";
import type { WarehousePage } from "@/types/master/warehouse";

export function getEnabledWarehouses() {
  return get<WarehousePage>("/master/warehouse", {
    page: 1,
    pageSize: 100,
    status: "ENABLE",
  }, { showError: false });
}
