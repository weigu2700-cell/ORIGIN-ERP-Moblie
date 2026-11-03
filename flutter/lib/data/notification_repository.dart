import 'package:origin_mobile/core/session.dart';

/// 业务通知（`/sys/notification`）。
class NotificationRepository {
  final Session session;
  NotificationRepository(this.session);

  static const _base = '/sys/notification';

  Future<Json> page(int pageNum, int pageSize) async =>
      await session.api.call(
            _base,
            query: {'pageNum': pageNum, 'pageSize': pageSize},
          )
          as Json;

  Future<Object?> unreadCount() => session.api.call('$_base/unread/count');

  Future<Json> detail(Object id) async =>
      await session.api.call('$_base/$id') as Json;

  Future<void> markRead(Object id) async {
    await session.api.call('$_base/$id/readed', method: 'PUT');
  }

  Future<void> markAllRead() async {
    await session.api.call('$_base/all/readed', method: 'PUT');
  }
}
