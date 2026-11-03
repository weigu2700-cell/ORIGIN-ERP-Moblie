import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origin_mobile/core/session.dart';
import 'package:origin_mobile/main.dart';

import 'support/fakes.dart';

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('组织门禁在 $width 宽和 1.5 倍字体下可读可退出', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = Session(FixtureApi(), MemoryVault())
        ..status = SessionStatus.authenticated;
      await tester.pumpWidget(OriginApp(session, chatFactory: testChat));
      await tester.pumpAndSettle();
      expect(find.text('组织业务尚未开放'), findsOneWidget);
      expect(find.text('退出并切换组织'), findsOneWidget);
      expect(find.text('工作台'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('退出并切换组织'));
      await tester.pumpAndSettle();
      expect(session.status, SessionStatus.anonymous);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    });
  }
}
