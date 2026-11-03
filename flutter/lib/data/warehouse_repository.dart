import 'package:origin_mobile/core/api.dart';
import 'package:origin_mobile/core/session.dart';

class WarehouseRepository {
  final Session session;
  WarehouseRepository(this.session);

  Future<List<Json>> enabled() async {
    if (!session.can('master:warehouse:list')) {
      throw const ApiFailure('缺少仓库查询权限，请联系管理员');
    }
    final items = <String, Json>{};
    for (var page = 1; ; page++) {
      // WarehouseStatus 没有数字码查询转换器，Spring 按枚举名绑定。
      final result =
          await session.api.call(
                '/master/warehouse',
                query: {'page': page, 'pageSize': 100, 'status': 'ENABLE'},
              )
              as Json;
      final rows = (result['records'] as List).cast<Json>();
      final before = items.length;
      for (final row in rows) {
        items[row['id'].toString()] = row;
      }
      if (items.length >= asInt(result['total']) || rows.isEmpty) {
        break;
      }
      if (items.length == before) throw const ApiFailure('仓库分页返回重复记录，请稍后重试');
    }
    return items.values.toList();
  }
}
