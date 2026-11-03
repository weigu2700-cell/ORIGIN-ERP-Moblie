import '../core/api.dart';
import '../core/session.dart';

class DocAction {
  final String label, suffix, permission, impact, method;
  final int status;
  const DocAction(
    this.label,
    this.status,
    this.suffix,
    this.permission,
    this.impact, {
    this.method = 'PUT',
  });
}

class DocSpec {
  final String key, title, path, permission, detailPermission, number, search;
  final List<String> statuses;
  final List<DocAction> actions;
  final bool warehouse;
  const DocSpec(
    this.key,
    this.title,
    this.path,
    this.permission,
    this.detailPermission,
    this.number,
    this.search,
    this.statuses,
    this.actions, {
    this.warehouse = false,
  });
  String statusLabel(dynamic status) {
    final n = int.tryParse('$status');
    return n != null && n >= 0 && n < statuses.length ? statuses[n] : '状态未知';
  }

  Map<String, dynamic> query({
    int page = 1,
    String keyword = '',
    int? status,
    String? warehouseId,
    String? orderId,
  }) => {
    'pageNum': page,
    'pageSize': 20,
    search: keyword,
    if (status != null)
      'status': key == 'warehousing'
          ? ['DRAFT', 'APPROVED', 'WAREHOUSED', 'CANCEL'][status]
          : status,
    if (warehouse && warehouseId != null) 'warehouseId': warehouseId,
    if (orderId != null) 'productionOrderId': orderId,
  };
}

