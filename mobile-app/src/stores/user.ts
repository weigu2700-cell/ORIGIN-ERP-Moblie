import { computed, ref } from "vue";
import { defineStore } from "pinia";
import { login } from "@/api/system/auth";
import { getCurrentUser, getCurrentUserPermissions } from "@/api/system/user";
import { STORAGE_KEYS } from "@/constants/storage";
import type { LoginRequest } from "@/types/system/auth";
import type { CurrentUser } from "@/types/system/user";
import { getToken, removeToken, setToken } from "@/utils/auth";

export const useUserStore = defineStore("user", () => {
  const token = ref(getToken());
  const profile = ref<CurrentUser | null>(null);
  const permissions = ref<string[]>([]);
  const isLoggedIn = computed(() => Boolean(token.value));
  const displayName = computed(() => profile.value?.realName || profile.value?.username || "用户");
  const primaryRole = computed(() => profile.value?.roles?.[0]?.roleName || "企业用户");

  function restoreSession() {
    token.value = getToken();
  }

  async function loginAction(data: LoginRequest) {
    const result = await login(data);
    if (!result.token) throw new Error("登录响应缺少 Token");
    setToken(result.token);
    token.value = result.token;
  }

  async function loadUserContext() {
    profile.value = await getCurrentUser();
    try {
      const permissionResult = await getCurrentUserPermissions();
      permissions.value = permissionResult.map((item) => item.code).filter(Boolean);
    } catch {
      permissions.value = [];
    }
  }

  function hasAnyPermission(codes: string[]) {
    if (!codes.length) return true;
    const roleCodes = profile.value?.roles?.map((role) => role.roleCode?.toUpperCase()) || [];
    if (roleCodes.some((code) => code === "ADMIN" || code === "SUPER_ADMIN")) return true;
    return codes.some((code) => permissions.value.includes(code));
  }

  function logout() {
    removeToken();
    token.value = "";
    profile.value = null;
    permissions.value = [];
    uni.removeStorageSync(STORAGE_KEYS.currentWarehouse);
    uni.reLaunch({ url: "/pages/login/login" });
  }

  return {
    token,
    profile,
    permissions,
    isLoggedIn,
    displayName,
    primaryRole,
    restoreSession,
    loadUserContext,
    hasAnyPermission,
    login: loginAction,
    logout,
  };
});
