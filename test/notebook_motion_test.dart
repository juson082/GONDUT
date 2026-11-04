import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memo_graph/notebook_motion.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets(
      'press feedback keeps taps working with reduced motion: $reduced',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: Scaffold(
                body: Center(
                  child: NotebookPress(
                    child: ElevatedButton(
                      onPressed: () => taps++,
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Open')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final scaled = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
        expect(scaled.scale, reduced ? 1 : .975);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(taps, 1);
        expect(
          tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
          1,
        );
      },
    );
  }
}
