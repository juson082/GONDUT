import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memo_graph/garden_routes.dart';

void main() {
  test(
    'a user drop keeps its exact coordinates and cannot alter graph nodes',
    () {
      const drop = Offset(137, 251);
      final route = gardenStationaryRoute(drop);
      expect(route.points, [drop]);
      expect(route.branchId, -1);
      expect(route.bounds.contains(drop), isTrue);
    },
  );
  test('rest spots sit on the left and right edge of each node', () {
    final spots = gardenRestSpots({1: const Offset(100, 200)});
    expect(spots, [const Offset(122, 200), const Offset(252, 200)]);
  });
  test(
    'overlapping route candidates can be explored without changing stored geometry',
    () {
      final items = <Map<String, Object?>>[
        {'id': 1, 'parent_id': null},
      ];
      final positions = <int, Offset>{
        0: const Offset(200, 500),
        1: const Offset(200, 50),
      };
      final before = Map<int, Offset>.of(positions);
      final all = gardenRoutes(
        items,
        positions,
        limit: 1000,
        allowOverlaps: true,
      );
      final separated = gardenRoutes(items, positions, limit: 1000);
      expect(all.length, greaterThanOrEqualTo(separated.length));
      expect(all.length, greaterThan(1));
      expect(positions, before);
      for (final r in all) {
        expect(r.branchId, 1);
      }
    },
  );
}
