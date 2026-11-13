import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memo_graph/garden_person.dart';
import 'package:memo_graph/garden_routes.dart';

GardenRoute route() => const GardenRoute(
  [Offset(100, 120), Offset(140, 100), Offset(180, 120)],
  Rect.fromLTRB(80, 60, 210, 145),
  1,
);

void main() {
  testWidgets('walker follows a curved route with eight different steps', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GardenPerson(index: 0, route: route())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));
    final seen = <int>{};
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 140));
      for (var frame = 0; frame < 8; frame++) {
        if (find.byKey(ValueKey('garden-step-$frame')).evaluate().isNotEmpty)
          seen.add(frame);
      }
    }
    expect(seen.length, greaterThanOrEqualTo(6));
  });
  testWidgets('tap shows a startled pose and returns to walking', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GardenPerson(index: 0, route: route())),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('garden-step-2')));
    await tester.pump();
    expect(find.byKey(const ValueKey('garden-pose-surprised')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.byKey(const ValueKey('garden-pose-surprised')), findsNothing);
  });
  test(
    'selected walking samples follow the real branch without covering labels',
    () {
      final items = <Map<String, Object?>>[
        {'id': 1, 'parent_id': null},
      ];
      final positions = {0: const Offset(100, 300), 1: const Offset(100, 100)};
      final routes = gardenRoutes(items, positions, limit: 1);
      expect(routes, isNotEmpty);
      for (final point in routes.single.points) {
        expect(point.dx, closeTo(187, .01));
        final sprite = Rect.fromLTWH(
          point.dx - gardenSpriteWidth / 2,
          point.dy - gardenSpriteHeight * .8 - 9,
          gardenSpriteWidth,
          gardenSpriteHeight + 9,
        );
        for (final p in positions.values) {
          expect(
            sprite.overlaps(Rect.fromLTWH(p.dx + 12, p.dy + 14, 150, 58)),
            isFalse,
          );
        }
      }
    },
  );
}
