import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memo_graph/paper_theme.dart';

void main() {
  testWidgets('render multilingual notebook fonts', (tester) async {
    tester.view.physicalSize = const Size(850, 1040);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final font in [
      (
        'GondutHand',
        Platform.environment['GONDUT_PREVIEW_FONT'] ??
            'assets/Xiaolai-Regular.ttf',
      ),
    ]) {
      final bytes = File(font.$2).readAsBytesSync();
      await (FontLoader(
        font.$1,
      )..addFont(Future.value(bytes.buffer.asByteData()))).load();
    }
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'GONDUT',
                    style: TextStyle(fontFamily: 'GondutHand', fontSize: 48),
                  ),
                  for (final sample in [
                    ('ko', '한국어', '오늘의 생각을 한 장씩 모아요'),
                    (
                      'en',
                      'English',
                      'Gather your thoughts, one page at a time',
                    ),
                    ('ja', '日本語', '今日の考えをノートに書きましょう'),
                    ('zh', '中文', '把今天的想法记录在笔记里'),
                    ('es', 'Español', 'Guarda tus ideas y deja que crezcan'),
                  ])
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: paperTheme(
                            'sage',
                          ).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: DefaultTextStyle(
                          style: paperTheme('sage').textTheme.titleLarge!,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sample.$2),
                              const SizedBox(height: 8),
                              Text(sample.$3),
                            ],
                          ),
                        ),
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
        Platform.environment['GONDUT_PREVIEW_OUTPUT'] ??
            'play-console/language-font-preview.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
