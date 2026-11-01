import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:memo_graph/plant_layout.dart';

void main() {
  test(
    'AI and voice additions avoid moved nodes and stay near their parent',
    () {
      final items = <Map<String, Object?>>[
        {'id': 1, 'parent_id': null, 'x': 2900.0, 'y': 2600.0},
        {'id': 2, 'parent_id': 1},
        {'id': 3, 'parent_id': 1},
      ];
      final p = placePlantNodes(
        items,
        layoutPlant(items, {}),
        const Offset(2800, 2800),
      );
      expect(p[1], const Offset(2900, 2600));
      expect((p[2]! - p[1]!).distance, lessThan(300));
      expect((p[3]! - p[2]!).distance, greaterThan(100));
    },
  );
  test(
    'branches grow upward, siblings spread out and parents remain centered',
    () {
      final items = <Map<String, Object?>>[
        {'id': 1, 'parent_id': null, 'text': 'A'},
        {'id': 2, 'parent_id': 1, 'text': 'B'},
        {'id': 3, 'parent_id': 1, 'text': 'C'},
        {'id': 4, 'parent_id': null, 'text': 'D'},
      ];
      final snapshot = items.map((e) => Map<String, Object?>.of(e)).toList();
      final layout = layoutPlant(items, {});
      final p = layout.positions;
      expect(p.keys.toSet(), {0, 1, 2, 3, 4});
      expect(p[2]!.dy, lessThan(p[1]!.dy));
      expect(p[1]!.dy, lessThan(p[0]!.dy));
      expect(p[2]!.dx, lessThan(p[3]!.dx));
      expect(p[1]!.dx, (p[2]!.dx + p[3]!.dx) / 2);
      expect(items, snapshot);
    },
  );

  test('collapsed branches hide descendants without changing data', () {
    final items = <Map<String, Object?>>[
      {'id': 1, 'parent_id': null},
      {'id': 2, 'parent_id': 1},
    ];
    expect(layoutPlant(items, {1}).positions.keys.toSet(), {0, 1});
    expect(layoutPlant(items, {}).positions.keys.toSet(), {0, 1, 2});
  });
}
