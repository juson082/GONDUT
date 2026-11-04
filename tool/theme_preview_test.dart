import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memo_graph/paper_theme.dart';

void main() {
  testWidgets('render plant theme color samples', (tester) async {
    tester.view.physicalSize = const Size(900, 1620);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final font = File('assets/NanumPenScript-Regular.ttf').readAsBytesSync();
    await (FontLoader(
      'GondutHand',
    )..addFont(Future.value(font.buffer.asByteData()))).load();
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: Scaffold(
            backgroundColor: const Color(0xfffffbf6),
            body: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'GONDUT · 식물 테마',
                    style: TextStyle(
                      fontFamily: 'GondutHand',
                      fontSize: 48,
                      color: Color(0xff425346),
                    ),
                  ),
                  const Text(
                    '색상별 앱 배경과 노트 종이 예시',
                    style: TextStyle(
                      fontFamily: 'GondutHand',
                      fontSize: 26,
                      color: Color(0xff6f7b6d),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      childAspectRatio: 1.22,
                      crossAxisSpacing: 22,
                      mainAxisSpacing: 22,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (final entry in themeColors.entries)
                          Builder(
                            builder: (context) {
                              final theme = paperTheme(entry.key);
                              return Container(
                                decoration: BoxDecoration(
                                  color: theme.scaffoldBackgroundColor,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant,
                                  ),
                                ),
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 13,
                                          backgroundColor: entry.value.$2,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          entry.value.$1,
                                          style: TextStyle(
                                            fontFamily: 'GondutHand',
                                            fontSize: 34,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: theme
                                              .colorScheme
                                              .primaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: theme
                                                .colorScheme
                                                .outlineVariant,
                                          ),
                                        ),
                                        padding: const EdgeInsets.all(18),
                                        child: Text(
                                          '한 장의 생각\n  └ 작은 가지',
                                          style: TextStyle(
                                            fontFamily: 'GondutHand',
                                            fontSize: 27,
                                            color: theme.colorScheme.onSurface,
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'play-console/theme-colors-preview.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
