import { beforeEach, describe, expect, it, vi } from 'vitest';
import { request } from '@/utils/request';
import { setToken, getToken, removeToken } from '@/utils/auth';
vi.mock('@/config/env', () => ({ appConfig: { apiBaseUrl: 'http://fixture.test', apiBaseUrlConfigured: true, requestTimeout: 1000 } }));
const storage = new Map<string, string>();
let pending: UniApp.RequestOptions;
const abort = vi.fn();
beforeEach(() => {
  storage.clear();
  vi.stubGlobal('uni', { getStorageSync: (key: string) => storage.get(key) || '', setStorageSync: (key: string, value: string) => storage.set(key, value), removeStorageSync: (key: string) => storage.delete(key), request: vi.fn(options => { pending = options; return { abort }; }), showToast: vi.fn(), reLaunch: vi.fn() });
  removeToken(); vi.clearAllMocks();
});
describe('request session boundaries', () => {
  it.each([200, 401])('ignores an old %s response after changing organization', async (statusCode) => {
    setToken('a'); const promise = request({ url: '/test' }); const rejection = expect(promise).rejects.toMatchObject({ name: 'AbortError' });
    setToken('b');
    pending.success?.({ statusCode, data: { code: statusCode, msg: 'old', data: 'a-data' }, header: {}, cookies: [] } as UniApp.RequestSuccessCallbackResult);
    await rejection; expect(getToken()).toBe('b'); expect(uni.reLaunch).not.toHaveBeenCalled(); expect(uni.showToast).not.toHaveBeenCalled(); expect(abort).toHaveBeenCalled();
  });
  it('does not attach credentials or sign out the current user on an anonymous 401', async () => {
    setToken('b'); const promise = request({ url: '/auth/tenant/resolve', auth: false, showError: false });
    const rejection = expect(promise).rejects.toMatchObject({ code: 401 });
    expect((pending.header as Record<string,string>).Authorization).toBeUndefined();
    pending.success?.({ statusCode: 401, data: { code: 401, msg: 'denied', data: null }, header: {}, cookies: [] } as UniApp.RequestSuccessCallbackResult);
    await rejection; expect(getToken()).toBe('b'); expect(uni.reLaunch).not.toHaveBeenCalled();
  });
});
