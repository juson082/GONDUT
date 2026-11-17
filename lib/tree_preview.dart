import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'plant_lines.dart';
import 'plant_layout.dart';

/// Draws the actual tree positions and links, without changing saved data.
class TreePreview extends StatelessWidget {
  const TreePreview({super.key, required this.items});
  final List<Map<String, Object?>> items;
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _PreviewPainter(
        items,
        Theme.of(context).colorScheme.outline,
        Theme.of(context).textTheme.bodyMedium!,
      ),
      child: const SizedBox.expand(),
    ),
  );
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.items, this.color, this.textStyle);
  final List<Map<String, Object?>> items;
  final Color color;
  final TextStyle textStyle;
  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty || size.isEmpty) return;
    final positions = placePlantNodes(
      items,
      layoutPlant(items, {}),
      const Offset(2800, 2800),
    );
    positions.remove(0);
    final bounds = positions.values;
    final left = bounds.map((p) => p.dx).reduce(math.min) - 18;
    final top = bounds.map((p) => p.dy).reduce(math.min) - 18;
    final right = bounds.map((p) => p.dx + 174).reduce(math.max) + 18;
    final bottom = bounds.map((p) => p.dy + 86).reduce(math.max) + 18;
    final scale = math.min(
      size.width / (right - left),
      size.height / (bottom - top),
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(
      (size.width - (right - left) * scale) / 2 - left * scale,
      (size.height - (bottom - top) * scale) / 2 - top * scale,
    );
    canvas.scale(scale);
    TreeLines(
      items,
      positions,
      color,
      zoomScale: scale,
    ).paint(canvas, const Size(6000, 6000));
    for (final item in items) {
      final pos = positions[item['id']];
      if (pos == null) continue;
      final text = TextPainter(
        text: TextSpan(
          text: (item['title'] as String? ?? '').isNotEmpty
              ? item['title'] as String
              : item['text'] as String? ?? '',
          style: textStyle.copyWith(color: color),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: 150);
      text.paint(
        canvas,
        pos + Offset((174 - text.width) / 2, (86 - text.height) / 2),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter old) =>
      old.items != items || old.color != color || old.textStyle != textStyle;
}
