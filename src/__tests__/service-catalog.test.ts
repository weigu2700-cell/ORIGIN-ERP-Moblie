import { describe, expect, it } from 'vitest';
import { FEATURE_CAPABILITIES } from '@/constants/capabilities';
import { SERVICE_CATALOG, SERVICE_CATEGORIES } from '@/constants/service-catalog';
import { PERMISSION_CODES } from '@/core/auth/permission-registry';

describe('service catalog', () => {
  it('uses unique stable service codes', () => {
    const codes = SERVICE_CATALOG.map((item) => item.code);
    expect(new Set(codes).size).toBe(codes.length);
  });

  it('assigns every service to a registered category', () => {
    const categories = new Set(SERVICE_CATEGORIES.map((item) => item.code));
    SERVICE_CATALOG.forEach((item) => expect(categories.has(item.categoryCode)).toBe(true));
  });

  it('uses only registered backend permission codes', () => {
    const permissions = new Set<string>(Object.values(PERMISSION_CODES));
    SERVICE_CATALOG.flatMap((item) => item.permissions).forEach((permission) => {
      expect(permissions.has(permission)).toBe(true);
    });
  });

  it('gives every available routed service a real route', () => {
    SERVICE_CATALOG.filter((item) => item.available && item.code !== 'scan').forEach((item) => {
      expect(item.route).toMatch(/^\/apps\//);
    });
  });

  it('derives workbench capabilities from the available catalog entries', () => {
    const availableCodes = SERVICE_CATALOG.filter((item) => item.available).map(
      (item) => item.code,
    );
    expect(Object.keys(FEATURE_CAPABILITIES).sort()).toEqual([...availableCodes].sort());
  });
});
