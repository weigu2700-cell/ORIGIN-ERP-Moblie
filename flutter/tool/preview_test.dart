// 仅用于视觉核对：数据来自测试夹具，正式 App 不包含演示身份。
import 'dart:io';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origin_mobile/main.dart';
import 'package:origin_mobile/ui/theme.dart';

import '../test/support/fakes.dart';
import 'readme_boards.dart';

void main() {
  testWidgets('导出工作台预览', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    final ios = Platform.environment['PREVIEW_IOS'] == '1';
    if (ios) {
      // 模拟带灵动岛的 iPhone 安全区。
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      final systemFont = File(
        Platform.environment['PREVIEW_FONT'] ??
            '/System/Library/Fonts/STHeiti Light.ttc',
      );
      if (!await systemFont.exists()) {
        throw StateError('预览需要中文字体，请设置 PREVIEW_FONT 为本机中文字体路径');
      }
      if (await systemFont.exists()) {
        final bytes = ByteData.sublistView(await systemFont.readAsBytes());
        for (final family in [
          'Roboto',
          'Ahem',
          '.AppleSystemUIFont',
          'CupertinoSystemText',
          'CupertinoSystemDisplay',
          'ReadmeFont',
        ]) {
          final loader = FontLoader(family)..addFont(Future.value(bytes));
          await loader.load();
        }
      }
      final iconFont = File(
        'build/unit_test_assets/fonts/MaterialIcons-Regular.otf',
      );
      if (await iconFont.exists()) {
        final loader = FontLoader('MaterialIcons')
          ..addFont(
            Future.value(ByteData.sublistView(await iconFont.readAsBytes())),
          );
        await loader.load();
      }
    });
    final api = FixtureApi();
    final base = api.handler;
    api.handler = null;
    // 测试环境没有相机插件，给扫码插件的通道一个空实现。
    final messenger = tester.binding.defaultBinaryMessenger;
    for (final name in ['method', 'deviceOrientation']) {
      messenger.setMockMethodCallHandler(
        MethodChannel('dev.steenbakker.mobile_scanner/scanner/$name'),
        (_) async => null,
      );
    }
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.steenbakker.mobile_scanner/scanner/event'),
      (_) async => null,
    );
    final session = authenticatedSession(api);
    final key = GlobalKey();
    // AppBar 的独立标题样式没有字体继承；仅预览注入已加载的中文字体。
    final theme = AppTokens.theme;
    final previewTheme = theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
          fontFamily: 'Roboto',
        ),
      ),
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: OriginApp(session, theme: previewTheme, chatFactory: testChat),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    Future<void> shot(String name) async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('output/preview${ios ? '-ios' : ''}/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    await shot('workspace');
    final nav = find.byType(Navigator);
    Future<void> back() async {
      tester.state<NavigatorState>(nav.last).pop();
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('扫一扫').first);
    await tester.pump(const Duration(seconds: 1)); // 扫描线动画不会静止
    await tester.pump(const Duration(seconds: 1));
    await shot('scan');
    tester.state<NavigatorState>(nav.last).pop();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('库存查询').first);
    await tester.pumpAndSettle();
    await shot('inventory');
    await tester.tap(find.text('精密轴承').first);
    await tester.pumpAndSettle();
    await shot('inventory-detail');
    await back();
    await back();
    await tester.tap(find.text('生产订单').first);
    await tester.pumpAndSettle();
    await shot('orders');
    await tester.tap(find.text('伺服驱动器').first);
    await tester.pumpAndSettle();
    await shot('order-detail');
    await tester.tap(find.text('登记报工'));
    await tester.pumpAndSettle();
    await shot('report-form');
    await back();
    await back();
    await back();
    await tester.tap(find.text('消息'));
    await tester.pumpAndSettle();
    await shot('messages');
    await tester.tap(find.text('系统通知'));
    await tester.pumpAndSettle();
    await shot('messages-system');
    tester.state<NavigatorState>(find.byType(Navigator).last).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI助手'));
    await tester.pumpAndSettle();
    await shot('assistant');
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await shot('assistant-drawer');
    await tester.tap(find.text('本周库存预警汇总'));
    await tester.pumpAndSettle();
    await shot('assistant-chat');
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await shot('me');
    await tester.tap(find.text('工作台'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部 ›').first);
    await tester.pumpAndSettle();
    await shot('apps');
    await session.logout();
    await tester.pumpAndSettle();
    await shot('login');
    await tester.runAsync(() => renderReadmeBoards(ios: ios));
    expect(base, isNull);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
    debugDefaultTargetPlatformOverride = null;
  });
}
