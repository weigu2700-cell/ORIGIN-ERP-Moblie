import { computed, ref, onScopeDispose } from 'vue';
import { defineStore } from 'pinia';
import { login, getTenantSession } from '@/api/system/auth';
import { getCurrentUser, getCurrentUserPermissions } from '@/api/system/user';
import { STORAGE_KEYS } from '@/constants/storage';
import type { LoginRequest, Organization } from '@/types/system/auth';
import type { CurrentUser } from '@/types/system/user';
import { getToken, removeToken, setToken, captureSession, assertSession, isSessionCurrent, onSessionChange, SessionChangedError, refreshSessionBoundary } from '@/utils/auth';
import { useOrganizationStore } from '@/stores/organization';
export type SessionStatus = 'unknown' | 'restoring' | 'authenticated' | 'anonymous' | 'error';
export type PermissionStatus = 'idle' | 'loading' | 'ready' | 'error';
export const useUserStore = defineStore('user', () => {
  const token = ref(getToken());
  const profile = ref<CurrentUser | null>(null);
  const permissions = ref<string[]>([]);
  const organization = ref<Organization | null>(null);
  const businessAvailable = ref(true);
  const sessionStatus = ref<SessionStatus>(token.value ? 'unknown' : 'anonymous');
  const permissionsStatus = ref<PermissionStatus>('idle');
  const contextError = ref('');
  const organizations = useOrganizationStore();
  const hasToken = computed(() => Boolean(token.value));
  const isLoggedIn = computed(() => sessionStatus.value === 'authenticated');
  const displayName = computed(() => profile.value?.realName || profile.value?.username || '用户');
  const primaryRole = computed(() => profile.value?.roles?.[0]?.roleName || '组织成员');
  function reset() {
    token.value = getToken(); profile.value = null; permissions.value = []; organization.value = null;
    businessAvailable.value = true;
    sessionStatus.value = token.value ? 'unknown' : 'anonymous'; permissionsStatus.value = 'idle'; contextError.value = '';
    uni.removeStorageSync(STORAGE_KEYS.currentWarehouse); uni.removeStorageSync(STORAGE_KEYS.currentWarehouseId);
  }
  onScopeDispose(onSessionChange(reset));
  function restoreSession() { if (token.value !== getToken()) refreshSessionBoundary(); }
  async function loadUserContext() {
    const snapshot = captureSession();
    const session = await getTenantSession(); assertSession(snapshot);
    let nextProfile: CurrentUser = { ...session.user, roles: [] };
    let nextPermissions: string[] = [];
    let permissionError = '';
    if (session.businessAvailable) {
      nextProfile = await getCurrentUser(); assertSession(snapshot);
      try { nextPermissions = (await getCurrentUserPermissions()).map(item => item.code).filter(Boolean); }
      catch (failure) { assertSession(snapshot); permissionError = failure instanceof Error ? failure.message : '权限加载失败'; }
    }
    assertSession(snapshot);
    profile.value = nextProfile; permissions.value = nextPermissions; organization.value = session.organization;
    businessAvailable.value = session.businessAvailable; permissionsStatus.value = permissionError ? 'error' : 'ready'; contextError.value = permissionError;
    organizations.remember(session.organization);
  }
  async function loginAction(data: LoginRequest) {
    removeToken(); const snapshot = captureSession();
    const result = await login(data); assertSession(snapshot);
    if (!result.token) throw new Error('登录响应缺少凭据');
    setToken(result.token); const active = captureSession(); sessionStatus.value = 'restoring';
    try { await loadUserContext(); assertSession(active); sessionStatus.value = 'authenticated'; }
    catch (failure) { if (isSessionCurrent(active)) clearSession(); throw failure; }
  }
  async function validateSession(force = false) {
    restoreSession(); if (!token.value) return false;
    if (!force && sessionStatus.value === 'authenticated' && profile.value) return true;
    const snapshot = captureSession(); sessionStatus.value = 'restoring';
    try { await loadUserContext(); assertSession(snapshot); sessionStatus.value = 'authenticated'; return true; }
    catch (failure) {
      if (!isSessionCurrent(snapshot)) throw new SessionChangedError();
      const error = failure as { code?: number; statusCode?: number; kind?: string };
      if (error?.code === 401 || error?.statusCode === 401 || error?.kind === 'unauthorized') { clearSession(); return false; }
      sessionStatus.value = 'error'; contextError.value = failure instanceof Error ? failure.message : '会话验证失败'; throw failure;
    }
  }
  function hasAnyPermission(codes: string[]) {
    if (!businessAvailable.value) return false;
    if (!codes.length) return true;
    const roleCodes = profile.value?.roles?.map(role => role.roleCode?.toUpperCase()) || [];
    return roleCodes.some(code => code === 'ADMIN' || code === 'SUPER_ADMIN') || codes.some(code => permissions.value.includes(code));
  }
  function clearSession() { removeToken(); }
  function logout() { clearSession(); uni.reLaunch({ url: '/pages/login/login' }); }
  return { token, profile, permissions, organization, businessAvailable, sessionStatus, permissionsStatus, contextError, hasToken, isLoggedIn, displayName, primaryRole, restoreSession, validateSession, loadUserContext, hasAnyPermission, login: loginAction, clearSession, logout };
});
