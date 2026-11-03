import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:origin_mobile/data/document_repository.dart';
import 'package:origin_mobile/core/api.dart';
import 'package:origin_mobile/core/session.dart';
import 'package:origin_mobile/domain/documents.dart';
import 'package:origin_mobile/domain/quantity.dart';
import 'package:origin_mobile/domain/notification_targets.dart';

import 'support/fakes.dart';

import 'package:origin_mobile/data/warehouse_repository.dart';

void main() {
  test('仓库使用枚举名并加载后续分页', () async {
    final api = FixtureApi();
    final session = authenticatedSession(api);
    api.handler = (path, method, query, body) async {
      expect(query['status'], 'ENABLE');
      final page = query['page'] as int;
      return {
        'records': [
          {'id': '$page', 'name': '仓库$page'},
        ],
        'total': 2,
      };
    };
    expect((await WarehouseRepository(session).enabled()).length, 2);
    session.dispose();
  });

  test('通知仅跳转真实且受支持的业务类型', () {
    expect(notificationTarget('PRODUCTION_PICKING_READY')?.key, 'picking');
    expect(notificationTarget('PURCHASE_ORDER_APPROVED'), isNull);
    expect(notificationTarget(null), isNull);
  });
  test('十进制数量按万分位比较，并保留前导零', () {
    expect(validateQuantities('0.3', '0.1', '0.2'), isNull);
    expect(validateQuantities('1', '0.9999', '0.0002'), isNotNull);
    expect(validateQuantities('1.00001', '0', '0'), isNotNull);
    expect(validateQuantities('0', '0', '0'), isNotNull);
    expect(quantityUnits('0001.20'), BigInt.from(12000));
    expect(quantityUnits('-1'), isNull);
    expect(quantityUnits('1e3'), isNull);
  });
  test('成品入库筛选必须使用枚举名', () {
    final spec = documents.firstWhere((d) => d.key == 'warehousing');
    expect(spec.query(status: 1)['status'], 'APPROVED');
    expect(
      documents
          .firstWhere((d) => d.key == 'reports')
          .query(status: 1)['status'],
      1,
    );
  });
  test('SSE 在 UTF8、CRLF 的任意分片位置都能解码', () async {
    final bytes = utf8.encode(
      ': comment\r\ndata: {"type":"CONTENT","content":"生产中"}\r\n\r\ndata: [DONE]\r\n\r\n',
    );
    final chunks = bytes.map((b) => <int>[b]);
    final events = await decodeSse(Stream.fromIterable(chunks)).toList();
    expect(jsonDecode(events.first)['content'], '生产中');
    expect(events.last, '[DONE]');
  });
  test('SSE 多行 data、CR 和 EOF', () async {
    expect(
      await decodeSse(
        Stream.value(utf8.encode('data: a\rdata: b\r\rdata: tail')),
      ).toList(),
      ['a\nb', 'tail'],
    );
  });
  test('组织业务门禁优先于管理员角色', () {
    final session = Session(
      ApiClient('https://erp.example/api'),
      MemoryVault(),
    );
    session.profile = {
      'roles': [
        {'roleCode': 'ADMIN'},
      ],
    };
    session.permissions = {'prd:report:add'};
    expect(session.can('prd:report:add'), isFalse);
    session.businessAvailable = true;
    expect(session.can('prd:report:add'), isTrue);
    session.dispose();
  });
  test('迟到响应不能穿过身份边界', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final api = ApiClient('http://127.0.0.1:${server.port}');
    final future = api.call('/slow');
    final expectation = expectLater(future, throwsA(isA<SessionChanged>()));
    final request = await server.first;
    api.boundary('new-identity');
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode({
        'code': 200,
        'msg': '成功',
        'data': {'old': true},
      }),
    );
    try {
      await request.response.close();
    } catch (_) {}
    await expectation;
    api.boundary();
    await server.close(force: true);
  });
  test('领料 POST 仅携带 query ID，不发送数量', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final session = Session(
      ApiClient('http://127.0.0.1:${server.port}'),
      MemoryVault(),
    );
    session.businessAvailable = true;
    session.permissions = {
      'production:picking:get',
      'production:picking:confirm',
    };
    final spec = documents.firstWhere((d) => d.key == 'picking');
    final handled = <Future<void>>[];
    server.listen((request) {
      handled.add(() async {
        request.response.headers.contentType = ContentType.json;
        if (request.method == 'GET') {
          request.response.write(
            jsonEncode({
              'code': 200,
              'msg': 'ok',
              'data': {'id': '9007199254740993123', 'status': 1},
            }),
          );
        } else {
          expect(request.method, 'POST');
          expect(request.uri.path, '/prd/picking/confirm');
          expect(request.uri.queryParameters['id'], '9007199254740993123');
          expect(await utf8.decoder.bind(request).join(), '');
          request.response.write(
            jsonEncode({'code': 200, 'msg': 'ok', 'data': null}),
          );
        }
        await request.response.close();
      }());
    });
    await DocumentRepository(
      session,
    ).execute(spec, '9007199254740993123', spec.actions.last);
    await Future.wait(handled);
    session.api.boundary();
    await server.close(force: true);
    session.dispose();
  });
  test('单据状态变化时不能发出写请求', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var writes = 0;
    server.listen((r) async {
      if (r.method != 'GET') writes++;
      r.response.headers.contentType = ContentType.json;
      r.response.write(
        jsonEncode({
          'code': 200,
          'msg': 'ok',
          'data': {'status': 2},
        }),
      );
      await r.response.close();
    });
    final session =
        Session(ApiClient('http://127.0.0.1:${server.port}'), MemoryVault())
          ..businessAvailable = true
          ..permissions = {
            'production:picking:get',
            'production:picking:confirm',
          };
    final spec = documents.firstWhere((d) => d.key == 'picking');
    await expectLater(
      DocumentRepository(session).execute(spec, '1', spec.actions.last),
      throwsA(isA<ApiFailure>()),
    );
    expect(writes, 0);
    session.api.boundary();
    await server.close(force: true);
    session.dispose();
  });
}
