import { get } from '@/utils/request';
import type { WarehousePage } from '@/types/master/warehouse';
import { WAREHOUSE_STATUS } from '@/constants/domain-enums';

export function getEnabledWarehouses(page = 1) {
  return get<WarehousePage>(
    '/master/warehouse',
    {
      page,
      pageSize: 100,
      status: WAREHOUSE_STATUS.ENABLED,
    },
    { showError: false },
  );
}
