import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memo_graph/garden_person.dart';
import 'package:memo_graph/garden_routes.dart';

class FixedRandom implements math.Random {
  FixedRandom(this.value, {this.choice = 0, this.sleepOffset = 0});
  final double value;
  final int choice;
  final int sleepOffset;
  @override
  double nextDouble() => value;
  @override
  int nextInt(int max) => max == 3
      ? choice
      : max == 121
      ? sleepOffset
      : 0;
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
  testWidgets('a person dropped into empty space returns from above', (
    tester,
  ) async {
    Offset? returnedTo;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GardenPerson(
            index: 0,
            route: route(),
            random: FixedRandom(.8),
            onDragStart: () {},
            onDragUpdate: (_) {},
            onDragEnd: (_) {},
            landingAt: (_) => null,
            reentryAt: (_) => (
              const Offset(100, 400),
              const Offset(140, -50),
              const Offset(140, 160),
            ),
            onReentry: (point) => returnedTo = point,
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('garden-step-2'))),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pump();
    expect(pose('dropping'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump();
    expect(pose('dropping'), findsNothing);
    expect(returnedTo, isNull);
    await tester.pump(const Duration(milliseconds: 2999));
    expect(returnedTo, isNull);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(returnedTo, const Offset(140, 160));
    expect(pose('dropping'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump();
    expect(pose('landing'), findsOneWidget);
  });

  testWidgets('sitting renders each character frame as a single image', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GardenPerson(
            index: 1,
            route: route(),
            random: FixedRandom(.2, choice: 1),
            restSpots: const [Offset(185, 120)],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 4100));
    await tester.pump(const Duration(milliseconds: 710));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump();
    expect(find.byKey(const ValueKey('garden-step-2')), findsOneWidget);
    for (var i = 0; i < 120 && pose('sitting').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(pose('sitting'), findsOneWidget);
    expect(
      find.descendant(of: pose('sitting'), matching: find.byType(Image)),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(pose('sitting'), findsOneWidget);
    expect(
      find.descendant(of: pose('sitting'), matching: find.byType(Image)),
      findsOneWidget,
    );
  });
  testWidgets('a character falls before playing the landing animation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GardenPerson(
            index: 0,
            route: route(),
            random: FixedRandom(.8),
            onDragStart: () {},
            onDragUpdate: (_) {},
            onDragEnd: (_) {},
            landingAt: (_) => const Offset(100, 260),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('garden-step-2'))),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pump();
    expect(pose('dropping'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1200));
    expect(pose('landing'), findsOneWidget);
  });
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
    await tester.pump(const Duration(milliseconds: 200));
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
            random: FixedRandom(.1, choice: 2),
            restSpots: const [Offset(185, 120)],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 4100));
    await tester.pump(const Duration(milliseconds: 710));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump();
    expect(find.byKey(const ValueKey('garden-step-2')), findsOneWidget);
    for (var i = 0; i < 120 && pose('yawning').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(pose('yawning'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pump();
    expect(pose('sleeping'), findsOneWidget);
    expect(find.byKey(const ValueKey('garden-sleep-zzz')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 59999));
    expect(pose('sleeping'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(pose('waking'), findsOneWidget);
    expect(find.byKey(const ValueKey('garden-sleep-zzz')), findsNothing);
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pump();
    expect(pose('waking'), findsNothing);
    expect(pose('sleeping'), findsNothing);
    expect(find.byKey(const ValueKey('garden-step-2')), findsOneWidget);
  });

  testWidgets('sleep lasts at least a minute and tapping wakes immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GardenPerson(
            index: 1,
            route: route(),
            random: FixedRandom(.1, choice: 2, sleepOffset: 30),
            restSpots: const [Offset(185, 120)],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 4100));
    await tester.pump(const Duration(milliseconds: 710));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump();
    for (var i = 0; i < 120 && pose('yawning').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(pose('yawning'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pump();
    expect(pose('sleeping'), findsOneWidget);
    await tester.pump(const Duration(seconds: 61));
    expect(pose('sleeping'), findsOneWidget);
    await tester.tap(pose('sleeping'));
    await tester.pump();
    expect(pose('sleeping'), findsNothing);
    expect(pose('waking'), findsOneWidget);
    expect(find.byKey(const ValueKey('garden-pose-surprised')), findsNothing);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(pose('waking'), findsNothing);
  });
}
