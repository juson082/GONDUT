import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'app_strings.dart';

/// Highlights the real widget below the overlay without repainting it.
class SpotlightTutorial extends StatefulWidget {
  const SpotlightTutorial({
    super.key,
    required this.target,
    required this.message,
    required this.onNext,
    required this.onSkip,
    this.last = false,
    this.radius = 16,
    this.insets = EdgeInsets.zero,
  });
  final GlobalKey target;
  final String message;
  final VoidCallback onNext, onSkip;
  final bool last;
  final double radius;
  final EdgeInsets insets;
  @override
  State<SpotlightTutorial> createState() => _SpotlightTutorialState();
}

class _SpotlightTutorialState extends State<SpotlightTutorial> {
  final GlobalKey overlay = GlobalKey();
  Rect? hole;

  void measure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = widget.target.currentContext?.findRenderObject();
      final parent = overlay.currentContext?.findRenderObject();
      if (target is! RenderBox ||
          parent is! RenderBox ||
          !target.hasSize ||
          !parent.hasSize)
        return;
      final next = widget.insets.deflateRect(
        parent.globalToLocal(target.localToGlobal(Offset.zero)) & target.size,
      );
      if (hole != next) setState(() => hole = next);
    });
  }

  @override
  Widget build(BuildContext context) {
    measure();
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounds =
            hole ??
            Rect.fromCenter(
              center: Offset(
                constraints.maxWidth / 2,
                constraints.maxHeight / 2,
              ),
              width: 0,
              height: 0,
            );
        final topSpace = bounds.top;
        final bottomSpace = constraints.maxHeight - bounds.bottom;
        final placeBelow = bottomSpace >= 205 || bottomSpace > topSpace;
        final panelTop = placeBelow
            ? math.min(bounds.bottom + 14, constraints.maxHeight - 190)
            : math.max(12.0, bounds.top - 190);
        return Stack(
          key: overlay,
          fit: StackFit.expand,
          children: [
            TweenAnimationBuilder<Rect?>(
              tween: RectTween(end: bounds),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              builder: (context, rect, _) => CustomPaint(
                painter: _SpotlightPainter(rect ?? bounds, widget.radius),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              left: 20,
              right: 20,
              top: panelTop.clamp(
                12.0,
                math.max(12.0, constraints.maxHeight - 160),
              ),
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                elevation: 5,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 12, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(context, widget.message),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: widget.onSkip,
                            child: Text(tr(context, '건너뛰기')),
                          ),
                          FilledButton(
                            onPressed: widget.onNext,
                            child: Text(tr(context, widget.last ? '완료' : '다음')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter(this.hole, this.radius);
  final Rect hole;
  final double radius;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(hole, Radius.circular(radius)));
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: .72));
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) =>
      old.hole != hole || old.radius != radius;
}
