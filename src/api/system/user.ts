import { get } from "@/utils/request";
import type { CurrentUser, Permission } from "@/types/system/user";

export function getCurrentUser() {
  return get<CurrentUser>("/system/user/current", undefined, { showError: false });
}

export function getCurrentUserPermissions() {
  return get<Permission[]>("/system/permission", undefined, { showError: false });
}
