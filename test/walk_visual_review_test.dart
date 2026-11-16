import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memo_graph/garden_person.dart';
import 'package:memo_graph/garden_routes.dart';

class _WalkRandom implements math.Random {
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => .8;
  @override
  int nextInt(int max) => 0;
}

void main() {
  testWidgets('capture the actual five walking animations', (tester) async {
    final key = GlobalKey();
    const route = GardenRoute(
      [Offset(45, 65), Offset(45, 65)], Rect.fromLTWH(0, 0, 100, 80), 1,
    );
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(
      child: RepaintBoundary(key: key, child: SizedBox(width: 100, height: 400,
        child: Column(children: [for (var i = 0; i < 5; i++) SizedBox(
          width: 100, height: 80, child: GardenPerson(index: i, route: route, random: _WalkRandom()),
        )]),
      )),
    ))));
    await tester.runAsync(() async {
      await Future.wait([
        for (var i = 0; i < 5; i++)
          precacheImage(AssetImage(i == 1
              ? 'assets/characters/walk-body-clean-1.png'
              : 'assets/characters/walk-body-$i.png'), key.currentContext!),
      ]);
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump();
    final frames = <ui.Image>[];
    for (var i = 0; i < 8; i++) {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      frames.add((await tester.runAsync(() => boundary.toImage(pixelRatio: 4)))!);
      await tester.pump(const Duration(milliseconds: 125));
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xfff5f4ea), BlendMode.src);
    for (var i = 0; i < frames.length; i++) {
      for (var person = 0; person < 5; person++) {
        canvas.drawImageRect(
          frames[i],
          Rect.fromLTWH(125, person * 320.0 + 130, 140, 140),
          Rect.fromLTWH(i * 180.0, person * 180.0, 180, 180),
          Paint()..filterQuality = FilterQuality.high,
        );
      }
    }
    await tester.runAsync(() async {
      final image = await recorder.endRecording().toImage(1440, 900);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('.tools').create(recursive: true);
      await File('.tools/walk-visual-review.png').writeAsBytes(png!.buffer.asUint8List());
    });
    await tester.pumpWidget(const SizedBox());
  });
}
