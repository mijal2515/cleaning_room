import 'package:flutter/material.dart';

class MochiBeaver extends StatelessWidget {
  const MochiBeaver({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '말랑한 비버 코치',
        image: true,
        child: SizedBox.square(
          dimension: size,
          child: const RepaintBoundary(child: CustomPaint(painter: _BeaverPainter())),
        ),
      );
}

class _BeaverPainter extends CustomPainter {
  const _BeaverPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 160, size.height / 160);
    void oval(Rect rect, Color color) => canvas.drawOval(rect, Paint()..color = color);
    const fur = Color(0xFFD9B68E);
    const face = Color(0xFF51392B);
    canvas.save();
    canvas.translate(126, 101);
    canvas.rotate(.55);
    oval(const Rect.fromLTWH(-16, -28, 32, 48), const Color(0xFF896349));
    canvas.drawLine(const Offset(-9, -8), const Offset(8, -8), Paint()..color = const Color(0xFFA78161)..strokeWidth = 1.5);
    canvas.restore();
    oval(const Rect.fromLTWH(37, 41, 16, 16), fur);
    oval(const Rect.fromLTWH(97, 41, 16, 16), fur);
    oval(const Rect.fromLTWH(39, 116, 20, 14), fur);
    oval(const Rect.fromLTWH(91, 116, 20, 14), fur);
    canvas.drawRRect(RRect.fromRectAndCorners(const Rect.fromLTWH(22, 45, 106, 80),
      topLeft: const Radius.circular(48), topRight: const Radius.circular(48),
      bottomLeft: const Radius.circular(30), bottomRight: const Radius.circular(30)), Paint()..color = fur);
    oval(const Rect.fromLTWH(51, 89, 3.6, 3.6), face);
    oval(const Rect.fromLTWH(95, 89, 3.6, 3.6), face);
    oval(const Rect.fromLTWH(42, 96, 6, 4), const Color(0xFFE9A68C));
    oval(const Rect.fromLTWH(102, 96, 6, 4), const Color(0xFFE9A68C));
    oval(const Rect.fromLTWH(72, 95, 6, 4), face);
    for (final x in [72.0, 75.2]) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, 100, 3, 3.5), const Radius.circular(1.2)),
        Paint()..color = const Color(0xFFFFF4DE));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BeaverPainter oldDelegate) => false;
}
