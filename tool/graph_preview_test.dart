import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:memo_graph/main.dart';
import 'package:memo_graph/paper_theme.dart';
import '../test/editor_test.dart' show MemoryStore;

void main() {
  testWidgets('render graph preview', (tester) async {
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final font = File('C:/Windows/Fonts/malgun.ttf').readAsBytesSync();
    final loader = FontLoader('PreviewFont')
      ..addFont(Future.value(font.buffer.asByteData()));
    await loader.load();
    final handwritten = File(
      'assets/NanumPenScript-Regular.ttf',
    ).readAsBytesSync();
    await (FontLoader(
      'GondutHand',
    )..addFont(Future.value(handwritten.buffer.asByteData()))).load();
    final icons = File(
      '.tools/release/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ).readAsBytesSync();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(icons.buffer.asByteData()))).load();
    final store = MemoryStore();
    final examples = <(int, int?, String)>[
      (1, null, '투자 판단'),
      (2, 1, '거시 경제'),
      (3, 1, '기업 분석'),
      (4, 1, '위험 관리'),
      (5, 2, '금리 추세'),
      (6, 2, '경기 전망'),
      (7, 3, '실적 확인'),
      (8, 3, '시장 기대'),
      (9, 4, '손실 범위'),
      (10, 4, '다음 점검'),
    ];
    for (final (id, parent, text) in examples) {
      store.treeItems.add({
        'id': id,
        'parent_id': parent,
        'text': text,
        'memo_id': 1,
        'position': id,
      });
    }
    final key = GlobalKey();
    final base = paperTheme('sage');
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: const [Locale('ko')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          quill.FlutterQuillLocalizations.delegate,
        ],
        theme: base,
        builder: (context, child) => RepaintBoundary(key: key, child: child!),
        home: Editor(store, 1, '투자 판단을 정리해 보세요'),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'play-console/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    }

    await tester.runAsync(() => capture('editor-preview'));
    await tester.tap(find.byTooltip('나무 그래프'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('전체 보기'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => capture('graph-overview-preview'));
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    final viewerBox = tester.renderObject<RenderBox>(
      find.byType(InteractiveViewer),
    );
    final nodePosition = viewerBox.globalToLocal(
      tester.getCenter(find.text('기업 분석')),
    );
    final nodeScene = viewer.transformationController!.toScene(nodePosition);
    viewer.transformationController!.value = Matrix4.identity()
      ..translateByDouble(
        viewerBox.size.width / 2 - nodeScene.dx,
        viewerBox.size.height / 2 - nodeScene.dy,
        0,
        1,
      );
    await tester.pumpAndSettle();
    await tester.runAsync(() => capture('graph-detail-preview'));
    await tester.tap(find.text('기업 분석'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => capture('graph-node-preview'));
    await tester.tap(find.byTooltip('가지 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('노드 모양'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => capture('graph-shapes-preview'));
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('손글씨'));
    await tester.pumpAndSettle();
    final canvas = find.byKey(const ValueKey('handwriting-canvas'));
    final start = tester.getTopLeft(canvas) + const Offset(50, 100);
    await tester.dragFrom(start, const Offset(120, 60));
    await tester.pumpAndSettle();
    await tester.runAsync(() => capture('handwriting-preview'));
  });
}
