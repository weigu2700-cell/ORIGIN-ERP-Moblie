import 'package:flutter/material.dart';

import 'package:origin_mobile/ui/theme.dart';

/// 原点智造标志：与 Web 管理端 origin-logo.svg 相同的几何图形（64×64 视口）。
class OriginLogo extends StatelessWidget {
  final double size;

  /// 深色背景上使用较亮的六边形底色，避免与背景融在一起。
  final bool onDark;
  const OriginLogo({super.key, this.size = 32, this.onDark = false});
  @override
  Widget build(BuildContext context) => Semantics(
    label: '原点智造',
    image: true,
    child: SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LogoPainter(onDark)),
    ),
  );
}

class _LogoPainter extends CustomPainter {
  final bool onDark;
  _LogoPainter(this.onDark);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 64, size.height / 64);
    canvas.drawPath(
      Path()
        ..moveTo(32, 5)
        ..lineTo(55, 18)
        ..lineTo(55, 46)
        ..lineTo(32, 59)
        ..lineTo(9, 46)
        ..lineTo(9, 18)
        ..close(),
      Paint()..color = onDark ? const Color(0xFF3A6D8A) : AppTokens.brandMark,
    );
    final amber = Paint()
      ..color = AppTokens.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(10, 18)
        ..lineTo(32, 31)
        ..lineTo(54, 18)
        ..moveTo(32, 31)
        ..lineTo(32, 58),
      amber,
    );
    canvas.drawPath(
      Path()
        ..moveTo(21, 12)
        ..lineTo(44, 25)
        ..lineTo(44, 37)
        ..lineTo(32, 44)
        ..lineTo(20, 37)
        ..lineTo(20, 25)
        ..lineTo(32, 18),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(
      const Offset(32, 31),
      4,
      Paint()..color = AppTokens.accent,
    );
    canvas.drawCircle(
      const Offset(32, 31),
      4,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.onDark != onDark;
}
