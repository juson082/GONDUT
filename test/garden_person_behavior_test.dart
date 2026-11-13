import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memo_graph/garden_person.dart';
import 'package:memo_graph/garden_routes.dart';

GardenRoute _route() => const GardenRoute(
  [Offset(100, 120), Offset(140, 100), Offset(180, 120)],
  Rect.fromLTRB(80, 60, 210, 145),
  1,
);

Widget _app({bool reduced = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(body: GardenPerson(index: 0, route: _route())),
  ),
);

Finder _step() => find.byWidgetPredicate(
  (widget) =>
      widget.key is ValueKey<String> &&
      (widget.key as ValueKey<String>).value.startsWith('garden-step-'),
);

void main() {
  testWidgets('surprised sprite preserves square frame and lasts 500ms', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.tap(_step());
    await tester.pump();
    final pose = find.byKey(const ValueKey('garden-pose-surprised'));
    expect(pose, findsOneWidget);
    final clip = find.descendant(of: pose, matching: find.byType(ClipRect));
    expect(clip, findsOneWidget);
    final size = tester.getSize(clip);
    expect(size.width, closeTo(size.height, 0.1));
    await tester.pump(const Duration(milliseconds: 499));
    expect(pose, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2));
    expect(pose, findsNothing);
  });

  testWidgets('walking person remains tappable at its moved location', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    final initial = tester.getCenter(_step());
    var moved = false;
    for (var i = 0; i < 80 && !moved; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      final step = _step();
      if (step.evaluate().isNotEmpty) {
        moved = (tester.getCenter(step) - initial).distance > 12;
      }
    }
    expect(
      moved,
      isTrue,
      reason: 'A walking character should move from its initial position.',
    );
    await tester.tap(_step());
    await tester.pump();
    expect(find.byKey(const ValueKey('garden-pose-surprised')), findsOneWidget);
  });

  testWidgets('reduced motion keeps position still and resets reaction', (
    tester,
  ) async {
    await tester.pumpWidget(_app(reduced: true));
    final initial = tester.getCenter(_step());
    await tester.pump(const Duration(seconds: 8));
    expect(tester.getCenter(_step()), initial);
    await tester.tap(_step());
    await tester.pump();
    final pose = find.byKey(const ValueKey('garden-pose-surprised'));
    expect(pose, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 501));
    expect(pose, findsNothing);
  });
}
