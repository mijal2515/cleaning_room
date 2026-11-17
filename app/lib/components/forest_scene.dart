import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Static, resolution-independent woodland. No network assets or animation loop.
class ForestScene extends StatelessWidget {
  const ForestScene({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: ExcludeSemantics(
              child: RepaintBoundary(child: CustomPaint(painter: _ForestPainter())),
            ),
          ),
          child,
        ],
      );
}

class _ForestPainter extends CustomPainter {
  const _ForestPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // A portrait illustration is cropped horizontally on narrow devices.
    canvas.save();
    canvas.scale(size.width / 390, size.height / 844);
    const bounds = Rect.fromLTWH(0, 0, 390, 844);
    canvas.drawRect(bounds, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF8DAE8D), Color(0xFFE9EED5), Color(0xFFB8C99C)],
      stops: [0, .46, 1],
    ).createShader(bounds));

    // Distant tree silhouettes: pale, narrow and partially lost in mist.
    for (var i = 0; i < 12; i++) {
      final x = i * 39.0 - 20;
      final top = (i % 3) * 23.0;
      final paint = Paint()..color = const Color(0xFF688D72).withValues(alpha: .22);
      canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(x, top, 9.0 + i % 4 * 2, 490), const Radius.circular(8)), paint);
      canvas.drawOval(Rect.fromCenter(center: Offset(x + 8, top + 70), width: 95, height: 145), paint);
    }
    final light = Path()..moveTo(265, 0)..lineTo(345, 0)
      ..lineTo(180, 650)..lineTo(40, 650)..close();
    canvas.drawPath(light, Paint()..color = const Color(0xFFFFF8CE).withValues(alpha: .21));
    canvas.drawOval(const Rect.fromLTWH(36, 200, 320, 500), Paint()
      ..shader = const RadialGradient(colors: [Color(0xFFF8F7E6), Color(0x00F8F7E6)])
          .createShader(const Rect.fromLTWH(36, 200, 320, 500)));

    // Foreground trunks frame the clearing, never crossing the form centre.
    for (final right in [false, true]) {
      canvas.save();
      if (right) { canvas.translate(390, 0); canvas.scale(-1, 1); }
      final trunk = Path()..moveTo(0, 0)..lineTo(53, 0)
        ..cubicTo(32, 200, 30, 460, 59, 738)
        ..lineTo(0, 786)..close();
      canvas.drawPath(trunk, Paint()..color = const Color(0xFF53694B));
      final bark = Path()..moveTo(22, 40)..cubicTo(5, 260, 18, 500, 31, 690);
      canvas.drawPath(bark, Paint()..color = const Color(0xFF86926A)
        ..style = PaintingStyle.stroke..strokeWidth = 3);
      canvas.drawPath(Path()..moveTo(28, 173)..quadraticBezierTo(70, 115, 106, 91),
        Paint()..color = const Color(0xFF53694B)..style = PaintingStyle.stroke
          ..strokeWidth = 13..strokeCap = StrokeCap.round);
      canvas.restore();
    }
    // Layered canopy with warm openings between leaves.
    for (var row = 0; row < 3; row++) {
      for (var i = 0; i < 7; i++) {
        final x = i * 70.0 - 25 + row * 12;
        final y = -35.0 + row * 26 - math.sin(i * 1.7) * 19;
        canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 145, height: 120),
          Paint()..color = [const Color(0xFF244D39), const Color(0xFF386347), const Color(0xFF547C50)][row]);
      }
    }
    final ground = Path()..moveTo(0, 755)..quadraticBezierTo(95, 710, 180, 769)
      ..quadraticBezierTo(280, 710, 390, 748)..lineTo(390, 844)..lineTo(0, 844)..close();
    canvas.drawPath(ground, Paint()..color = const Color(0xFF719362));
    final stream = Path()..moveTo(245, 735)..cubicTo(190, 767, 310, 786, 180, 844)
      ..lineTo(300, 844)..cubicTo(345, 782, 227, 772, 260, 735)..close();
    canvas.drawPath(stream, Paint()..color = const Color(0xFFACCBC0));
    for (var i = 0; i < 4; i++) {
      canvas.drawLine(Offset(234 + i * 8, 775 + i * 15), Offset(258 + i * 8, 775 + i * 15),
        Paint()..color = const Color(0xFFDCE9CE)..strokeWidth = 2..strokeCap = StrokeCap.round);
    }
    for (final x in [12.0, 42.0, 78.0, 322.0, 355.0, 382.0]) {
      final y = 800 + math.sin(x) * 17;
      for (var j = -2; j <= 2; j++) {
        final stem = Path()..moveTo(x, y + 30)..quadraticBezierTo(x + j * 13, y - 10, x + j * 17, y - 35);
        canvas.drawPath(stem, Paint()..color = const Color(0xFF315D43)
          ..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round);
        canvas.drawOval(Rect.fromCenter(center: Offset(x + j * 10, y - 3), width: 15, height: 8),
          Paint()..color = const Color(0xFF446F47));
      }
    }
    // A few sunlit pollen specks, deliberately static for reduced motion.
    for (final point in [const Offset(83, 180), const Offset(313, 223), const Offset(284, 142), const Offset(60, 642)]) {
      canvas.drawCircle(point, 2, Paint()..color = const Color(0xFFFFF1B3));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ForestPainter oldDelegate) => false;
}
