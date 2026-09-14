import { SERVICE_CATALOG } from './service-catalog';

/** @deprecated 请改用 core/auth 中的 PERMISSION_CODES。 */
export { PERMISSION_CODES as PERMISSIONS } from '@/core/auth/permission-registry';

export type FeatureKey =
  | 'scan'
  | 'stock'
  | 'purchase-inbound'
  | 'production-picking'
  | 'production-inbound'
  | 'sales-outbound'
  | 'production-order'
  | 'sales-order';

export interface FeatureCapability {
  key: FeatureKey;
  title: string;
  permissions: string[];
  route?: string;
  available: boolean;
}

export const FEATURE_CAPABILITIES = Object.fromEntries(
  SERVICE_CATALOG.filter((item) => item.available).map((item) => [
    item.code,
    {
      key: item.code,
      title: item.title,
      permissions: [...item.permissions],
      route: item.route,
      available: item.available,
    },
  ]),
) as Record<FeatureKey, FeatureCapability>;
