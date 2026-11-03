import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:origin_mobile/ui/common.dart';
import 'package:origin_mobile/ui/theme.dart';

/// 扫一扫：全屏相机取景，底部手工输入兜底。只返回识别到的编码，不执行任何业务。
class ScanPage extends StatefulWidget {
  final String? expected;
  const ScanPage({super.key, this.expected});
  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final camera = MobileScannerController(autoStart: false);
  final input = TextEditingController();
  late final AnimationController sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);
  bool accepted = false, torch = false, cameraFailed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => startCamera());
  }

  Future<void> startCamera() async {
    try {
      await camera.start();
      if (mounted) setState(() => cameraFailed = false);
    } catch (_) {
      if (mounted) setState(() => cameraFailed = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!accepted) startCamera();
    } else {
      camera.stop();
      if (mounted) setState(() => torch = false);
    }
  }

  void accept(String? raw) {
    if (accepted || raw == null || raw.trim().isEmpty) return;
    final code = raw.trim();
    if (widget.expected != null && code != widget.expected) {
      HapticFeedback.heavyImpact();
      feedback(context, '编码不匹配，请核对物料后重新扫描');
      return;
    }
    accepted = true;
    HapticFeedback.mediumImpact();
    camera.stop();
    Navigator.pop(context, code);
  }

  Future<void> toggleTorch() async {
    try {
      await camera.toggleTorch();
      if (mounted) setState(() => torch = !torch);
    } catch (_) {
      if (mounted) feedback(context, '当前设备不支持闪光灯');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    sweep.dispose();
    camera.dispose();
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final frame = (size.shortestSide * 0.68).clamp(200.0, 300.0);
    final frameTop = (size.height * 0.2).clamp(110.0, 220.0);
    final rect = Rect.fromLTWH(
      (size.width - frame) / 2,
      frameTop,
      frame,
      frame,
    );
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('扫一扫', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: torch ? '关闭闪光灯' : '打开闪光灯',
            onPressed: cameraFailed ? null : toggleTorch,
            icon: Icon(torch ? Icons.flash_on : Icons.flash_off),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (!cameraFailed)
            MobileScanner(
              controller: camera,
              onDetect: (capture) {
                for (final item in capture.barcodes) {
                  if (item.rawValue != null) {
                    accept(item.rawValue);
                    break;
                  }
                }
              },
              errorBuilder: (context, error) => const SizedBox.shrink(),
            ),
          CustomPaint(painter: _FramePainter(rect, sweep)),
          Positioned(
            left: 24,
            right: 24,
            top: rect.bottom + 20,
            child: Text(
              cameraFailed
                  ? '相机不可用或权限被拒绝，请在下方手工输入编码'
                  : widget.expected == null
                  ? '将条码或二维码放入框内，自动识别'
                  : '请扫描物料编码 ${widget.expected} 进行核对',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  16 + MediaQuery.paddingOf(context).bottom,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '手工输入编码',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '支持粘贴与外接扫码枪，保留前导零和完整编码',
                      style: TextStyle(fontSize: 12.5, color: AppTokens.muted),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: input,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              hintText: '物料编码',
                              isDense: true,
                            ),
                            onSubmitted: accept,
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(72, 48),
                          ),
                          onPressed: () => accept(input.text),
                          child: const Text('确定'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  final Rect frame;
  final Animation<double> sweep;
  _FramePainter(this.frame, this.sweep) : super(repaint: sweep);
  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(frame, const Radius.circular(20));
    final mask = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      mask,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    final corner = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const len = 26.0;
    for (final c in [
      (frame.topLeft, 1.0, 1.0),
      (frame.topRight, -1.0, 1.0),
      (frame.bottomLeft, 1.0, -1.0),
      (frame.bottomRight, -1.0, -1.0),
    ]) {
      final p = c.$1;
      canvas.drawLine(p, p.translate(len * c.$2, 0), corner);
      canvas.drawLine(p, p.translate(0, len * c.$3), corner);
    }
    final y = frame.top + 12 + (frame.height - 24) * sweep.value;
    canvas.drawLine(
      Offset(frame.left + 18, y),
      Offset(frame.right - 18, y),
      Paint()
        ..color = AppTokens.brand
        ..strokeWidth = 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3),
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.frame != frame;
}
