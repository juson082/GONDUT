import 'dart:math' as math;
import 'package:flutter/material.dart';

/// An unruled sheet shared by the note, handwriting and tree views.
class PaperSurface extends StatelessWidget {
  const PaperSurface({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const corners = BorderRadius.all(Radius.circular(4));
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 5, 12, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: corners,
        border: Border.all(
          color: scheme.onSurface.withValues(alpha: .07),
          width: .7,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.onSurface.withValues(alpha: .10),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: scheme.onSurface.withValues(alpha: .035),
            blurRadius: 2,
            offset: const Offset(1, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: corners,
        child: CustomPaint(
          painter: _PaperGrain(scheme.onSurface),
          foregroundPainter: _PaperOutline(scheme.onSurface),
          child: child,
        ),
      ),
    );
  }
}

class _PaperGrain extends CustomPainter {
  const _PaperGrain(this.ink);
  final Color ink;
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(37);
    final paint = Paint()
      ..color = ink.withValues(alpha: .045)
      ..strokeWidth = .5
      ..strokeCap = StrokeCap.round;
    final count = (size.width * size.height / 105).round().clamp(0, 3800);
    for (var i = 0; i < count; i++) {
      final point = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      canvas.drawLine(
        point,
        point +
            Offset(
              .4 + random.nextDouble() * 1.8,
              (random.nextDouble() - .5) * .7,
            ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PaperGrain oldDelegate) =>
      oldDelegate.ink != ink;
}

class _PaperOutline extends CustomPainter {
  const _PaperOutline(this.ink);
  final Color ink;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final paint = Paint()
      ..color = ink.withValues(alpha: .20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .75
      ..strokeCap = StrokeCap.round;
    final outline = Path()
      ..moveTo(5, 2)
      ..cubicTo(w * .27, .5, w * .65, 3.5, w - 5, 2)
      ..quadraticBezierTo(w - 1, 2, w - 2, 6)
      ..cubicTo(w - 3.5, h * .32, w - .5, h * .68, w - 2, h - 5)
      ..quadraticBezierTo(w - 2, h - 2, w - 6, h - 2)
      ..cubicTo(w * .7, h - 3.5, w * .3, h - .5, 5, h - 2)
      ..quadraticBezierTo(2, h - 2, 2, h - 6)
      ..cubicTo(.5, h * .7, 3.5, h * .3, 2, 6)
      ..quadraticBezierTo(2, 2, 5, 2);
    canvas.drawPath(outline, paint);
  }

  @override
  bool shouldRepaint(covariant _PaperOutline oldDelegate) =>
      oldDelegate.ink != ink;
}
