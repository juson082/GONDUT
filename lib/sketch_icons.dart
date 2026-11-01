import 'package:flutter/material.dart';

/// Small, readable pen-drawn marks for the main navigation tools.
class SketchIcon extends StatelessWidget {
  const SketchIcon(this.kind, {super.key, this.size = 24});
  final String kind;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _SketchIconPainter(
        kind,
        IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface,
      ),
    ),
  );
}

class _SketchIconPainter extends CustomPainter {
  const _SketchIconPainter(this.kind, this.color);
  final String kind;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final ink = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void line(Path path) => canvas.drawPath(path, ink);
    void dot(double x, double y, [double r = 1.5]) =>
        canvas.drawCircle(Offset(x, y), r, ink);
    switch (kind) {
      case 'tree':
        line(
          Path()
            ..moveTo(12, 20)
            ..cubicTo(12, 15.5, 11.5, 13, 12, 9)
            ..cubicTo(11.9, 6, 11.8, 4.6, 12, 3.5),
        );
        line(
          Path()
            ..moveTo(12, 13)
            ..cubicTo(9, 12.7, 6.8, 11.3, 5.5, 8.5),
        );
        line(
          Path()
            ..moveTo(12, 16)
            ..cubicTo(15.2, 15.8, 17.2, 14.3, 18.5, 11),
        );
        dot(12, 3);
        dot(5, 7);
        dot(19, 9.5);
        dot(12, 21);
      case 'text':
        line(
          Path()
            ..moveTo(3.2, 5.5)
            ..quadraticBezierTo(7, 5.1, 11, 5.4),
        );
        line(
          Path()
            ..moveTo(3, 10)
            ..quadraticBezierTo(6.5, 9.7, 10, 9.9),
        );
        line(
          Path()
            ..moveTo(3.2, 14.5)
            ..quadraticBezierTo(5.6, 14.1, 7.3, 14.3),
        );
        line(
          Path()
            ..moveTo(10.2, 19)
            ..lineTo(12, 15.4)
            ..lineTo(19, 8.4)
            ..quadraticBezierTo(20.1, 7.5, 21, 9)
            ..lineTo(14, 16.3)
            ..close(),
        );
      case 'ink':
        line(
          Path()
            ..moveTo(3, 16)
            ..cubicTo(5, 13, 8, 8, 9, 8)
            ..cubicTo(11, 8, 6, 17, 8, 17)
            ..cubicTo(10, 17, 15, 8, 16, 9)
            ..cubicTo(17.6, 10, 12.8, 17, 15, 17)
            ..cubicTo(17, 17, 19, 14, 21, 14),
        );
      case 'keyboard':
        line(
          Path()
            ..moveTo(4, 7)
            ..quadraticBezierTo(3, 7, 3, 8.5)
            ..lineTo(3, 17)
            ..quadraticBezierTo(3, 18.4, 4.5, 18.4)
            ..lineTo(19.5, 18)
            ..quadraticBezierTo(21, 18, 21, 16.7)
            ..lineTo(21, 8)
            ..quadraticBezierTo(21, 6.7, 19.5, 6.7)
            ..close(),
        );
        for (final x in [6.5, 10.0, 13.5, 17.0]) {
          dot(x, 10, .35);
          dot(x, 13, .35);
        }
        line(
          Path()
            ..moveTo(8, 16)
            ..lineTo(16, 15.8),
        );
      case 'mic':
        line(
          Path()
            ..moveTo(9, 9)
            ..lineTo(9, 5)
            ..cubicTo(9, 1.5, 15, 1.5, 15, 5)
            ..lineTo(15, 9)
            ..cubicTo(15, 12.5, 9, 12.5, 9, 9),
        );
        line(
          Path()
            ..moveTo(6.5, 9)
            ..cubicTo(6.2, 17, 17.7, 17, 17.5, 9),
        );
        line(
          Path()
            ..moveTo(12, 15)
            ..lineTo(12, 20)
            ..moveTo(9, 20)
            ..lineTo(15, 20),
        );
      case 'add':
        line(
          Path()
            ..moveTo(12, 4)
            ..quadraticBezierTo(11.7, 12, 12, 20),
        );
        line(
          Path()
            ..moveTo(4, 12)
            ..quadraticBezierTo(12, 11.7, 20, 12),
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SketchIconPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}
