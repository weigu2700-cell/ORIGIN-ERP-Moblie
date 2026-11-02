import { beforeEach, describe, expect, it, vi } from 'vitest';
import { get, put } from '@/utils/request';
import { documentFlows } from '@/core/production/documents';
import { buildReportPayload, isUncertainWrite } from '@/core/production/report-form';
import { useWriteAction } from '@/shared/composables/useWriteAction';
import type { ProductionOrder } from '@/types/production/production';

vi.mock('@/utils/request', () => ({ get: vi.fn(), put: vi.fn(), post: vi.fn() }));
const order = {
  id: '9007199254740993',
  materialId: '9007199254740995',
  warehouseId: '42',
  status: 2,
} as ProductionOrder;
const form = { quantity: '0.3', qualified: '0.1', scrapped: '0.2', remark: ' 已核对 ' };

beforeEach(() => {
  vi.clearAllMocks();
});

describe('production report payload', () => {
  it('preserves decimal values and large IDs without Number conversion', () => {
    expect(buildReportPayload(order, '42', form)).toEqual({
      productionOrderId: order.id,
      materialId: order.materialId,
      warehouseId: '42',
      reportQuantity: '0.3',
      qualifiedQuantity: '0.1',
      scrappedQuantity: '0.2',
      remark: '已核对',
    });
    expect(
      buildReportPayload(order, '42', { ...form, quantity: '99999999999999.9999' }).reportQuantity,
    ).toBe('99999999999999.9999');
  });
  it.each(['-1', 'NaN', 'Infinity', '1e3', '1.12345', '', '1.2.3'])(
    'rejects invalid quantity %s',
    (quantity) => {
      expect(() => buildReportPayload(order, '42', { ...form, quantity })).toThrow();
    },
  );
  it('rejects zero total, excess qualified/scrapped sum, wrong warehouse and inactive order', () => {
    expect(() => buildReportPayload(order, '42', { ...form, quantity: '0' })).toThrow('大于零');
    expect(() => buildReportPayload(order, '42', { ...form, qualified: '0.2' })).toThrow(
      '不能超过',
    );
    expect(() => buildReportPayload(order, '43', form)).toThrow('目标仓库');
    expect(() => buildReportPayload({ ...order, status: 1 }, '42', form)).toThrow('生产中');
  });
  it('distinguishes unknown write outcomes from correctable validation errors', () => {
    expect(isUncertainWrite({ kind: 'timeout' })).toBe(true);
    expect(isUncertainWrite({ kind: 'network' })).toBe(true);
    expect(isUncertainWrite({ kind: 'validation' })).toBe(false);
  });
});

describe('real warehousing contract', () => {
  it('queries actual inbound documents with enum names and warehouse scope', async () => {
    vi.mocked(get).mockResolvedValue({
      records: [{ id: 'fw-1', warehousingNo: 'FW001', warehousingQuantity: 5, status: 1 }],
      total: 1,
    });
    const page = await documentFlows.inbound.list(2, 'FW', 1, '42');
    expect(get).toHaveBeenCalledWith(
      '/inv/finish-warehousing',
      expect.objectContaining({
        pageNum: 2,
        warehouseId: '42',
        warehousingNo: 'FW',
        status: 'APPROVED',
      }),
    );
    expect(page.records[0]).toMatchObject({ id: 'fw-1', no: 'FW001', quantity: 5 });
  });
  it('warehouse action calls actual stock entry rather than report completion', async () => {
    vi.mocked(put).mockResolvedValue(true);
    const action = documentFlows.inbound.actions.find((item) => item.label === '确认入库')!;
    expect(action.status).toBe(1);
    expect(action.permission).toBe('inv:finish-warehousing:update');
    await action.execute('fw-1');
    expect(put).toHaveBeenCalledWith('/inv/finish-warehousing/fw-1/warehouse');
    expect(documentFlows.inbound.labels[2]).toBe('已入库');
  });
  it('finishing a report is a separate step with a separate permission', async () => {
    const action = documentFlows.report.actions.find((item) => item.label === '完成报工')!;
    expect(action.permission).toBe('prd:report:finish');
    await action.execute('report-1');
    expect(put).toHaveBeenCalledWith('/prd/report/report-1/finish');
  });
});

describe('write action guard', () => {
  it('locks before asynchronous preparation and blocks repeat taps', async () => {
    let release!: () => void;
    const prepare = () =>
      new Promise<void>((resolve) => {
        release = resolve;
      });
    const write = useWriteAction(async () => true);
    const execute = vi.fn().mockResolvedValue(undefined);
    const first = write.run({ allowed: () => true, prepare, execute });
    expect(write.busy.value).toBe(true);
    expect(await write.run({ allowed: () => true, execute })).toBe(false);
    await Promise.resolve();
    release();
    expect(await first).toBe(true);
    expect(execute).toHaveBeenCalledTimes(1);
    expect(write.busy.value).toBe(false);
  });
  it('blocks writes when offline or permission is missing', async () => {
    const execute = vi.fn();
    await expect(
      useWriteAction(async () => false).run({ allowed: () => true, execute }),
    ).rejects.toThrow('离线');
    await expect(
      useWriteAction(async () => true).run({ allowed: () => false, execute }),
    ).rejects.toThrow('权限');
    expect(execute).not.toHaveBeenCalled();
  });
  it('rechecks permissions after preparation and never executes on stale state', async () => {
    let allowed = true;
    const execute = vi.fn();
    const write = useWriteAction(async () => true);
    await expect(
      write.run({
        allowed: () => allowed,
        prepare: async () => {
          allowed = false;
        },
        execute,
      }),
    ).rejects.toThrow('权限已变更');
    await expect(
      write.run({
        allowed: () => true,
        prepare: async () => {
          throw new Error('单据状态已变化');
        },
        execute,
      }),
    ).rejects.toThrow('状态已变化');
    expect(execute).not.toHaveBeenCalled();
    expect(write.busy.value).toBe(false);
  });
  it('cancelling confirmation does not write or report success', async () => {
    const execute = vi.fn();
    expect(
      await useWriteAction(async () => true).run({
        allowed: () => true,
        prepare: async () => false,
        execute,
      }),
    ).toBe(false);
    expect(execute).not.toHaveBeenCalled();
  });
});
