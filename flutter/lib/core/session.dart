import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api.dart';

typedef Json = Map<String, dynamic>;

abstract class TokenVault {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

class SecureTokenVault implements TokenVault {
  final String key;
  SecureTokenVault({this.key = 'origin.token'});
  // macOS 本地调试没有团队签名，数据保护钥匙串不可用，退回登录钥匙串。
  final FlutterSecureStorage storage = const FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );
  @override
  Future<String?> read() => storage.read(key: key);
  @override
  Future<void> write(String token) => storage.write(key: key, value: token);
  @override
  Future<void> clear() => storage.delete(key: key);
}

enum SessionStatus { restoring, anonymous, authenticated, error }

class Session extends ChangeNotifier {
  final ApiClient api;
  final TokenVault vault;
  SessionStatus status = SessionStatus.restoring;
  Json profile = {}, organization = {};
  Set<String> permissions = {};
  bool businessAvailable = false;
  String? error;
  Future<void> _storage = Future.value();
  Session(this.api, this.vault) {
    api.onUnauthorized = logout;
  }
  String get name =>
      (profile['realName'] ?? profile['username'] ?? '用户').toString();
  bool can(String permission) =>
      businessAvailable &&
      (permissions.contains(permission) ||
          ((profile['roles'] as List?) ?? []).any(
            (r) => ['ADMIN', 'SUPER_ADMIN'].contains(r['roleCode']),
          ));
  // 串行安全存储写入，防止慢写入在退出后把旧 token 写回来。
  Future<void> _save(Future<void> Function() operation) {
    final next = _storage.catchError((_) {}).then((_) => operation());
    _storage = next;
    return next;
  }

  Future<void> restore() async {
    status = SessionStatus.restoring;
    error = null;
    notifyListeners();
    final ticket = api.generation;
    try {
      final token = await vault.read();
      api.check(ticket);
      if (token == null) {
        status = SessionStatus.anonymous;
        notifyListeners();
        return;
      }
      api.boundary(token);
      await _context();
    } catch (e) {
      if (e is SessionChanged) return;
      if (status != SessionStatus.anonymous) {
        status = SessionStatus.error;
        error = e.toString();
        notifyListeners();
      }
    }
  }

  Future<void> login(String tenant, String username, String password) async {
    api.boundary();
    final ticket = api.generation;
    final result =
        await api.call(
              '/auth/login',
              method: 'POST',
              auth: false,
              body: {
                'tenantCode': tenant,
                'username': username,
                'password': password,
              },
            )
            as Json;
    api.check(ticket);
    final token = result['token'];
    if (token is! String || token.isEmpty) throw const ApiFailure('登录响应缺少凭据');
    api.boundary(token);
    final active = api.generation;
    try {
      await _save(() => vault.write(token));
      api.check(active);
      await _context();
    } catch (_) {
      if (active == api.generation) await logout();
      rethrow;
    }
  }

  Future<void> _context() async {
    final ticket = api.generation;
    final context = await api.call('/auth/tenant/session') as Json;
    Json user = context['user'] as Json;
    Set<String> codes = {};
    final available = context['businessAvailable'] == true;
    if (available) {
      user = await api.call('/system/user/current') as Json;
      final items = await api.call('/system/permission') as List;
      codes = items.map((p) => p['code'].toString()).toSet();
    }
    api.check(ticket);
    profile = user;
    organization = context['organization'] as Json;
    businessAvailable = available;
    permissions = codes;
    status = SessionStatus.authenticated;
    error = null;
    notifyListeners();
  }

  Future<void> logout() async {
    api.boundary();
    profile = {};
    organization = {};
    permissions = {};
    businessAvailable = false;
    status = SessionStatus.anonymous;
    error = null;
    notifyListeners();
    try {
      await _save(vault.clear);
    } catch (e) {
      error = '本机凭据清除失败，请重试退出';
      notifyListeners();
    }
  }
}
