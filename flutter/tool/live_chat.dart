// 聊天真实接口联调：用 HttpChatApi + ChatStore 走完整流程（会写入测试数据）。
// 用法：LIVE_URL=http://localhost:8080 LIVE_USER=.. LIVE_PASS=.. ./tool/flutterw test tool/live_chat.dart
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:origin_mobile/core/api.dart';
import 'package:origin_mobile/core/chat_store.dart';
import 'package:origin_mobile/core/session.dart';

import '../test/support/fakes.dart';

String uuid() {
  final r = Random();
  String h(int n) =>
      List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
  return '${h(8)}-${h(4)}-4${h(3)}-8${h(3)}-${h(12)}';
}

void main() {
  final env = Platform.environment;
  test('聊天真实接口全流程', () async {
    final session = Session(ApiClient(env['LIVE_URL']!), MemoryVault());
    await session.login(
      env['LIVE_TENANT'] ?? 'single',
      env['LIVE_USER']!,
      env['LIVE_PASS']!,
    );
    final chat = ChatStore(session);
    addTearDown(() {
      chat.dispose();
      session.dispose();
    });
    void step(String s) => stderr.writeln('· $s');

    await chat.bootstrap();
    expect(chat.disabledReason, isNull, reason: chat.disabledReason);
    step(
      'bootstrap ok；会话 ${chat.list.length}，配置上限 ${chat.config?.maxGroupMembers}',
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    step('ChatStore 连接状态 ${chat.connection}');
    expect(chat.connection.name, 'online');
    final contacts = await chat.api.contacts();
    step('联系人 ${contacts.map((c) => c.displayName).join('、')}');
    expect(contacts.length, greaterThanOrEqualTo(2));

    final id = await chat.createGroup(
      '联调测试群',
      contacts.take(2).map((c) => c.userId).toList(),
    );
    step(
      '建群 $id v${chat.conversations[id]!.version} 成员数 ${chat.conversations[id]!.memberCount}',
    );
    expect(chat.conversations[id]!.myRole, 'OWNER');

    await chat.sendText(id, '联调消息 1');
    var rows = chat.timelines[id]!;
    step(
      '发送后时间线 ${rows.length} 条，本地待发 ${rows.where((m) => m.local != null).length}',
    );
    expect(rows.where((m) => m.text == '联调消息 1'), hasLength(1));
    expect(rows.any((m) => m.local != null), isFalse);

    final history = await chat.api.history(id);
    step(
      '历史 ${history.records.length} 条，末条 seq=${history.records.last.seq} sys=${history.records.first.systemText}',
    );
    final members = await chat.api.members(id);
    step('成员 ${members.map((m) => '${m.displayName}/${m.role}').join('、')}');
    expect(members.length, 3);

    // 幂等：相同 clientMessageId 重发返回同一条
    final first = rows.firstWhere((m) => m.text == '联调消息 1');
    final again = await chat.api.send(
      id,
      clientMessageId: first.clientMessageId,
      type: 'TEXT',
      text: '联调消息 1',
    );
    expect(again.id, first.id);
    step('幂等重发返回同一条 ${again.id}');
    await expectLater(
      chat.api.send(
        id,
        clientMessageId: first.clientMessageId,
        type: 'TEXT',
        text: '内容不同',
      ),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.error,
          'error',
          'IDEMPOTENCY_CONFLICT',
        ),
      ),
    );
    step('相同标识不同内容 → IDEMPOTENCY_CONFLICT');

    await chat.rename(id, '联调测试群（改名）');
    expect(chat.conversations[id]!.name, '联调测试群（改名）');
    step('改名成功 v${chat.conversations[id]!.version}');
    chat.conversations[id]!.version = 1;
    await expectLater(
      chat.rename(id, '过期版本'),
      throwsA(
        isA<ApiFailure>().having((e) => e.error, 'error', 'VERSION_CONFLICT'),
      ),
    );
    step('过期版本 → VERSION_CONFLICT，已刷新到 v${chat.conversations[id]!.version}');

    await expectLater(
      chat.leave(id),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.error,
          'error',
          'OWNER_TRANSFER_REQUIRED',
        ),
      ),
    );
    step('群主直接退群 → OWNER_TRANSFER_REQUIRED');

    final read = await chat.api.markRead(id, chat.conversations[id]!.lastSeq);
    step('已读 lastReadSeq=${read.lastReadSeq} unread=${read.unreadCount}');

    final ticket = await chat.api.issueTicket(
      '3f0c6d3e-2f6b-4d3a-9d6e-0a7a5b3c2e11',
    );
    step('WS 票据路径 ${ticket.path.split('?').first} 心跳 ${ticket.heartbeat}s');
    final events = await chat.api.syncEvents('0');
    step(
      '同步事件 ${events.records.length} 条: ${events.records.map((e) => e.type).toSet()}',
    );

    // 真实 WebSocket：连上后应收到 SESSION.READY，再发一条消息应推送 MESSAGE.CREATED
    final uri = Uri.parse(env['LIVE_URL']!);
    final ws = await WebSocket.connect(
      'ws://${uri.host}:${uri.port}${ticket.path}',
    );
    final frames = <String>[];
    final sub = ws.listen((d) => frames.add('$d'));
    await Future<void>.delayed(const Duration(seconds: 1));
    step(
      'WS 首帧 ${frames.isEmpty ? '无' : frames.first.substring(0, frames.first.length.clamp(0, 140))}',
    );
    expect(frames.any((f) => f.contains('SESSION.READY')), isTrue);
    await chat.api.send(
      id,
      clientMessageId: uuid(),
      type: 'TEXT',
      text: '联调消息 WS',
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    step(
      'WS 事件 ${frames.where((f) => f.contains('eventId')).map((f) => RegExp(r'"type":"([A-Z.]+)"').firstMatch(f)?.group(1)).toList()}',
    );
    expect(frames.any((f) => f.contains('MESSAGE.CREATED')), isTrue);
    await sub.cancel();
    await ws.close();

    await chat.dissolve(id);
    expect(chat.conversations[id]!.dissolved, isTrue);
    step('解散成功，状态 ${chat.conversations[id]!.status}');
    await chat.sendText(id, '解散后发送');
    final failed = chat.timelines[id]!.where((m) => m.local != null).toList();
    step('解散后发送 → ${failed.isEmpty ? '意外成功' : failed.first.reason}');
    expect(failed, isNotEmpty);
  });
}
