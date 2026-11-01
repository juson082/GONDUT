import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// Bottom-up drawing of the existing hierarchy. Coordinates are presentation
/// only: they never change the stored nodes or parent relationships.
class PlantLayout {
  const PlantLayout(this.positions, this.size);
  final Map<int, Offset> positions;
  final Size size;
}

/// Keep manually placed nodes fixed; place newly created nodes near their
/// parent without covering the rest of the visible tree.
Map<int, Offset> placePlantNodes(
  List<Map<String, Object?>> items,
  PlantLayout layout,
  Offset rootPosition,
) {
  final visible = layout.positions;
  final root = visible[0] ?? Offset.zero;
  final result = <int, Offset>{0: rootPosition};
  final byId = {for (final item in items) item['id'] as int: item};
  final manual = items.any((item) => item['x'] is num && item['y'] is num);
  for (final item in items) {
    final id = item['id'] as int;
    if (visible.containsKey(id) && item['x'] is num && item['y'] is num) {
      result[id] = Offset(
        (item['x'] as num).toDouble(),
        (item['y'] as num).toDouble(),
      );
    }
  }
  const offsets = [
    Offset(0, -145),
    Offset(205, 0),
    Offset(-205, 0),
    Offset(0, 145),
    Offset(205, -145),
    Offset(-205, -145),
    Offset(205, 145),
    Offset(-205, 145),
  ];
  Offset resolve(int id, Set<int> visiting) {
    if (result.containsKey(id)) return result[id]!;
    final fallback = rootPosition + (visible[id] ?? root) - root;
    if (!manual || !visiting.add(id)) return result[id] = fallback;
    final parentId = byId[id]?['parent_id'] as int? ?? 0;
    final parent = visible.containsKey(parentId)
        ? resolve(parentId, visiting)
        : rootPosition;
    visiting.remove(id);
    for (var ring = 1; ring <= 20; ring++) {
      for (final offset in offsets) {
        final candidate = parent + offset * ring.toDouble();
        if (candidate.dx < 0 ||
            candidate.dx > 5826 ||
            candidate.dy < 0 ||
            candidate.dy > 5914)
          continue;
        if (result.values.every(
          (other) =>
              (other.dx - candidate.dx).abs() >= 174 ||
              (other.dy - candidate.dy).abs() >= 100,
        ))
          return result[id] = candidate;
      }
    }
    return result[id] = fallback;
  }

  for (final id in visible.keys.where((id) => id != 0)) {
    resolve(id, <int>{});
  }
  return result;
}

PlantLayout layoutPlant(List<Map<String, Object?>> items, Set<int> collapsed) {
  const nodeWidth = 174.0;
  const nodeHeight = 86.0;
  const horizontalStep = 205.0;
  const verticalStep = 125.0;
  const margin = 28.0;
  final children = <int, List<Map<String, Object?>>>{};
  for (final item in items) {
    final parent = item['parent_id'] as int? ?? 0;
    (children[parent] ??= []).add(item);
  }
  final xPositions = <int, double>{};
  final depths = <int, int>{};
  var leafCount = 0;
  var maxDepth = 0;
  double visit(int id, int depth, Set<int> ancestors) {
    if (ancestors.contains(id)) return margin;
    depths[id] = depth;
    maxDepth = math.max(maxDepth, depth);
    final visible = collapsed.contains(id)
        ? <Map<String, Object?>>[]
        : (children[id] ?? []);
    final childX = <double>[];
    for (final child in visible) {
      final childId = child['id'] as int;
      if (!ancestors.contains(childId) && childId != id) {
        childX.add(visit(childId, depth + 1, {...ancestors, id}));
      }
    }
    final x = childX.isEmpty
        ? margin + leafCount++ * horizontalStep
        : (childX.first + childX.last) / 2;
    xPositions[id] = x;
    return x;
  }

  visit(0, 0, {});
  return PlantLayout(
    {
      for (final e in xPositions.entries)
        e.key: Offset(
          e.value,
          margin + (maxDepth - depths[e.key]!) * verticalStep,
        ),
    },
    Size(
      margin * 2 +
          math.max(1, leafCount) * horizontalStep -
          (horizontalStep - nodeWidth),
      margin * 2 + maxDepth * verticalStep + nodeHeight,
    ),
  );
}
