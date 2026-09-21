import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/mundas_colors.dart';

class DotBackground extends StatelessWidget {
  final Widget child;
  const DotBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _DotPainter(),
        child: child,
      );
}

class _DotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = MundasColors.primary.withOpacity(.09);
    const gap = 24.0;
    for (double y = 8; y < math.min(size.height, 310); y += gap) {
      for (double x = 10; x < size.width; x += gap) {
        final drift = ((y / gap).round().isOdd) ? gap / 2 : 0;
        canvas.drawCircle(Offset((x + drift) % size.width, y), 2.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