const documents = [
  DocSpec(
    'inventory',
    '库存查询',
    '/inventory/material-stock',
    'inventory:material-stock:list',
    'inventory:material-stock:get',
    'materialCode',
    'materialCode',
    [],
    [],
    warehouse: true,
  ),
  DocSpec(
    'orders',
    '生产订单',
    '/prd/order',
    'production:order:list',
    'production:order:get',
    'productionOrderNo',
    'productionOrderNo',
    ['草稿', '已下达', '生产中', '已完成', '已取消'],
    [
      DocAction(
        '下达订单',
        0,
        'release',
        'production:order:release',
        '下达生产订单并计算物料需求。',
      ),
      DocAction('开始生产', 1, 'start', 'production:order:start', '将订单转为生产中。'),
      DocAction(
        '完成订单',
        2,
        'complete',
        'production:order:complete',
        '完成前请核对报工与入库情况。',
      ),
      DocAction('取消订单', 0, 'cancel', 'production:order:cancel', '取消此生产订单。'),
      DocAction('取消订单', 1, 'cancel', 'production:order:cancel', '取消此生产订单。'),
      DocAction(
        '取消订单',
        2,
        'cancel',
        'production:order:cancel',
        '取消此生产订单，服务端将校验关联业务。',
      ),
    ],
  ),
  DocSpec(
    'picking',
    '生产领料',
    '/prd/picking',
    'production:picking:list',
    'production:picking:get',
    'pickingNo',
    'productionOrderId',
    ['草稿', '已审批', '已领料', '已取消'],
    [
      DocAction(
        '审批领料',
        0,
        'approve',
        'production:picking:approve',
        '审批后仍需核对并确认领料。',
      ),
      DocAction(
        '确认领料',
        1,
        'confirm',
        'production:picking:confirm',
        '按单据数量执行领料并扣减库存，请核对物料和仓库。',
        method: 'POST',
      ),
    ],
    warehouse: true,
  ),
  DocSpec(
    'reports',
    '生产报工',
    '/prd/report',
    'prd:report:page',
    'prd:report:get',
    'productionReportNo',
    'productionReportNo',
    ['草稿', '已审批', '已取消', '已驳回', '已完成'],
    [
      DocAction('审批报工', 0, 'approve', 'prd:report:approve', '将报工单转为已审批，不增加库存。'),
      DocAction('取消报工', 0, 'cancel', 'prd:report:cancel', '取消报工并释放累计报工数量。'),
      DocAction(
        '完成报工',
        1,
        'finish',
        'prd:report:finish',
        '按合格量生成待审批入库单，不直接增加库存。',
      ),
      DocAction('驳回报工', 1, 'reject', 'prd:report:reject', '驳回后需重新登记报工。'),
    ],
  ),
  DocSpec(
    'warehousing',
    '成品入库',
    '/inv/finish-warehousing',
    'inv:finish-warehousing:list',
    'inv:finish-warehousing:get',
    'warehousingNo',
    'warehousingNo',
    ['草稿', '已审批', '已入库', '已取消'],
    [
      DocAction(
        '审批入库单',
        0,
        'approve',
        'inv:finish-warehousing:update',
        '审批后仍需执行入库。',
      ),
      DocAction(
        '取消入库单',
        0,
        'cancel',
        'inv:finish-warehousing:update',
        '取消草稿，不改变现有库存。',
      ),
      DocAction(
        '确认入库',
        1,
        'warehouse',
        'inv:finish-warehousing:update',
        '按此单数量增加目标仓库库存。',
      ),
    ],
    warehouse: true,
  ),
  DocSpec(
    'receiving',
    '采购入库',
    '/purchase/in/stock',
    'purchase:in:stock:list',
    'purchase:in:stock:detail',
    'purchaseInStockNo',
    'purchaseInStockNo',
    ['草稿', '已审核', '已上架'],
    [
      DocAction(
        '审核入库单',
        0,
        'approve',
        'purchase:in:stock:approve',
        '审核后仍需选择仓库并上架。',
      ),
      DocAction(
        '确认上架',
        1,
        'upload',
        'purchase:in:stock:upload',
        '按采购单数量入库，请核对仓库、库位及批次。',
      ),
    ],
    warehouse: true,
  ),
  DocSpec(
    'deliveries',
    '销售出库',
    '/sales/delivery',
    'sales:delivery:list',
    'sales:delivery:get',
    'deliveryNo',
    'deliveryNo',
    ['草稿', '已确认', '已取消', '已完成'],
    [
      DocAction(
        '确认出库单',
        0,
        'confirm',
        'sales:delivery:confirm',
        '确认单据并预留库存，尚未完成出库。',
      ),
      DocAction(
        '执行出库',
        1,
        'complete',
        'sales:delivery:complete',
        '按明细扣减库存并完成出库。',
      ),
      DocAction('取消出库单', 0, 'cancel', 'sales:delivery:cancel', '取消此单据。'),
      DocAction('取消出库单', 1, 'cancel', 'sales:delivery:cancel', '取消出库单并释放预留库存。'),
    ],
  ),
  DocSpec(
    'sales',
    '销售订单',
    '/sales/order',
    'sales:order:list',
    'sales:order:get',
    'orderNo',
    'orderNo',
    ['草稿', '已确认', '已完成', '已取消'],
    [],
  ),
];

class DocumentRepository {
  final Session session;
  DocumentRepository(this.session);
  void require(String code) {
    if (!session.can(code)) throw const ApiFailure('没有访问权限或当前组织业务尚未开放');
  }

  Future<Json> list(DocSpec spec, Map<String, dynamic> query) async {
    require(spec.permission);
    return await session.api.call(spec.path, query: query) as Json;
  }

  Future<Json> detail(DocSpec spec, String id) async {
    require(spec.detailPermission);
    return await session.api.call('${spec.path}/${Uri.encodeComponent(id)}')
        as Json;
  }

  Future<void> execute(
    DocSpec spec,
    String id,
    DocAction action, {
    Json? body,
  }) async {
    require(action.permission);
    final latest = await detail(spec, id);
    if (latest['status'] != action.status) {
      throw const ApiFailure('单据状态已变化，请刷新后核对');
    }
    if (spec.key == 'picking' && action.suffix == 'confirm') {
      await session.api.call(
        '/prd/picking/confirm',
        method: 'POST',
        query: {'id': id},
      );
    } else {
      await session.api.call(
        '${spec.path}/${Uri.encodeComponent(id)}/${action.suffix}',
        method: action.method,
        body: body,
      );
    }
  }
}
