import { beforeEach, afterEach, describe, expect, it, vi } from 'vitest';
import { createPinia, setActivePinia, disposePinia, type Pinia } from 'pinia';
import { useUserStore } from '@/stores/user';
import { useWorkbenchStore } from '@/stores/workbench';
import { useOrganizationStore } from '@/stores/organization';
import { login, getTenantSession, resolveOrganization, getTenantConfiguration } from '@/api/system/auth';
import { getEnabledWarehouses } from '@/api/master/warehouse';
import { getToken, setToken, removeToken } from '@/utils/auth';
vi.mock('@/api/system/auth', () => ({ login: vi.fn(), getTenantSession: vi.fn(), resolveOrganization: vi.fn(), getTenantConfiguration: vi.fn() }));
vi.mock('@/api/system/user', () => ({ getCurrentUser: vi.fn(), getCurrentUserPermissions: vi.fn() }));
vi.mock('@/api/master/warehouse', () => ({ getEnabledWarehouses: vi.fn() }));
function deferred<T>() { let resolve!: (value: T) => void; const promise = new Promise<T>(done => { resolve = done; }); return { promise, resolve }; }
const session = (code: string) => ({ tenantId: code, organization: { code, name: `组织 ${code}` }, businessAvailable: false, user: { id: '80001', username: 'owner', realName: code } });
const storage = new Map<string, unknown>();
let pinia: Pinia;
beforeEach(() => {
  vi.stubGlobal('uni', { getStorageSync: vi.fn(key => storage.get(key) || ''), setStorageSync: vi.fn((key, value) => storage.set(key, value)), removeStorageSync: vi.fn(key => storage.delete(key)), reLaunch: vi.fn(), switchTab: vi.fn() });
  storage.clear(); removeToken(); pinia = createPinia(); setActivePinia(pinia); vi.clearAllMocks();
});
afterEach(() => { disposePinia(pinia); removeToken(); });
describe('organization session', () => {
  it('cannot restore an old token after logout and another organization login', async () => {
    const first = deferred<{ token: string }>();
    vi.mocked(login).mockImplementation(data => data.tenantCode === 'a' ? first.promise : Promise.resolve({ token: 'b-token' }));
    vi.mocked(getTenantSession).mockResolvedValue(session('b'));
    const user = useUserStore();
    const old = user.login({ tenantCode: 'a', username: 'owner', password: 'fixture' }); const rejection = expect(old).rejects.toMatchObject({ name: 'AbortError' });
    user.logout(); await user.login({ tenantCode: 'b', username: 'owner', password: 'fixture' });
    first.resolve({ token: 'a-token' }); await rejection;
    expect(getToken()).toBe('b-token'); expect(user.organization?.code).toBe('b'); expect(user.profile?.id).toBe('80001');
  });
  it('clears cached workbench data and rejects a late warehouse response', async () => {
    setToken('a-token'); const user = useUserStore(); const workbench = useWorkbenchStore();
    user.permissionsStatus = 'ready'; user.hasAnyPermission = () => true;
    const pending = deferred<{ records: Array<{ id: string; name: string }>; total: number }>();
    vi.mocked(getEnabledWarehouses).mockReturnValue(pending.promise as ReturnType<typeof getEnabledWarehouses>);
    const load = workbench.loadWarehouses(); user.logout(); setToken('b-token');
    pending.resolve({ records: [{ id: 'a-warehouse', name: '旧组织仓库' }], total: 1 }); await load;
    expect(workbench.warehouses).toEqual([]); expect(workbench.currentWarehouse).toBeNull(); expect(workbench.warehouseStatus).toBe('idle');
  });
  it('ignores a late profile response and retains the new session', async () => {
    const first = deferred<ReturnType<typeof session>>();
    vi.mocked(getTenantSession).mockReturnValueOnce(first.promise).mockResolvedValueOnce(session('b'));
    setToken('a-token'); const user = useUserStore();
    const old = user.loadUserContext(); const rejection = expect(old).rejects.toMatchObject({ name: 'AbortError' });
    setToken('b-token'); await user.loadUserContext(); first.resolve(session('a')); await rejection;
    expect(user.organization?.code).toBe('b'); expect(user.businessAvailable).toBe(false);
  });
  it('keeps a single deployment usable without entering a company code', async () => {
    vi.mocked(getTenantConfiguration).mockResolvedValue({ mode: 'single', organization: { code: 'single', name: '默认组织' } });
    const organizations = useOrganizationStore(); await organizations.initialize(); expect(organizations.resolved?.code).toBe('single');
  });
  it('does not select an older organization when its validation finishes last', async () => {
    const first = deferred<{ code: string; name: string }>();
    vi.mocked(resolveOrganization).mockImplementation(code => code === 'a' ? first.promise : Promise.resolve({ code: 'b', name: 'B' }));
    const organizations = useOrganizationStore(); const old = organizations.verify('a'); const rejection = expect(old).rejects.toThrow('组织选择已改变');
    await organizations.verify('b'); first.resolve({ code: 'a', name: 'A' }); await rejection; expect(organizations.resolved?.code).toBe('b');
  });
});
