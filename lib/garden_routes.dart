import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'plant_lines.dart';

/// A sampled section of the same curve used to paint the graph's branches.
class GardenRoute {
  const GardenRoute(this.points, this.bounds, this.branchId);
  final List<Offset> points;
  final Rect bounds;
  final int branchId;
}

const gardenSpriteWidth = 22.0;
const gardenSpriteHeight = 48.0;

/// Select short, unobstructed branch segments without moving any nodes.
List<GardenRoute> gardenRoutes(
  List<Map<String, Object?>> items,
  Map<int, Offset> positions, {
  int limit = 5,
  bool allowOverlaps = false,
}) {
  // Characters are painted underneath nodes; keep their paths outside the
  // central text area even when branches are close together.
  final blockers = positions.values
      .map((p) => Rect.fromLTWH(p.dx + 12, p.dy + 14, 150, 58))
      .toList();
  final candidates = <GardenRoute>[];
  bool clear(Offset foot) {
    // The image has transparent padding below the shoes; the foot is 80% down.
    final sprite = Rect.fromLTWH(
      foot.dx - gardenSpriteWidth / 2,
      foot.dy - gardenSpriteHeight * .8 - 9,
      gardenSpriteWidth,
      gardenSpriteHeight + 9,
    );
    return sprite.left >= 0 &&
        sprite.top >= 0 &&
        sprite.right <= 6000 &&
        sprite.bottom <= 6000 &&
        !blockers.any((box) => box.overlaps(sprite));
  }

  for (final branch in buildPlantLines(items, positions)) {
    for (final metric in branch.path.computeMetrics()) {
      var current = <Offset>[];
      void finish() {
        if (current.length >= 2) {
          final left =
              current.map((p) => p.dx).reduce(math.min) - gardenSpriteWidth / 2;
          final right =
              current.map((p) => p.dx).reduce(math.max) + gardenSpriteWidth / 2;
          final top =
              current.map((p) => p.dy).reduce(math.min) -
              gardenSpriteHeight * .8 -
              12;
          final bottom =
              current.map((p) => p.dy).reduce(math.max) +
              gardenSpriteHeight * .2 +
              4;
          candidates.add(
            GardenRoute(
              List.unmodifiable(current),
              Rect.fromLTRB(left, top, right, bottom),
              branch.childId,
            ),
          );
        }
        current = [];
      }

      final steps = (metric.length / 2).ceil();
      for (var i = 0; i <= steps; i++) {
        final point = metric
            .getTangentForOffset(math.min(metric.length, i * 2.0))
            ?.position;
        if (point == null || !clear(point)) {
          finish();
          continue;
        }
        current.add(point);
        // Leave room for other walkers on long branches.
        if (current.length >= 65) finish();
      }
      finish();
    }
  }
  candidates.sort((a, b) => b.points.length.compareTo(a.points.length));
  final selected = <GardenRoute>[];
  for (final route in candidates) {
    if (!allowOverlaps &&
        selected.any((other) => other.bounds.inflate(4).overlaps(route.bounds)))
      continue;
    selected.add(route);
    if (selected.length == limit) break;
  }
  return selected;
}

/// Keep an explicitly placed character at the exact released point until it
/// chooses a reachable branch. No memo or node coordinates are modified.
GardenRoute gardenStationaryRoute(Offset foot, {int branchId = -1}) {
  return GardenRoute(
    [foot],
    Rect.fromLTWH(
      foot.dx - gardenSpriteWidth / 2,
      foot.dy - gardenSpriteHeight * .8 - 12,
      gardenSpriteWidth,
      gardenSpriteHeight + 16,
    ),
    branchId,
  );
}

/// The feet touch an edge of the node, with the body above its text.
List<Offset> gardenRestSpots(Map<int, Offset> positions) => [
  for (final p in positions.values) ...[
    Offset(p.dx + 22, p.dy),
    Offset(p.dx + 152, p.dy),
  ],
];
