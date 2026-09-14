import { PERMISSION_CODES } from '@/core/auth/permission-registry';

export const SERVICE_CATEGORY_CODES = {
  common: 'common',
  inventory: 'inventory',
  purchase: 'purchase',
  production: 'production',
  sales: 'sales',
  master: 'master',
} as const;

export type ServiceCategoryCode =
  (typeof SERVICE_CATEGORY_CODES)[keyof typeof SERVICE_CATEGORY_CODES];

export type ServiceCode =
  | 'scan'
  | 'stock'
  | 'purchase-inbound'
  | 'production-picking'
  | 'production-inbound'
  | 'sales-outbound'
  | 'production-order'
  | 'sales-order'
  | 'inventory-flow'
  | 'purchase-demand'
  | 'purchase-order'
  | 'production-demand'
  | 'production-bom'
  | 'production-report'
  | 'material'
  | 'warehouse'
  | 'supplier'
  | 'customer'
  | 'factory'
  | 'production-line';

export interface ServiceCatalogItem {
  code: ServiceCode;
  categoryCode: ServiceCategoryCode;
  title: string;
  description: string;
  icon: string;
  tone: 'navy' | 'blue' | 'amber' | 'green' | 'cyan' | 'orange' | 'violet' | 'red';
  permissions: readonly string[];
  available: boolean;
  route?: string;
}

export const SERVICE_CATEGORIES = [
  { code: SERVICE_CATEGORY_CODES.common, title: '通用工具' },
  { code: SERVICE_CATEGORY_CODES.inventory, title: '库存仓储' },
  { code: SERVICE_CATEGORY_CODES.purchase, title: '采购管理' },
  { code: SERVICE_CATEGORY_CODES.production, title: '生产管理' },
  { code: SERVICE_CATEGORY_CODES.sales, title: '销售管理' },
  { code: SERVICE_CATEGORY_CODES.master, title: '基础资料' },
] as const;

/**
 * 移动端服务目录的唯一数据源。code/permission/route 属于契约数据；
 * title/description 仅用于本地展示，不进入任何 API query 或 body。
 */
