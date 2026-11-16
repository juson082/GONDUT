import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memo_graph/plant_lines.dart';

void main() {
  test(
    'drag preview uses the same eligible nearest parent without changing data',
    () {
      final items = <Map<String, Object?>>[
        {'id': 1, 'parent_id': null},
        {'id': 2, 'parent_id': 1},
        {'id': 3, 'parent_id': null},
      ];
      final positions = <int, Offset>{
        0: const Offset(0, 0),
        1: const Offset(100, 0),
        2: const Offset(290, 0),
        3: const Offset(310, 0),
      };
      // The dragged node and its descendant are both closer but ineligible.
      final target = nearestDropTarget(positions, {1, 2}, const Offset(290, 0));
      expect(target, 3);
      final lines = buildPlantLines(
        items,
        positions,
        previewChildId: 1,
        previewParentId: target,
      );
      expect(lines.map((line) => (line.parentId, line.childId)).toSet(), {
        (3, 1),
        (1, 2),
        (0, 3),
      });
      expect(items.first['parent_id'], isNull);
      expect(nearestDropTarget(positions, {1, 2, 3}, const Offset(0, 0)), 0);
      expect(nearestDropTarget(positions, {0, 1, 2, 3}, Offset.zero), isNull);
      expect(
        buildPlantLines(
          items,
          positions,
          previewChildId: 2,
          previewParentId: 0,
        ).any((line) => line.parentId == 0 && line.childId == 2),
        isTrue,
      );
    },
  );
  test(
    'drawing keeps the saved positions and exactly the stored connections',
    () {
      final items = <Map<String, Object?>>[
        {'id': 1, 'parent_id': null, 'shape': 'rounded'},
        {'id': 2, 'parent_id': 1, 'shape': 'circle'},
        {'id': 3, 'parent_id': 1, 'shape': 'diamond'},
        {'id': 4, 'parent_id': 2},
      ];
      final positions = <int, Offset>{
        0: const Offset(0, 0),
        1: const Offset(260, 100),
        2: const Offset(480, -80),
        3: const Offset(500, 250),
        4: const Offset(200, -200),
      };
      final before = Map<int, Offset>.of(positions);
      final rowsBefore = items.map((e) => Map<String, Object?>.of(e)).toList();
      final lines = buildPlantLines(items, positions);
      expect(lines.map((e) => (e.parentId, e.childId)).toSet(), {
        (0, 1),
        (1, 2),
        (1, 3),
        (2, 4),
      });
      expect(positions, before);
      expect(items, rowsBefore);
      for (final line in lines) {
        final metric = line.path.computeMetrics().single;
        final start = metric.getTangentForOffset(0)!.position;
        final end = metric.getTangentForOffset(metric.length)!.position;
        expect(
          (positions[line.parentId]! & const Size(174, 86))
              .inflate(1)
              .contains(start),
          isTrue,
        );
        expect(
          (positions[line.childId]! & const Size(174, 86))
              .inflate(1)
              .contains(end),
          isTrue,
        );
      }
    },
  );
}
