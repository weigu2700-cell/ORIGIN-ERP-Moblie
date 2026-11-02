import { PERMISSION_CODES as P } from '@/core/auth/permission-registry';
import {
  getPageProductionReport,
  getDetailProductionReport,
  approveProductionReport,
  cancelProductionReport,
  rejectProductionReport,
  finishProductionReport,
} from '@/api/production/production';
import {
  getPageFinishWarehousing,
  getDetailFinishWarehousing,
  approveFinishWarehousing,
  warehouseFinishWarehousing,
  cancelFinishWarehousing,
} from '@/api/production/warehousing';
import type { ProductionReport } from '@/types/production/production';
import type { FinishWarehousing, WarehousingQuery } from '@/types/production/warehousing';

export type DocumentKind = 'report' | 'inbound';
export interface ProductionDocument {
  id: string;
  no: string;
  orderNo?: string;
  materialName?: string;
  materialCode?: string;
  warehouseName?: string;
  quantity: number;
  qualified?: number;
  scrapped?: number;
  userName?: string;
  time?: string;
  reportNo?: string;
  status: number;
  remark?: string;
}
export interface DocumentAction {
  label: string;
  status: number;
  permission: string;
  hint: string;
  execute: (id: string) => Promise<void | boolean>;
}
const report = (value: ProductionReport): ProductionDocument => ({
  id: value.id,
  no: value.productionReportNo,
  orderNo: value.productionOrderNo,
  materialName: value.materialName,
  materialCode: value.materialCode,
  warehouseName: value.warehouseName,
  quantity: value.reportQuantity,
  qualified: value.qualifiedQuantity,
  scrapped: value.scrappedQuantity,
  userName: value.reportUserName,
  time: value.reportTime,
  status: value.status,
  remark: value.remark,
});
const inbound = (value: FinishWarehousing): ProductionDocument => ({
  id: value.id,
  no: value.warehousingNo,
  orderNo: value.productionOrderNo,
  reportNo: value.productionReportNo,
  materialName: value.materialName,
  materialCode: value.materialCode,
  warehouseName: value.warehouseName,
  quantity: value.warehousingQuantity,
  userName: value.warehousingUserName,
  time: value.warehousingTime,
  status: value.status,
  remark: value.remark,
});
export const documentFlows = {
  report: {
    title: '生产报工',
    base: '/apps/production-report',
    listPermission: P.productionReportList,
    detailPermission: P.productionReportDetail,
    hint: '完成报工会生成成品入库单；随后需审批并执行入库，库存才会增加。',
    labels: ['草稿', '已审批', '已取消', '已驳回', '已完成'],
    async list(
      pageNum: number,
      keyword: string,
      status?: number,
      _warehouseId?: string,
      orderId?: string,
    ) {
      const page = await getPageProductionReport({
        pageNum,
        pageSize: 20,
        productionReportNo: keyword || undefined,
        status: status as ProductionReport['status'] | undefined,
        productionOrderId: orderId,
      });
      return { records: page.records.map(report), total: page.total };
    },
    async detail(id: string) {
      return report(await getDetailProductionReport(id));
    },
    actions: [
      {
        label: '审批报工',
        status: 0,
        permission: P.productionReportApprove,
        hint: '将报工单转为已审批。',
        execute: approveProductionReport,
      },
      {
        label: '取消报工',
        status: 0,
        permission: P.productionReportCancel,
        hint: '取消后该报工单不再占用累计报工数量。',
        execute: cancelProductionReport,
      },
      {
        label: '完成报工',
        status: 1,
        permission: P.productionReportFinish,
        hint: '根据合格数量生成待审批成品入库单，不会直接增加库存。',
        execute: finishProductionReport,
      },
      {
        label: '驳回报工',
        status: 1,
        permission: P.productionReportReject,
        hint: '驳回后需重新登记报工。',
        execute: rejectProductionReport,
      },
    ] as DocumentAction[],
  },
  inbound: {
    title: '成品入库',
    base: '/apps/production-inbound',
    listPermission: P.finishedWarehousingList,
    detailPermission: P.finishedWarehousingDetail,
    hint: '核对仓库和数量后审批，再执行入库；执行入库成功后才增加库存。',
    labels: ['草稿', '已审批', '已入库', '已取消'],
    async list(
      pageNum: number,
      keyword: string,
      status?: number,
      warehouseId?: string,
      orderId?: string,
    ) {
      const names: WarehousingQuery['status'][] = ['DRAFT', 'APPROVED', 'WAREHOUSED', 'CANCEL'];
      const page = await getPageFinishWarehousing({
        pageNum,
        pageSize: 20,
        warehousingNo: keyword || undefined,
        status: status === undefined ? undefined : names[status],
        warehouseId,
        productionOrderId: orderId,
      });
      return { records: page.records.map(inbound), total: page.total };
    },
    async detail(id: string) {
      return inbound(await getDetailFinishWarehousing(id));
    },
    actions: [
      {
        label: '审批入库单',
        status: 0,
        permission: P.finishedWarehousingUpdate,
        hint: '审批后仍需执行入库才会增加库存。',
        execute: approveFinishWarehousing,
      },
      {
        label: '取消入库单',
        status: 0,
        permission: P.finishedWarehousingUpdate,
        hint: '仅取消草稿入库单，不会改变现有库存。',
        execute: cancelFinishWarehousing,
      },
      {
        label: '确认入库',
        status: 1,
        permission: P.finishedWarehousingUpdate,
        hint: '将按此单数量增加所选仓库库存，请核对仓库和数量。',
        execute: warehouseFinishWarehousing,
      },
    ] as DocumentAction[],
  },
};
