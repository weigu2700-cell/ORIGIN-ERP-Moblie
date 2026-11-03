export interface LoginRequest {
  tenantCode?: string;
  username: string;
  password: string;
}

export interface LoginResponse {
  token: string;
}

export interface Organization { code: string; name: string }
export interface TenantConfiguration { mode: 'single' | 'multi'; organization: Organization | null }
export interface TenantSession {
  tenantId: string
  organization: Organization
  businessAvailable: boolean
  user: { id: string; username: string; realName: string; phone?: string }
}
