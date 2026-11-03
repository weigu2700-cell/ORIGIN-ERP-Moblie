import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origin_mobile/main.dart';
import 'package:origin_mobile/features/report_form.dart';
import 'package:origin_mobile/ui/theme.dart';

import 'support/fakes.dart';

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('工作台在 $width 宽和大字体下不溢出', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final session = authenticatedSession(FixtureApi());
      await tester.pumpWidget(OriginApp(session));
      await tester.pumpAndSettle();
      expect(find.text('搜索应用'), findsOneWidget);
      expect(find.text('库存查询'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    });
  }

  testWidgets('退出销毁已打开的库存查询页面', (tester) async {
    final session = authenticatedSession(FixtureApi());
    await tester.pumpWidget(OriginApp(session));
    await tester.pumpAndSettle();
    await tester.tap(find.text('库存查询'));
    await tester.pumpAndSettle();
    expect(find.text('精密轴承'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '0000');
    expect(find.widgetWithText(TextField, '0000'), findsOneWidget);
    await session.logout();
    await tester.pumpAndSettle();
    expect(find.text('精密轴承'), findsNothing);
    expect(find.text('登录原点智造'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  testWidgets('报工失败保留输入，未保存返回必须确认', (tester) async {
    final api = FixtureApi();
    final session = authenticatedSession(api);
    const order = {
      'id': '1',
      'materialId': '2',
      'materialName': '轴承',
      'productionOrderNo': 'MO-001',
      'warehouseId': '001',
    };
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTokens.theme,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('zh', 'CN')],
        locale: const Locale('zh', 'CN'),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReportFormPage(session, order),
                ),
              ),
              child: const Text('开始报工'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('开始报工'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '本次报工量'), '1');
    await tester.enterText(find.widgetWithText(TextFormField, '合格量'), '2');
    await tester.scrollUntilVisible(
      find.text('保存草稿'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('保存草稿'));
    await tester.pumpAndSettle();
    expect(find.text('合格量与报废量之和不能超过报工量'), findsOneWidget);
    expect(api.requests.where((r) => r == 'POST /prd/report'), isEmpty);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('未保存的数量与备注将丢失。确认返回？'), findsOneWidget);
    await tester.tap(find.text('返回核对'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, '2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
}
