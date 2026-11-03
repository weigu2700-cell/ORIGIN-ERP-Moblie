import 'package:origin_mobile/core/session.dart';

/// 生产订单与报工。
class ProductionRepository {
  final Session session;
  ProductionRepository(this.session);

  Future<Json> order(Object id) async =>
      await session.api.call('/prd/order/$id') as Json;

  Future<void> createReport(Json body) async {
    await session.api.call('/prd/report', method: 'POST', body: body);
  }
}