export const SERVICE_CATALOG = [
  {
    code: 'scan',
    categoryCode: SERVICE_CATEGORY_CODES.common,
    title: '扫一扫',
    description: '扫描物料条码并定位库存',
    icon: 'scan',
    tone: 'navy',
    permissions: [],
    available: true,
  },
  {
    code: 'stock',
    categoryCode: SERVICE_CATEGORY_CODES.inventory,
    title: '库存查询',
    description: '查看物料库存与可用数量',
    icon: 'search',
    tone: 'blue',
    permissions: [PERMISSION_CODES.inventoryList],
    available: true,
    route: '/apps/inventory/index',
  },
  {
    code: 'inventory-flow',
    categoryCode: SERVICE_CATEGORY_CODES.inventory,
    title: '库存流水',
    description: '追踪物料库存变动记录',
    icon: 'chart',
    tone: 'blue',
    permissions: [PERMISSION_CODES.inventoryTransactionList],
    available: false,
  },
  {
    code: 'purchase-inbound',
    categoryCode: SERVICE_CATEGORY_CODES.purchase,
    title: '采购入库',
    description: '处理采购到货与上架',
    icon: 'shop',
    tone: 'amber',
    permissions: [PERMISSION_CODES.purchaseInboundList],
    available: true,
    route: '/apps/purchase-in-stock/index',
  },
  {
    code: 'purchase-demand',
    categoryCode: SERVICE_CATEGORY_CODES.purchase,
    title: '采购需求',
    description: '汇总与跟踪采购需求',
    icon: 'list',
    tone: 'amber',
    permissions: [PERMISSION_CODES.purchaseDemandList],
    available: false,
  },
  {
    code: 'purchase-order',
    categoryCode: SERVICE_CATEGORY_CODES.purchase,
    title: '采购订单',
    description: '查看采购订单执行进度',
    icon: 'a-rootlist',
    tone: 'amber',
    permissions: [PERMISSION_CODES.purchaseOrderList],
    available: false,
  },
  {
    code: 'production-picking',
    categoryCode: SERVICE_CATEGORY_CODES.production,
    title: '生产领料',
    description: '按生产任务办理领料',
    icon: 'goods',
    tone: 'green',
    permissions: [PERMISSION_CODES.productionPickingList],
    available: true,
    route: '/apps/production-picking/index',
  },
  {
    code: 'production-inbound',
    categoryCode: SERVICE_CATEGORY_CODES.production,
    title: '成品入库',
    description: '处理生产完成后的入库',
    icon: 'layers',
    tone: 'cyan',
    permissions: [PERMISSION_CODES.finishedWarehousingList],
    available: true,
    route: '/apps/production-inbound/index',
  },
  {
    code: 'production-order',
    categoryCode: SERVICE_CATEGORY_CODES.production,
    title: '生产订单',
    description: '查看并推进生产任务',
    icon: 'list',
    tone: 'violet',
    permissions: [PERMISSION_CODES.productionOrderList],
    available: true,
    route: '/apps/production-order/index',
  },
  {
    code: 'production-demand',
    categoryCode: SERVICE_CATEGORY_CODES.production,
    title: '生产需求',
    description: '查看生产需求来源与进度',
    icon: 'calendar',
    tone: 'green',
    permissions: [PERMISSION_CODES.productionDemandList],
    available: false,
  },
  {
    code: 'production-bom',
    categoryCode: SERVICE_CATEGORY_CODES.production,
    title: 'BOM',
    description: '查看产品物料清单',
    icon: 'file',
    tone: 'cyan',
    permissions: [PERMISSION_CODES.productionBomList],
    available: false,
  },
  {
    code: 'production-report',
    categoryCode: SERVICE_CATEGORY_CODES.production,
    title: '生产报工',
    description: '登记生产数量与质量结果',
    icon: 'edit',
    tone: 'violet',
    permissions: [PERMISSION_CODES.productionReportList],
    available: false,
  },
  {
    code: 'sales-order',
    categoryCode: SERVICE_CATEGORY_CODES.sales,
    title: '销售订单',
    description: '查看客户销售订单',
    icon: 'a-rootlist',
    tone: 'red',
    permissions: [PERMISSION_CODES.salesOrderList],
    available: true,
    route: '/apps/sales-order/index',
  },
  {
    code: 'sales-outbound',
    categoryCode: SERVICE_CATEGORY_CODES.sales,
    title: '销售出库',
    description: '处理销售发货与出库',
    icon: 'cart',
    tone: 'orange',
    permissions: [PERMISSION_CODES.salesDeliveryList],
    available: true,
    route: '/apps/sales-outbound/index',
  },
  {
    code: 'material',
    categoryCode: SERVICE_CATEGORY_CODES.master,
    title: '物料',
    description: '查看物料基础资料',
    icon: 'goods',
    tone: 'blue',
    permissions: [PERMISSION_CODES.materialList],
    available: false,
  },
  {
    code: 'warehouse',
    categoryCode: SERVICE_CATEGORY_CODES.master,
    title: '仓库',
    description: '查看仓库与库区信息',
    icon: 'home',
    tone: 'navy',
    permissions: [PERMISSION_CODES.warehouseList],
    available: false,
  },
  {
    code: 'supplier',
    categoryCode: SERVICE_CATEGORY_CODES.master,
    title: '供应商',
    description: '查看供应商基础资料',
    icon: 'usergroup',
    tone: 'amber',
    permissions: [PERMISSION_CODES.supplierList],
    available: false,
  },
  {
    code: 'customer',
    categoryCode: SERVICE_CATEGORY_CODES.master,
    title: '客户',
    description: '查看客户基础资料',
    icon: 'user',
    tone: 'red',
    permissions: [PERMISSION_CODES.customerList],
    available: false,
  },
  {
    code: 'factory',
    categoryCode: SERVICE_CATEGORY_CODES.master,
    title: '工厂',
    description: '查看工厂基础资料',
    icon: 'home',
    tone: 'green',
    permissions: [PERMISSION_CODES.factoryList],
    available: false,
  },
  {
    code: 'production-line',
    categoryCode: SERVICE_CATEGORY_CODES.master,
    title: '生产线',
    description: '查看生产线基础资料',
    icon: 'setting',
    tone: 'violet',
    permissions: [PERMISSION_CODES.productionLineList],
    available: false,
  },
] as const satisfies readonly ServiceCatalogItem[];
