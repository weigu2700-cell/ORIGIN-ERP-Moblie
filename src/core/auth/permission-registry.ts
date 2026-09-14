/**
 * 权限码注册表 —— 文档 M0 契约闸门产物。
 * 入口按 `list`，按钮按动作权限控制。
 * 所有权限码与后端 @PreAuthorize 注解一致，不得使用别名。
 */
export const PERMISSION_CODES = Object.freeze({
  // ---------- 仓库 ----------
  warehouseList: 'master:warehouse:list',

  // ---------- 基础资料 ----------
  materialList: 'master:material:list',
  supplierList: 'master:supplier:list',
  customerList: 'master:customer:list',
  factoryList: 'factory:list',
  productionLineList: 'master:production_line:list',

  // ---------- 库存 ----------
  inventoryList: 'inventory:material-stock:list',
  inventoryDetail: 'inventory:material-stock:get',
  inventoryCreate: 'inventory:material-stock:create',
  inventoryTransactionList: 'inventory:transaction:list',

  // ---------- 采购管理 ----------
  purchaseDemandList: 'purchase:demand:list',
  purchaseOrderList: 'purchase:order:list',

  // ---------- 采购入库 ----------
  purchaseInboundList: 'purchase:in:stock:list',
  purchaseInboundDetail: 'purchase:in:stock:detail',
  purchaseInboundApprove: 'purchase:in:stock:approve',
  purchaseInboundUpload: 'purchase:in:stock:upload',

  // ---------- 生产领料 ----------
  productionPickingList: 'production:picking:list',
  productionPickingApprove: 'production:picking:approve',
  productionPickingConfirm: 'production:picking:confirm',

  // ---------- 成品入库 ----------
  finishedWarehousingList: 'inv:finish-warehousing:list',
  finishedWarehousingDetail: 'inv:finish-warehousing:get',
  finishedWarehousingUpdate: 'inv:finish-warehousing:update',

  // ---------- 销售出库 ----------
  salesDeliveryList: 'sales:delivery:list',
  salesDeliveryDetail: 'sales:delivery:get',
  salesDeliveryConfirm: 'sales:delivery:confirm',
  salesDeliveryComplete: 'sales:delivery:complete',
  salesDeliveryCancel: 'sales:delivery:cancel',

  // ---------- 生产订单 ----------
  productionOrderList: 'production:order:list',
  productionOrderDetail: 'production:order:get',
  productionOrderRelease: 'production:order:release',
  productionOrderStart: 'production:order:start',
  productionOrderComplete: 'production:order:complete',
  productionOrderCancel: 'production:order:cancel',

  // ---------- 生产管理 ----------
  productionDemandList: 'production:demand:list',
  productionBomList: 'production:bom:list',

  // ---------- 销售订单 ----------
  salesOrderList: 'sales:order:list',
  salesOrderDetail: 'sales:order:get',

  // ---------- 生产报工 ----------
  productionReportList: 'prd:report:page',
  productionReportDetail: 'prd:report:get',
  productionReportCreate: 'prd:report:add',
  productionReportApprove: 'prd:report:approve',
  productionReportReject: 'prd:report:reject',
  productionReportFinish: 'prd:report:finish',
  productionReportCancel: 'prd:report:cancel',
} as const);

export type PermissionCode = (typeof PERMISSION_CODES)[keyof typeof PERMISSION_CODES];

export function hasPermission(userPermissions: string[], requiredPermission: string): boolean {
  if (!userPermissions || userPermissions.length === 0) return false;
  if (userPermissions.includes('*:*')) return true;
  return userPermissions.includes(requiredPermission);
}

export function hasAllPermissions(
  userPermissions: string[],
  requiredPermissions: string[],
): boolean {
  if (!requiredPermissions || requiredPermissions.length === 0) return true;
  return requiredPermissions.every((perm) => hasPermission(userPermissions, perm));
}

export function hasAnyPermission(
  userPermissions: string[],
  requiredPermissions: string[],
): boolean {
  if (!requiredPermissions || requiredPermissions.length === 0) return false;
  return requiredPermissions.some((perm) => hasPermission(userPermissions, perm));
}
