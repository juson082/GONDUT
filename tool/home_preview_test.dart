import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memo_graph/main.dart';
import 'package:memo_graph/paper_theme.dart';
import '../test/editor_test.dart' show MemoryStore;

class _PreviewStore extends MemoryStore {
  @override
  Future<List<Map<String, Object?>>> memos([String query = '']) async => [
    {'id': 1, 'text': '투자 판단', 'title': null},
    {'id': 2, 'text': '여행 계획', 'title': null},
    {'id': 3, 'text': '새로운 아이디어', 'title': null},
  ];
  @override
  Future<List<Map<String, Object?>>> branches(int memoId) async =>
      treeItems.where((row) => row['memo_id'] == memoId).toList();
}

void main() {
  testWidgets('render home preview', (tester) async {
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final font = File('assets/Xiaolai-Regular.ttf').readAsBytesSync();
    await (FontLoader(
      'GondutHand',
    )..addFont(Future.value(font.buffer.asByteData()))).load();
    final icons = File(
      '.tools/release/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ).readAsBytesSync();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(icons.buffer.asByteData()))).load();
    final store = _PreviewStore();
    store.treeItems.addAll([
      {'id': 1, 'memo_id': 1, 'parent_id': null, 'text': '경제'},
      {'id': 2, 'memo_id': 1, 'parent_id': 1, 'text': '금리'},
      {'id': 3, 'memo_id': 1, 'parent_id': 1, 'text': '시장'},
      {'id': 4, 'memo_id': 1, 'parent_id': 2, 'text': '계획'},
      {'id': 5, 'memo_id': 2, 'parent_id': null, 'text': '여행'},
      {'id': 6, 'memo_id': 2, 'parent_id': 5, 'text': '장소'},
      {'id': 7, 'memo_id': 2, 'parent_id': 5, 'text': '일정'},
    ]);
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: const [Locale('ko')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: paperTheme('sage'),
        builder: (context, child) => RepaintBoundary(key: key, child: child!),
        home: Home(store),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'play-console/home-tree-preview.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
