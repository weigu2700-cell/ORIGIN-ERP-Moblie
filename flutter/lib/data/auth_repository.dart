import 'package:origin_mobile/core/session.dart';

/// 登录前的组织解析接口（无需令牌）。登录与会话本身由 [Session] 负责。
class AuthRepository {
  final Session session;
  AuthRepository(this.session);

  /// 当前服务器的组织模式：`single` 单组织，或需要用户输入组织编码。
  Future<Json> tenantContext() async =>
      await session.api.call('/auth/tenant/context', auth: false) as Json;

  Future<void> resolveTenant(String code) async {
    await session.api.call(
      '/auth/tenant/resolve',
      method: 'POST',
      body: {'tenantCode': code},
      auth: false,
    );
  }
}
