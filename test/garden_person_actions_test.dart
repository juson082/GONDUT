import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memo_graph/garden_person.dart';
import 'package:memo_graph/garden_routes.dart';

class FixedRandom implements math.Random {
  FixedRandom(this.value);
  final double value;
  @override
  double nextDouble() => value;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

GardenRoute route() => const GardenRoute(
  [Offset(100, 120), Offset(140, 100), Offset(180, 120)],
  Rect.fromLTRB(80, 60, 210, 145),
  1,
);
Finder pose(String name) => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key as ValueKey<String>).value.startsWith('garden-$name-'),
);

void main() {
  testWidgets('long press carries the person and a drop can trigger a fall', (
    tester,
  ) async {
    var started = 0, ended = 0;
    Offset? dropped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GardenPerson(
            index: 0,
            route: route(),
            random: FixedRandom(.2),
            onDragStart: () => started++,
            onDragUpdate: (_) {},
            onDragEnd: (p) {
              ended++;
              dropped = p;
            },
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('garden-step-2'))),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(started, 1);
    expect(pose('carried'), findsOneWidget);
    await gesture.moveBy(const Offset(30, 15));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(ended, 1);
    expect(dropped, isNotNull);
    expect(pose('falling'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(pose('falling'), findsNothing);
  });

  testWidgets('after walking the person can yawn and sleep on a node', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GardenPerson(
            index: 0,
            route: route(),
            random: FixedRandom(.1),
            restSpots: const [Offset(185, 120)],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 3700));
    await tester.pump(const Duration(milliseconds: 710));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(pose('yawning'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump();
    expect(pose('sleeping'), findsOneWidget);
    expect(find.byKey(const ValueKey('garden-sleep-zzz')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 5500));
    expect(pose('waking'), findsOneWidget);
    expect(find.byKey(const ValueKey('garden-sleep-zzz')), findsNothing);
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pump();
    expect(pose('waking'), findsNothing);
    expect(pose('sleeping'), findsNothing);
    expect(find.byKey(const ValueKey('garden-step-2')), findsOneWidget);
  });
}
