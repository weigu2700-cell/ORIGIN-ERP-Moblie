import { get, post } from '@/utils/request';
import type { LoginRequest, LoginResponse } from '@/types/system/auth';

export function login(data: LoginRequest) {
  return post<LoginResponse>('/auth/login', data, {
    auth: false,
    showError: false,
  });
}

import type { Organization, TenantConfiguration, TenantSession } from '@/types/system/auth';
export const getTenantConfiguration = () => get<TenantConfiguration>('/auth/tenant/context', undefined, { auth: false, showError: false });
export const resolveOrganization = (tenantCode: string) => post<Organization>('/auth/tenant/resolve', { tenantCode }, { auth: false, showError: false });
export const getTenantSession = () => get<TenantSession>('/auth/tenant/session', undefined, { showError: false });
