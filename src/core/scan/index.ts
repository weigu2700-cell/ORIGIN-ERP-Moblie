import { SERVICE_CATALOG } from '@/constants/service-catalog';

/** Only literal codes are accepted: QR URLs/JSON are never executed or guessed as business IDs. */
export function normalizeScanValue(raw: string): string {
  const value = raw.trim();
  if (!value) throw new Error('未读取到编码，请重新扫码或手动输入');
  if (value.length > 200) throw new Error('编码过长，请扫描物料或单据编码');
  if (Array.from(value).some((char) => char.charCodeAt(0) < 32 || char.charCodeAt(0) === 127))
    throw new Error('编码包含换行或控制字符，请核对后输入');
  if (/^(?:[a-z][a-z\d+.-]*:\/\/|javascript:|data:)/i.test(value) || /^[{[]/.test(value)) {
    throw new Error('这是链接或结构化二维码，请改扫物料条码或单据编号');
  }
  return value;
}

export function decodeScanQuery(value: unknown): string {
  const raw = String(value || '');
  try {
    return decodeURIComponent(raw);
  } catch {
    return raw;
  }
}

export const SCAN_TARGETS = SERVICE_CATALOG.filter((item) =>
  [
    'stock',
    'purchase-inbound',
    'production-picking',
    'sales-outbound',
    'production-order',
    'sales-order',
  ].includes(item.code),
);

export function getScanErrorMessage(error: unknown): string {
  const candidate = error as { name?: string; errMsg?: string; message?: string } | null;
  const message = candidate?.errMsg || candidate?.message || '';
  if (/cancel/i.test(message)) return '';
  if (
    /NotAllowed|PermissionDenied/i.test(candidate?.name || '') ||
    /permission|auth|denied|权限|授权/i.test(message)
  ) {
    return '相机权限未开启，请在系统或浏览器设置中允许访问相机，或手动输入编码';
  }
  if (/NotFound|DevicesNotFound/i.test(candidate?.name || ''))
    return '未找到可用相机，请连接相机或手动输入编码';
  if (/NotReadable|TrackStart/i.test(candidate?.name || ''))
    return '相机被占用，请关闭其他使用相机的应用后重试';
  return '扫码失败，请重试或手动输入编码';
}

export function openScan(onResult: (value: string) => void, title = '扫码搜索') {
  uni.navigateTo({
    url: `/pages/scan/index?mode=return&title=${encodeURIComponent(title)}`,
    events: { scanResult: (data: { value: string }) => onResult(normalizeScanValue(data.value)) },
    fail: () => uni.showToast({ title: '无法打开扫码页，请重试', icon: 'none' }),
  });
}
