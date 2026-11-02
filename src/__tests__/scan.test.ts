import { afterEach, describe, expect, it, vi } from 'vitest';
import {
  decodeScanQuery,
  getScanErrorMessage,
  normalizeScanValue,
  openScan,
  SCAN_TARGETS,
} from '@/core/scan';

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('scan values and query handoff', () => {
  it('preserves leading zeroes, percent signs and string IDs', () => {
    expect(normalizeScanValue('  00123456789012345678\r\n')).toBe('00123456789012345678');
    expect(normalizeScanValue('A%20B')).toBe('A%20B');
    expect(decodeScanQuery(encodeURIComponent('A%20B + 中文'))).toBe('A%20B + 中文');
    expect(decodeScanQuery('%invalid')).toBe('%invalid');
  });
  it.each([
    '',
    '  ',
    'A\nB',
    'A\x00B',
    'x'.repeat(201),
    'https://erp.test/?id=1',
    'javascript:alert(1)',
    '{"id":1}',
    '[123]',
  ])('rejects unusable scan content %j', (value) =>
    expect(() => normalizeScanValue(value)).toThrow(),
  );
  it('distinguishes permission, camera and cancellation failures', () => {
    expect(getScanErrorMessage({ errMsg: 'scanCode:fail cancel' })).toBe('');
    expect(getScanErrorMessage({ name: 'NotAllowedError' })).toContain('权限');
    expect(getScanErrorMessage({ name: 'NotFoundError' })).toContain('未找到');
    expect(getScanErrorMessage({ name: 'NotReadableError' })).toContain('占用');
  });
  it('only returns a confirmed value through the opener event channel', () => {
    const navigateTo = vi.fn();
    vi.stubGlobal('uni', { navigateTo });
    const result = vi.fn();
    openScan(result, '库存扫码');
    expect(result).not.toHaveBeenCalled();
    const options = navigateTo.mock.calls[0][0];
    expect(options.url).toContain('mode=return');
    options.events.scanResult({ value: ' 00123 ' });
    expect(result).toHaveBeenCalledTimes(1);
    expect(result).toHaveBeenCalledWith('00123');
  });
  it('offers only real query routes with their existing permissions', () => {
    expect(SCAN_TARGETS).toHaveLength(6);
    SCAN_TARGETS.forEach((target) => {
      expect(target.route).toMatch(/^\/apps\//);
      expect(target.permissions.length).toBeGreaterThan(0);
    });
  });
});
