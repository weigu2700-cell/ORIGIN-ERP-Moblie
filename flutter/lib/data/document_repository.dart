import 'package:origin_mobile/core/api.dart';
import 'package:origin_mobile/core/session.dart';
import 'package:origin_mobile/domain/documents.dart';

/// 单据（领料、成品入库、采购入库、销售出库等）的列表、详情与状态流转。
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
