// ignore_for_file: avoid_print
// 联调自检：对真实后端执行只读请求并检查字段形状。
// 用法：LIVE_URL=http://localhost:8080 LIVE_USER=.. LIVE_PASS=.. ./tool/flutterw test tool/live_check.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:origin_mobile/data/document_repository.dart';
import 'package:origin_mobile/core/api.dart';
import 'package:origin_mobile/core/session.dart';
import 'package:origin_mobile/domain/documents.dart';
import 'package:origin_mobile/data/warehouse_repository.dart';

import '../test/support/fakes.dart';

void main() {
  final env = Platform.environment;
  test('真实后端只读契约', () async {
    final session = Session(ApiClient(env['LIVE_URL']!), MemoryVault());
    await session.login(
      env['LIVE_TENANT'] ?? 'single',
      env['LIVE_USER']!,
      env['LIVE_PASS']!,
    );
    print(
      '登录: ${session.name} 业务可用=${session.businessAvailable} 权限数=${session.permissions.length}',
    );
    try {
      final warehouses = await WarehouseRepository(session).enabled();
      print('仓库: ${warehouses.length}');
    } catch (e) {
      print('仓库失败: $e');
    }
    for (final spec in documents) {
      try {
        final page = await DocumentRepository(session).list(spec, spec.query());
        final rows = (page['records'] as List).cast<Json>();
        final first = rows.isEmpty ? null : rows.first;
        print(
          '${spec.key}: total=${asInt(page['total'])} 首行单号=${first?[spec.number]} 状态=${first == null ? '-' : spec.statusLabel(first['status'])}(${first?['status']})',
        );
      } catch (e) {
        print('${spec.key}: 失败 $e');
      }
    }
    final notes =
        await session.api.call(
              '/sys/notification',
              query: {'pageNum': 1, 'pageSize': 20},
            )
            as Json;
    print(
      '通知: total=${asInt(notes['total'])} types=${(notes['records'] as List).map((e) => e['businessType']).toSet()}',
    );
    print(
      '未读: ${asInt(await session.api.call('/sys/notification/unread/count'))}',
    );
    final convs = await session.api.call('/ai/conversation') as List;
    print('AI会话: ${convs.length}');
    session.dispose();
  });
}
