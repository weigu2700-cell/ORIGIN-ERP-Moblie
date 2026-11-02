import type { CreateProductionReport, ProductionOrder } from '@/types/production/production';

export interface ReportForm {
  quantity: string;
  qualified: string;
  scrapped: string;
  remark: string;
}
function units(value: string, name: string) {
  const text = value.trim();
  if (!/^\d{1,14}(\.\d{1,4})?$/.test(text)) throw new Error(`${name}请输入非负数字，最多四位小数`);
  const [whole, fraction = ''] = text.split('.');
  return BigInt(whole) * BigInt(10000) + BigInt(fraction.padEnd(4, '0'));
}
export function buildReportPayload(
  order: ProductionOrder,
  warehouseId: string,
  form: ReportForm,
): CreateProductionReport {
  if (order.status !== 2) throw new Error('仅生产中的订单可以登记报工，请刷新订单状态');
  if (!warehouseId) throw new Error('请选择成品入库仓库');
  if (order.warehouseId && order.warehouseId !== warehouseId)
    throw new Error('入库仓库必须与生产订单的目标仓库一致');
  const quantity = units(form.quantity, '报工数量');
  const qualified = units(form.qualified, '合格数量');
  const scrapped = units(form.scrapped, '报废数量');
  if (quantity <= BigInt(0)) throw new Error('报工数量必须大于零');
  if (qualified + scrapped > quantity) throw new Error('合格数量与报废数量之和不能超过报工数量');
  return {
    productionOrderId: order.id,
    materialId: order.materialId,
    warehouseId,
    reportQuantity: form.quantity.trim(),
    qualifiedQuantity: form.qualified.trim(),
    scrappedQuantity: form.scrapped.trim(),
    remark: form.remark.trim(),
  };
}

export function isUncertainWrite(error: unknown) {
  return (
    !!error &&
    typeof error === 'object' &&
    ['network', 'timeout', 'server'].includes(String((error as { kind?: string }).kind))
  );
}
