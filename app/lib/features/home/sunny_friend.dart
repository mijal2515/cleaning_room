import 'package:flutter/material.dart';

/// Original watercolor cleaning companion.
class SunnyFriend extends StatelessWidget {
  const SunnyFriend({super.key, this.size = 110});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '웃고 있는 노란 청소 요정',
    image: true,
    child: SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/illustrations/sunny_watercolor.png',
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      ),
    ),
  );
}

class WaveRule extends StatelessWidget {
  const WaveRule({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 24,
    width: double.infinity,
    child: CustomPaint(
      painter: _WavePainter(Theme.of(context).colorScheme.outline),
    ),
  );
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(0, 12);
    for (double x = 0; x < size.width; x += 80) {
      path.cubicTo(x + 20, -1, x + 20, -1, x + 40, 12);
      path.cubicTo(x + 60, 25, x + 60, 25, x + 80, 12);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: .55)
        ..strokeWidth = .8
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.color != color;
}
