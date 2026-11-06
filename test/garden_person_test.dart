import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memo_graph/garden_person.dart';

void main() {
  testWidgets('a tap makes the little person hide and return', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: GardenPerson(index: 0))),
    );
    await tester.tap(find.byType(GardenPerson));
    await tester.pump();
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      .25,
    );
    await tester.pump(const Duration(milliseconds: 1300));
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1,
    );
  });
}
