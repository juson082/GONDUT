import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('action frames stay inside their own atlas cells', (tester) async {
    await tester.runAsync(() async {
      for (var character = 0; character < 5; character++) {
        for (final repaired in character == 1 || character == 2
            ? [false, true]
            : [false]) {
          final path = repaired
              ? 'assets/characters/actions-sleep-$character.png'
              : 'assets/characters/actions-$character.png';
          final data = await rootBundle.load(path);
          final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
          final image = (await codec.getNextFrame()).image;
          final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          final pixels = bytes.buffer.asUint8List();
          for (var row = 0; row < 4; row++) {
            if ((character == 1 || character == 2) &&
                (row == 1) != repaired) continue;
            for (var col = 0; col < 8; col++) {
              final left = (col * image.width / 8).ceil();
              final right = ((col + 1) * image.width / 8).floor() - 1;
              final top = (row * image.height / 4).ceil();
              final bottom = ((row + 1) * image.height / 4).floor();
              var edgePixels = 0;
              for (var y = top; y < bottom; y++) {
                final leftAlpha = pixels[(y * image.width + left) * 4 + 3];
                final rightAlpha = pixels[(y * image.width + right) * 4 + 3];
                if (leftAlpha > 64 || rightAlpha > 64) edgePixels++;
              }
              expect(edgePixels, lessThanOrEqualTo(2),
                  reason: '$path row $row frame $col touches a neighbour');
            }
          }
          image.dispose();
          codec.dispose();
        }
      }
      final singleRowSheets = <String>[
        for (var i = 0; i < 5; i++)
          i == 1
              ? 'assets/characters/walk-body-clean-1.png'
              : 'assets/characters/walk-body-$i.png',
        for (var i = 0; i < 5; i++)
          i == 2 ? 'assets/characters/sit-clean-2.png' : 'assets/characters/sit-$i.png',
      ];
      for (final path in singleRowSheets) {
        final data = await rootBundle.load(path);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final image = (await codec.getNextFrame()).image;
        final pixels = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
            .buffer.asUint8List();
        for (var col = 0; col < 8; col++) {
          final left = (col * image.width / 8).ceil();
          final right = ((col + 1) * image.width / 8).floor() - 1;
          var edgePixels = 0;
          for (var y = 0; y < image.height; y++) {
            if (pixels[(y * image.width + left) * 4 + 3] > 64 ||
                pixels[(y * image.width + right) * 4 + 3] > 64) edgePixels++;
          }
          expect(edgePixels, lessThanOrEqualTo(2),
              reason: '$path frame $col touches a neighbour');
        }
        image.dispose();
        codec.dispose();
      }
    });
  });
}
