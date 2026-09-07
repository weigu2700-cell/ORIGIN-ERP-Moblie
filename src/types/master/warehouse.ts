import type { PageResult } from "@/types/common/pagination";

export interface Warehouse {
  id: number;
  name: string;
  code: string;
  type?: string;
  factoryId?: number;
  factoryName?: string;
  status: number;
}

export type WarehousePage = PageResult<Warehouse>;
