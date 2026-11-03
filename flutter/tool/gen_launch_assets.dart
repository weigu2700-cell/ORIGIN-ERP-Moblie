// 从 OriginLogo 生成各平台启动图。用法：./tool/flutterw test tool/gen_launch_assets.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origin_mobile/ui/brand.dart';

Future<void> render(
  WidgetTester tester,
  String path, {
  required int pixels,
  required double logoFraction,
}) async {
  final key = GlobalKey();
  tester.view.physicalSize = Size(pixels.toDouble(), pixels.toDouble());
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: key,
        child: Center(
          child: OriginLogo(size: pixels * logoFraction, onDark: true),
        ),
      ),
    ),
  );
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  testWidgets('生成启动图', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const ios = 'ios/Runner/Assets.xcassets/LaunchImage.imageset';
    await render(tester, '$ios/LaunchImage.png', pixels: 120, logoFraction: 1);
    await render(
      tester,
      '$ios/LaunchImage@2x.png',
      pixels: 240,
      logoFraction: 1,
    );
    await render(
      tester,
      '$ios/LaunchImage@3x.png',
      pixels: 360,
      logoFraction: 1,
    );
    const res = 'android/app/src/main/res';
    await render(
      tester,
      '$res/drawable-nodpi/launch_logo.png',
      pixels: 360,
      logoFraction: 1,
    );
    // Android 12+ 启动图标画布 960px，图形需落在中央 2/3 圆内。
    await render(
      tester,
      '$res/drawable-nodpi/splash_icon.png',
      pixels: 960,
      logoFraction: 0.5,
    );
  });

  testWidgets('生成应用图标母版', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    tester.view.physicalSize = const Size(1024, 1024);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: key,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF18384B), Color(0xFF245B78)],
              ),
            ),
            child: const Center(child: OriginLogo(size: 640, onDark: true)),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('output/app-icon-1024.png').parent.create(recursive: true);
      await File(
        'output/app-icon-1024.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  });
}
