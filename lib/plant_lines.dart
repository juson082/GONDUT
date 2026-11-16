import 'dart:math' as math;
import 'package:flutter/material.dart';

/// The path is decorative: its endpoints always belong to the stored parent
/// and child and it never alters either node's position or relationship.
class PlantLine {
  const PlantLine(this.parentId, this.childId, this.path, this.depth);
  final int parentId, childId, depth;
  final Path path;
}

/// Returns the same eligible node that a drop will attach to. Root is 0;
/// null means no visible eligible target exists.
int? nearestDropTarget(
  Map<int, Offset> positions,
  Set<int> excluded,
  Offset destination,
) {
  final candidates =
      positions.entries.where((entry) => !excluded.contains(entry.key)).toList()
        ..sort(
          (a, b) => (a.value - destination).distanceSquared.compareTo(
            (b.value - destination).distanceSquared,
          ),
        );
  return candidates.isEmpty ? null : candidates.first.key;
}

List<PlantLine> buildPlantLines(
  List<Map<String, Object?>> items,
  Map<int, Offset> positions, {
  int? previewChildId,
  int? previewParentId,
}) {
  if (previewChildId != null && previewParentId != null) {
    items = [
      for (final item in items)
        if (item['id'] == previewChildId)
          {...item, 'parent_id': previewParentId == 0 ? null : previewParentId}
        else
          item,
    ];
  }
  final byId = <int, Map<String, Object?>>{
    for (final item in items) item['id'] as int: item,
  };
  final directions = <(int, int), Offset>{};
  final groups = <(int, int), List<Offset>>{};
  int sector(Offset d) =>
      d.dx.abs() > d.dy.abs() ? (d.dx >= 0 ? 0 : 1) : (d.dy >= 0 ? 2 : 3);
  for (final item in items) {
    final parent = item['parent_id'] as int? ?? 0;
    final child = item['id'] as int;
    final a = positions[parent], b = positions[child];
    if (a == null || b == null || (b - a).distance < .01) continue;
    final unit = (b - a) / (b - a).distance;
    directions[(parent, child)] = unit;
    (groups[(parent, sector(unit))] ??= []).add(unit);
  }
  Offset edge(Offset center, Offset direction, String? shape) {
    final dx = direction.dx.abs(), dy = direction.dy.abs();
    final double distance;
    if (shape == 'circle') {
      distance = 43 / direction.distance;
    } else if (shape == 'diamond') {
      distance = 1 / (dx / 87 + dy / 43);
    } else {
      distance = math.min(
        dx < .0001 ? double.infinity : 87 / dx,
        dy < .0001 ? double.infinity : 43 / dy,
      );
    }
    return center + direction * distance;
  }

  int depth(int parent) {
    var n = parent, count = 0;
    final seen = <int>{};
    while (n != 0 && seen.add(n) && byId.containsKey(n)) {
      count++;
      n = byId[n]!['parent_id'] as int? ?? 0;
    }
    return count;
  }

  final result = <PlantLine>[];
  for (final item in items) {
    final parent = item['parent_id'] as int? ?? 0;
    final child = item['id'] as int;
    final unit = directions[(parent, child)];
    if (unit == null) continue;
    final siblings = groups[(parent, sector(unit))]!;
    final average = siblings.fold<Offset>(Offset.zero, (sum, d) => sum + d);
    final direction = average.distance < .01
        ? unit
        : average / average.distance;
    final parentCenter = positions[parent]! + const Offset(87, 43);
    final childCenter = positions[child]! + const Offset(87, 43);
    final from = edge(
      parentCenter,
      direction,
      byId[parent]?['shape'] as String?,
    );
    final to = edge(childCenter, -unit, item['shape'] as String?);
    final distance = (to - from).distance;
    final shared = math.min(14.0, distance * .12);
    final joint = from + direction * shared;
    final bend = math.min(distance * .35, 140.0);
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..lineTo(joint.dx, joint.dy)
      ..cubicTo(
        joint.dx + direction.dx * bend,
        joint.dy + direction.dy * bend,
        to.dx - unit.dx * bend,
        to.dy - unit.dy * bend,
        to.dx,
        to.dy,
      );
    result.add(PlantLine(parent, child, path, depth(parent)));
  }
  return result;
}

class TreeLines extends CustomPainter {
  TreeLines(
    this.items,
    this.positions,
    this.color, {
    this.zoomScale = 1,
    this.previewChildId,
    this.previewParentId,
    this.previewColor,
  });
  final List<Map<String, Object?>> items;
  final Map<int, Offset> positions;
  final Color color;
  final double zoomScale;
  final int? previewChildId, previewParentId;
  final Color? previewColor;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final minWidth = .65 / zoomScale.clamp(.05, 2.5);
    for (final link in buildPlantLines(
      items,
      positions,
      previewChildId: previewChildId,
      previewParentId: previewParentId,
    )) {
      paint.color = link.childId == previewChildId && previewParentId != null
          ? (previewColor ?? color).withValues(alpha: .42)
          : color;
      final base = 1.1 + .7 / (1 + link.depth * .65);
      for (final metric in link.path.computeMetrics()) {
        for (var i = 0; i < 6; i++) {
          paint.strokeWidth = math.max(minWidth, base * (1 - .22 * i / 5));
          canvas.drawPath(
            metric.extractPath(
              metric.length * i / 6,
              metric.length * (i + 1) / 6,
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant TreeLines old) =>
      old.items != items ||
      old.positions != positions ||
      old.color != color ||
      old.zoomScale != zoomScale ||
      old.previewChildId != previewChildId ||
      old.previewParentId != previewParentId ||
      old.previewColor != previewColor;
}
