import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:origin_mobile/core/api.dart';
import 'package:origin_mobile/core/session.dart';

import 'support/fakes.dart';

void main() {
  test('multi 门禁恢复不请求未开放的业务和权限接口', () async {
    final api = FixtureApi();
    final vault = MemoryVault()..token = 'stored';
    api.handler = (path, method, query, body) async => {
      'organization': {'code': 'tenant-b', 'name': '组织 B'},
      'user': {'id': 'same-user', 'username': 'worker'},
      'businessAvailable': false,
    };
    final session = Session(api, vault);
    await session.restore();
    expect(session.status, SessionStatus.authenticated);
    expect(session.businessAvailable, isFalse);
    expect(api.requests, ['GET /auth/tenant/session']);
    expect(session.can('prd:report:add'), isFalse);
    session.dispose();
  });

  test('权限加载失败清除新登录凭据，不能带着部分身份进入业务', () async {
    final api = FixtureApi();
    final vault = MemoryVault();
    api.handler = (path, method, query, body) async => switch (path) {
      '/auth/login' => {'token': 'new-token'},
      '/auth/tenant/session' => {
        'organization': {'code': 'a'},
        'user': {'id': 'u'},
        'businessAvailable': true,
      },
      '/system/user/current' => {'id': 'u', 'roles': <Json>[]},
      _ => throw const ApiFailure('权限服务暂不可用'),
    };
    final session = Session(api, vault);
    await expectLater(
      session.login('a', 'user', 'password'),
      throwsA(isA<ApiFailure>()),
    );
    expect(vault.token, isNull);
    expect(api.token, isNull);
    expect(session.status, SessionStatus.anonymous);
    session.dispose();
  });

  test('退出发生在会话恢复中，旧组织不能复活', () async {
    final pending = Completer<Json>();
    final entered = Completer<void>();
    final api = FixtureApi();
    api.handler = (path, method, query, body) {
      entered.complete();
      return pending.future;
    };
    final session = Session(api, MemoryVault()..token = 'old-token');
    final restoring = session.restore();
    await entered.future;
    await session.logout();
    pending.complete({
      'organization': {'code': 'old-tenant'},
      'user': {'id': 'same-user'},
      'businessAvailable': false,
    });
    await restoring;
    expect(session.status, SessionStatus.anonymous);
    expect(session.organization, isEmpty);
    session.dispose();
  });

  test('安全存储的慢写入不能越过退出重新留下凭据', () async {
    final api = FixtureApi();
    api.handler = (path, method, query, body) async => {'token': 'old-token'};
    final vault = SlowVault();
    final session = Session(api, vault);
    final login = session.login('a', 'worker', 'password');
    final assertion = expectLater(login, throwsA(isA<SessionChanged>()));
    await vault.started.future;
    final logout = session.logout();
    vault.resume.complete();
    await assertion;
    await logout;
    expect(vault.token, isNull);
    expect(session.status, SessionStatus.anonymous);
    session.dispose();
  });
}

class SlowVault extends MemoryVault {
  final started = Completer<void>();
  final resume = Completer<void>();
  @override
  Future<void> write(String value) async {
    started.complete();
    await resume.future;
    token = value;
  }
}
