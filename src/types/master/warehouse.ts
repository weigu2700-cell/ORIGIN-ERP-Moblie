import type { PageResult } from '@/types/common/pagination';
import type { EntityId } from '@/types/common/entity';

export interface Warehouse {
  id: EntityId;
  name: string;
  code: string;
  type?: number;
  address?: string;
  remark?: string;
  factoryId?: EntityId;
  factoryName?: string;
  status: number;
}

export type WarehousePage = PageResult<Warehouse>;
