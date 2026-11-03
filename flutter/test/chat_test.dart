import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origin_mobile/core/api.dart';
import 'package:origin_mobile/data/chat/chat_store.dart';
import 'package:origin_mobile/domain/chat.dart';
import 'package:origin_mobile/domain/chat_format.dart';
import 'package:origin_mobile/features/messages/chat_page.dart';
import 'package:origin_mobile/ui/theme.dart';

import 'support/fakes.dart';

Future<ChatStore> loaded() async {
  final session = authenticatedSession(FixtureApi());
  final chat = testChat(session);
  await chat.bootstrap();
  addTearDown(() {
    chat.dispose();
    session.dispose();
  });
  return chat;
}

ChatEvent update(int seq, String conv, String name) => ChatEvent(
  'ev-$seq',
  '$seq',
  'CONVERSATION.UPDATED',
  conv,
  {
    'conversation': {'id': conv, 'type': 'DIRECT', 'name': name, 'version': 1},
  },
);

void main() {
  group('聊天工具', () {
    test('seq 按 BigInt 比较，超出安全整数也正确', () {
      expect(cmpSeq('9007199254740993', '9007199254740992'), 1);
      expect(cmpSeq('9', '10'), -1);
      expect(cmpSeq('', '0'), 0);
    });

    test('时间与预览格式', () {
      final now = DateTime(2026, 11, 3, 12);
      expect(listTime(DateTime(2026, 11, 3, 9, 5), now), '09:05');
      expect(listTime(DateTime(2026, 11, 2, 23), now), '昨天');
      expect(listTime(DateTime(2026, 10, 31), now), '10月31日');
      expect(listTime(DateTime(2025, 12, 31), now), '2025/12/31');
      expect(dayLabel(DateTime(2026, 10, 30), now), startsWith('10月30日 周'));
      expect(fmtBytes(24681), '25 KB');
      expect(fmtBytes(8123456), '8.1 MB');
      String name(String? id) => id == '2' ? '李敏' : '系统';
      final text = ChatMessage(
        id: '1',
        conversationId: 'c',
        clientMessageId: 'x',
        type: 'TEXT',
        seq: '1',
        senderId: '2',
        text: '你好',
      );
      expect(previewOf(text, name, true), '李敏：你好');
      expect(previewOf(text, name, false), '你好');
      expect(previewOf(null, name, false), '暂无消息');
    });

    test('时间线插入日期分隔，未读分割线只出现一次', () {
      final now = DateTime(2026, 11, 3, 12);
      ChatMessage m(String seq, DateTime at) => ChatMessage(
        id: seq,
        conversationId: 'c',
        clientMessageId: seq,
        type: 'TEXT',
        seq: seq,
        text: seq,
        createdAt: at,
      );
      final rows = buildRows(
        [
          m('1', DateTime(2026, 11, 2, 9)),
          m('2', DateTime(2026, 11, 3, 9)),
          m('3', DateTime(2026, 11, 3, 9, 5)),
        ],
        '2',
        now,
      );
      expect(rows.map((r) => r.runtimeType.toString()), [
        'DayRow',
        'MessageRow',
        'DayRow',
        'UnreadRow',
        'MessageRow',
        'MessageRow',
      ]);
      expect((rows.first as DayRow).label, '昨天');
    });
  });

  group('聊天状态', () {
    test('加载会话快照，静音会话不计入总未读', () async {
      final chat = await loaded();
      expect(chat.ready, isTrue);
      expect(chat.list.length, 4);
      expect(chat.conversations['110003']!.muted, isTrue);
      expect(chat.unreadTotal, 2);
    });

    test('进入会话读取历史并上报已读', () async {
      final chat = await loaded();
      await chat.open('110001');
      expect(chat.timelines['110001']!.length, greaterThan(5));
      expect(chat.conversations['110001']!.unreadCount, 0);
    });

    test('发送文本：实时事件与 HTTP 响应合并为同一条', () async {
      final chat = await loaded();
      await chat.open('110002');
      final before = chat.timelines['110002']!.length;
      await chat.sendText('110002', '  下午三点见  ');
      final rows = chat.timelines['110002']!;
      expect(rows.length, before + 1);
      expect(rows.any((m) => m.local != null), isFalse);
      expect(rows.where((m) => m.text == '下午三点见'), hasLength(1));
    });

    test('解散的群发送失败，保留失败状态，可删除', () async {
      final chat = await loaded();
      await chat.open('110005');
      await chat.sendText('110005', '还能发吗');
      final failed = chat.timelines['110005']!.firstWhere(
        (m) => m.local == LocalState.failed,
      );
      expect(failed.reason, contains('解散'));
      chat.discard('110005', failed);
      expect(chat.timelines['110005']!.any((m) => m.local != null), isFalse);
    });

    test('事件按 eventSeq 顺序处理：跳号先缓存，重复丢弃', () async {
      final chat = await loaded();
      final base = int.parse((await chat.api.snapshot()).syncEventSeq);
      chat.applyEvent(update(base + 2, '110002', '第二个'));
      expect(chat.conversations['110002']!.name, '王强');
      chat.applyEvent(update(base + 1, '110002', '第一个'));
      expect(chat.conversations['110002']!.name, '第二个');
      chat.applyEvent(update(base + 1, '110002', '重复'));
      expect(chat.conversations['110002']!.name, '第二个');
    });

    test('文件本地预检：超限、空文件、类型不允许', () async {
      final chat = await loaded();
      expect(chat.precheck('a.pdf', 50000001), contains('上限'));
      expect(chat.precheck('empty.pdf', 0), '文件为空');
      expect(chat.precheck('tool.exe', 10), contains('.exe'));
      expect(chat.precheck('ok.xlsx', 10), isNull);
    });

    test('群管理：版本冲突时刷新并抛出，群主不能直接退群，解散后只读', () async {
      final chat = await loaded();
      await chat.open('110003');
      await Future<void>.delayed(Duration.zero); // 等推送事件落地，避免覆盖下面的过期版本
      chat.conversations['110003']!.version = 1;
      await expectLater(
        chat.rename('110003', '新群名'),
        throwsA(
          isA<ApiFailure>().having((e) => e.error, 'error', 'VERSION_CONFLICT'),
        ),
      );
      expect(chat.conversations['110003']!.version, 7);
      await expectLater(
        chat.leave('110003'),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.error,
            'error',
            'OWNER_TRANSFER_REQUIRED',
          ),
        ),
      );
      await chat.rename('110003', '仓储协同二组');
      expect(chat.conversations['110003']!.name, '仓储协同二组');
      await chat.dissolve('110003');
      expect(chat.conversations['110003']!.dissolved, isTrue);
    });

    test('被撤销的会话从列表和时间线移除并提示', () async {
      final chat = await loaded();
      await chat.open('110002');
      final base = int.parse((await chat.api.snapshot()).syncEventSeq);
      chat.applyEvent(
        ChatEvent(
          'ev-r',
          '${base + 1}',
          'CONVERSATION.REVOKED',
          '110002',
          const {'reason': 'REMOVED'},
        ),
      );
      expect(chat.conversations['110002'], isNull);
      expect(chat.activeId, isNull);
      expect(chat.revokedNotice, isNotNull);
    });
  });

  testWidgets('聊天页展示未读分割线、文件卡片，并能发送消息', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final chat = (await tester.runAsync(loaded))!;
    await tester.pumpWidget(
      MaterialApp(theme: AppTokens.theme, home: ChatPage(chat, '110001')),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('装配一组'), findsOneWidget);
    expect(find.text('以下为新消息'), findsOneWidget);
    expect(find.text('装配排产-11月.xlsx'), findsOneWidget);
    expect(find.text('工单资料已补齐'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '好的，马上处理');
    await tester.pump();
    await tester.tap(find.byTooltip('发送'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('好的，马上处理'), findsOneWidget);
    // 等 Mock 的自动回复计时器触发完再离开页面。
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('已解散的群只读，不显示输入框', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final chat = (await tester.runAsync(loaded))!;
    await tester.pumpWidget(
      MaterialApp(theme: AppTokens.theme, home: ChatPage(chat, '110005')),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('该群已解散，仅可查看历史消息'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
}
