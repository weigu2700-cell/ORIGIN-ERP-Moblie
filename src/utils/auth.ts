import { STORAGE_KEYS } from '@/constants/storage';

export function getToken(): string {
  return uni.getStorageSync(STORAGE_KEYS.token) || '';
}

export function setToken(token: string) {
  uni.setStorageSync(STORAGE_KEYS.token, token);
}

export function removeToken() {
  uni.removeStorageSync(STORAGE_KEYS.token);
}
