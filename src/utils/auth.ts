import { STORAGE_KEYS } from '@/constants/storage';
const TOKEN_KEY = STORAGE_KEYS.token;

let generation = 0
const listeners = new Set<() => void>()
const aborters = new Set<() => void>()
export interface SessionSnapshot { generation: number; token: string | null }
export class SessionChangedError extends Error {
  constructor() { super('会话已切换，已忽略旧请求'); this.name = 'AbortError' }
}
export function refreshSessionBoundary() { advanceSession() }
export function getToken(): string { return uni.getStorageSync(TOKEN_KEY) || '' }
export function captureSession(): SessionSnapshot { return { generation, token: getToken() } }
export function isSessionCurrent(snapshot: SessionSnapshot) { return snapshot.generation === generation && snapshot.token === getToken() }
export function assertSession(snapshot: SessionSnapshot) { if (!isSessionCurrent(snapshot)) throw new SessionChangedError() }
function advanceSession() {
  generation += 1
  for (const abort of [...aborters]) abort()
  aborters.clear()
  for (const listener of [...listeners]) listener()
}
export function setToken(token: string) { uni.setStorageSync(TOKEN_KEY, token); advanceSession() }
export function removeToken() { uni.removeStorageSync(TOKEN_KEY); advanceSession() }
export function onSessionChange(listener: () => void) { listeners.add(listener); return () => { listeners.delete(listener) } }
export function registerSessionAbort(abort: () => void) { aborters.add(abort); return () => { aborters.delete(abort) } }
