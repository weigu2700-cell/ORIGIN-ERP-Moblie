import { computed, ref } from 'vue';
import { defineStore } from 'pinia';
import { login } from '@/api/system/auth';
import { getCurrentUser, getCurrentUserPermissions } from '@/api/system/user';
import { STORAGE_KEYS } from '@/constants/storage';
import type { LoginRequest } from '@/types/system/auth';
import type { CurrentUser } from '@/types/system/user';
import { getToken, removeToken, setToken } from '@/utils/auth';

export type SessionStatus = 'unknown' | 'restoring' | 'authenticated' | 'anonymous' | 'error';
export type PermissionStatus = 'idle' | 'loading' | 'ready' | 'error';

export const useUserStore = defineStore('user', () => {
  const token = ref(getToken());
  const profile = ref<CurrentUser | null>(null);
  const permissions = ref<string[]>([]);
  const sessionStatus = ref<SessionStatus>(token.value ? 'unknown' : 'anonymous');
  const permissionsStatus = ref<PermissionStatus>('idle');
  const contextError = ref('');
  const hasToken = computed(() => Boolean(token.value));
  const isLoggedIn = computed(() => sessionStatus.value === 'authenticated');
  const displayName = computed(() => profile.value?.realName || profile.value?.username || '用户');
  const primaryRole = computed(() => profile.value?.roles?.[0]?.roleName || '企业用户');

  function restoreSession() {
    token.value = getToken();
    if (!token.value) sessionStatus.value = 'anonymous';
    else if (sessionStatus.value === 'anonymous') sessionStatus.value = 'unknown';
  }

  async function loginAction(data: LoginRequest) {
    const result = await login(data);
    if (!result.token) throw new Error('登录响应缺少 Token');
    setToken(result.token);
    token.value = result.token;
    sessionStatus.value = 'restoring';
    try {
      await loadUserContext();
      sessionStatus.value = 'authenticated';
    } catch (error) {
      clearSession();
      throw error;
    }
  }

  async function loadUserContext() {
    contextError.value = '';
    profile.value = await getCurrentUser();
    permissionsStatus.value = 'loading';
    try {
      const permissionResult = await getCurrentUserPermissions();
      permissions.value = permissionResult.map((item) => item.code).filter(Boolean);
      permissionsStatus.value = 'ready';
    } catch (error) {
      permissions.value = [];
      permissionsStatus.value = 'error';
      contextError.value = error instanceof Error ? error.message : '权限加载失败';
    }
  }

  function isAuthenticationError(error: unknown) {
    if (!error || typeof error !== 'object') return false;
    const candidate = error as { code?: number; statusCode?: number; kind?: string };
    return (
      candidate.code === 401 || candidate.statusCode === 401 || candidate.kind === 'unauthorized'
    );
  }

  async function validateSession(force = false) {
    restoreSession();
    if (!token.value) return false;
    if (!force && sessionStatus.value === 'authenticated' && profile.value) return true;

    sessionStatus.value = 'restoring';
    try {
      await loadUserContext();
      sessionStatus.value = 'authenticated';
      return true;
    } catch (error) {
      if (isAuthenticationError(error) || !getToken()) {
        clearSession();
        return false;
      }
      sessionStatus.value = 'error';
      contextError.value = error instanceof Error ? error.message : '会话验证失败';
      throw error;
    }
  }

  function hasAnyPermission(codes: string[]) {
    if (!codes.length) return true;
    const roleCodes = profile.value?.roles?.map((role) => role.roleCode?.toUpperCase()) || [];
    if (roleCodes.some((code) => code === 'ADMIN' || code === 'SUPER_ADMIN')) return true;
    return codes.some((code) => permissions.value.includes(code));
  }

  function clearSession() {
    removeToken();
    token.value = '';
    profile.value = null;
    permissions.value = [];
    sessionStatus.value = 'anonymous';
    permissionsStatus.value = 'idle';
    contextError.value = '';
    uni.removeStorageSync(STORAGE_KEYS.currentWarehouse);
    uni.removeStorageSync(STORAGE_KEYS.currentWarehouseId);
  }

  function logout() {
    clearSession();
    uni.reLaunch({ url: '/pages/login/login' });
  }

  return {
    token,
    profile,
    permissions,
    sessionStatus,
    permissionsStatus,
    contextError,
    hasToken,
    isLoggedIn,
    displayName,
    primaryRole,
    restoreSession,
    validateSession,
    loadUserContext,
    hasAnyPermission,
    login: loginAction,
    clearSession,
    logout,
  };
});
