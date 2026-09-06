import { post } from "@/utils/request";
import type { LoginRequest, LoginResponse } from "@/types/system/auth";

export function login(data: LoginRequest) {
  return post<LoginResponse>("/auth/login", data, {
    auth: false,
    showError: false,
  });
}
