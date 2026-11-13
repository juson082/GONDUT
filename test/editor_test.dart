import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memo_graph/main.dart';
import 'package:memo_graph/store.dart';
import 'package:memo_graph/paper_theme.dart';
import 'package:memo_graph/memo_tree.dart';
import 'package:memo_graph/tree_preview.dart';
import 'package:memo_graph/garden_person.dart';
import 'package:memo_graph/handwriting_pad.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_localizations/flutter_localizations.dart';

class MemoryStore extends Store {
  String value = '';
  String? savedRichText;
  String? savedInk;
  String? savedTitle;
  String theme = 'lavender';
  String language = 'system';
  bool showCharacters = true;
  String? createdKind;
  @override
  Future<int> addMemo(String text) async => 1;
  @override
  Future<List<Map<String, Object?>>> folders() async => [];
  @override
  Future<void> setMemoKind(int id, String kind) async {
    createdKind = kind;
  }

  @override
  Future<void> saveBranchContent(
    int memoId,
    int branchId,
    String title,
    String text,
    String richText, {
    String? ink,
  }) async {
    final row = treeItems.firstWhere((r) => r['id'] == branchId);
    row['title'] = title;
    row['text'] = text;
    row['rich_text'] = richText;
    row['ink'] = ink;
  }

  @override
  Future<bool> charactersEnabled() async => showCharacters;
  @override
  Future<void> setCharactersEnabled(bool enabled) async {
    showCharacters = enabled;
  }

  final List<Map<String, Object?>> treeItems = [];
  @override
  Future<List<Map<String, Object?>>> memos([String query = '']) async => [];
  @override
  Future<List<Map<String, Object?>>> nodes() async => [];
  @override
  Future<List<Map<String, Object?>>> edges() async => [];
  @override
  Future<List<Map<String, Object?>>> branches(int memoId) async =>
      List.of(treeItems);
  @override
  Future<void> saveMissingBranchPositions(
    int memoId,
    Map<int, (double, double)> positions,
  ) async {
    for (final entry in positions.entries) {
      final item = treeItems.firstWhere((row) => row['id'] == entry.key);
      if (item['x'] is! num || item['y'] is! num) {
        item['x'] = entry.value.$1;
        item['y'] = entry.value.$2;
      }
    }
  }

  @override
  Future<void> saveBranchPlacement(
    int memoId,
    int branchId,
    int? parentId,
    Map<int, (double, double)> placements,
  ) async {
    for (final entry in placements.entries) {
      final item = treeItems.firstWhere((row) => row['id'] == entry.key);
      item['x'] = entry.value.$1;
      item['y'] = entry.value.$2;
      if (entry.key == branchId) item['parent_id'] = parentId;
    }
  }

  @override
  Future<int> addBranch(
    int memoId,
    String text, {
    int? parentId,
    double? x,
    double? y,
  }) async {
    final id = treeItems.length + 1;
    treeItems.add({
      'id': id,
      'memo_id': memoId,
      'parent_id': parentId,
      'text': text,
      if (x != null && y != null) 'x': x,
      if (x != null && y != null) 'y': y,
      'position': id,
    });
    return id;
  }

  @override
  Future<void> renameBranch(int memoId, int branchId, String text) async {
    treeItems.firstWhere((row) => row['id'] == branchId)['text'] = text;
  }

  @override
  Future<void> setBranchShape(int memoId, int id, String shape) async {
    treeItems.firstWhere((row) => row['id'] == id)['shape'] = shape;
  }

  @override
  Future<void> setThemeName(String name) async {
    theme = name;
  }

  @override
  Future<String> languageName() async => language;
  @override
  Future<void> setLanguageName(String name) async {
    language = name;
  }

  @override
  Future<void> saveMemo(int id, String text) async {
    value = text;
  }

  @override
  Future<void> renameMemo(int id, String title) async {
    savedTitle = title.trim();
  }

  @override
  Future<void> saveRichMemo(int id, String text, String richText) async {
    value = text;
    savedRichText = richText;
  }

  @override
  Future<String?> memoInk(int id) async => savedInk;
  @override
  Future<void> saveMemoInk(int id, String ink) async {
    savedInk = ink;
  }
}

class GardenStore extends MemoryStore {
  @override
  Future<List<Map<String, Object?>>> memos([String query = '']) async => [
    {'id': 1, 'text': '한 가지 생각', 'title': null},
    {'id': 2, 'text': '비어 있는 나무', 'title': null},
  ];
  @override
  Future<List<Map<String, Object?>>> branches(int memoId) async =>
      memoId == 1 ? List.of(treeItems) : [];
}

class SelectedDraftStore extends MemoryStore {
  String? draftSource;
  List<Map<String, String>>? reviewed;
  @override
  Future<bool> appendReviewedProcessDraft(
    int memoId,
    String source,
    List<Map<String, String>> items, {
    Map<String, String>? categoryNames,
  }) async {
    draftSource = source;
    reviewed = items;
    return true;
  }
}

void main() {
  testWidgets('home can create a graph directly', (tester) async {
    final store = MemoryStore();
    await tester.pumpWidget(MemoApp(store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('새 메모'));
    await tester.pumpAndSettle();
    expect(find.text('일반 메모'), findsOneWidget);
    expect(find.text('새 폴더'), findsOneWidget);
    await tester.tap(find.text('나무 그래프'));
    await tester.pumpAndSettle();
    expect(store.createdKind, 'graph');
    expect(find.byType(MemoTree), findsOneWidget);
  });
  testWidgets('tree displays little people only when enabled', (tester) async {
    final store = MemoryStore();
    store.treeItems.add({
      'id': 1,
      'memo_id': 1,
      'parent_id': null,
      'text': '생각',
      'position': 1,
    });
    Widget tree(Key key) => MaterialApp(
      home: Scaffold(
        body: MemoTree(key: key, store: store, memoId: 1),
      ),
    );
    await tester.pumpWidget(tree(const ValueKey('on')));
    await tester.pumpAndSettle();
    expect(find.byType(GardenPerson), findsOneWidget);
    store.showCharacters = false;
    await tester.pumpWidget(tree(const ValueKey('off')));
    await tester.pumpAndSettle();
    expect(find.byType(GardenPerson), findsNothing);
    expect(store.treeItems.single['text'], '생각');
  });
  testWidgets('graph node saves and reopens its own handwriting', (
    tester,
  ) async {
    final store = MemoryStore();
    store.treeItems.add({
      'id': 1,
      'memo_id': 1,
      'parent_id': null,
      'text': '생각',
      'position': 1,
    });
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: const [Locale('ko')],
        localizationsDelegates: [
          ...GlobalMaterialLocalizations.delegates,
          quill.FlutterQuillLocalizations.delegate,
        ],
        home: Scaffold(body: MemoTree(store: store, memoId: 1)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('생각'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('branch-preview-edit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('손글씨'));
    await tester.pumpAndSettle();
    await tester.dragFrom(
      tester.getCenter(find.byKey(const ValueKey('handwriting-canvas'))),
      const Offset(25, 15),
    );
    await tester.pump();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(store.treeItems.single['ink'], isNotNull);
    await tester.tap(find.text('생각'));
    await tester.pumpAndSettle();
    expect(find.byType(InkPreview), findsOneWidget);
  });
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .localesTestValue = const [
      Locale('ko'),
    ];
  });
  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .clearLocalesTestValue();
  });
  testWidgets('tapping the note title edits it and displays the saved title', (
    tester,
  ) async {
    final store = MemoryStore();
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
        home: Editor(store, 1, 'body'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('내 노트'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '나의 기록');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(store.savedTitle, '나의 기록');
    expect(find.text('나의 기록'), findsOneWidget);
    await tester.tap(find.text('나의 기록'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).initialValue,
      '나의 기록',
    );
  });
  testWidgets('home shows the saved tree only for the matching note', (
    tester,
  ) async {
    final store = GardenStore();
    store.treeItems.add({
      'id': 1,
      'memo_id': 1,
      'parent_id': null,
      'text': '가지',
      'x': 3000.0,
      'y': 2700.0,
    });
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: const [Locale('ko')],
        localizationsDelegates: [
          ...GlobalMaterialLocalizations.delegates,
          quill.FlutterQuillLocalizations.delegate,
        ],
        home: Home(store),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tree-preview-1')), findsOneWidget);
    expect(find.byType(TreePreview), findsOneWidget);
    expect(find.text('비어 있는 나무'), findsOneWidget);
    expect(store.treeItems.single['x'], 3000.0);
  });
  testWidgets('leaving editor saves the latest text', (tester) async {
    final store = MemoryStore();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: const [Locale('ko'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          quill.FlutterQuillLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => Editor(store, 1, 'old')),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final editor = tester.widget<quill.QuillEditor>(
      find.byType(quill.QuillEditor),
    );
    editor.controller.replaceText(
      0,
      3,
      '새 메모',
      const TextSelection.collapsed(offset: 4),
    );
    editor.controller.formatText(0, 1, quill.Attribute.bold);
    await tester.pump();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(store.value, '새 메모');
    expect(store.savedRichText, contains('"bold":true'));
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('note color follows the application theme', (tester) async {
    final store = MemoryStore();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: const [Locale('ko'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          quill.FlutterQuillLocalizations.delegate,
        ],
        home: Editor(store, 1, 'hello'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('메모 색상'), findsNothing);
    expect(find.byTooltip('손글씨'), findsOneWidget);
  });

  testWidgets('switching a memo to its tree lets the user add a branch', (
    tester,
  ) async {
    final store = MemoryStore();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: const [Locale('ko'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          quill.FlutterQuillLocalizations.delegate,
        ],
        home: Editor(store, 1, 'my note'),
      ),
    );
    await tester.tap(find.byTooltip('나무 그래프'));
    await tester.pumpAndSettle();
    final canvasCenter = tester.getCenter(find.byType(InteractiveViewer));
    await tester.tapAt(canvasCenter + const Offset(110, -110));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(canvasCenter + const Offset(110, -110));
    await tester.pumpAndSettle();
    tester
        .widget<quill.QuillEditor>(find.byType(quill.QuillEditor).last)
        .controller
        .document
        .insert(0, '첫 생각');
    await tester.pump();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('첫 생각'), findsOneWidget);
    expect(store.treeItems.single['memo_id'], 1);
  });

  testWidgets('handwriting saves and reopens as ink', (tester) async {
    final store = MemoryStore();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: const [Locale('ko'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          quill.FlutterQuillLocalizations.delegate,
        ],
        home: Editor(store, 1, 'note'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('손글씨'));
    await tester.pumpAndSettle();
    final pad = find.byKey(const ValueKey('handwriting-canvas'));
    final start = tester.getCenter(pad);
    await tester.dragFrom(start, const Offset(35, 25));
    await tester.pumpAndSettle();
    expect(store.savedInk, isNotNull);
    expect(store.savedInk, isNot('[]'));
    await tester.tap(find.byTooltip('마지막 획 되돌리기'));
    await tester.pumpAndSettle();
    expect(store.savedInk, '[]');
    await tester.tap(find.byTooltip('마지막 획 다시 실행'));
    await tester.pumpAndSettle();
    expect(store.savedInk, isNot('[]'));
    await tester.tap(find.byTooltip('글쓰기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('손글씨'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('마지막 획 되돌리기'), findsOneWidget);
  });

  testWidgets(
    'zoomed-out tree keeps text and restores editing controls when zoomed in',
    (tester) async {
      final store = MemoryStore();
      store.treeItems.add({
        'id': 1,
        'memo_id': 1,
        'parent_id': null,
        'text': '내 생각',
        'position': 1,
      });
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ko'),
          supportedLocales: const [Locale('ko')],
          localizationsDelegates: [
            ...GlobalMaterialLocalizations.delegates,
            quill.FlutterQuillLocalizations.delegate,
          ],
          home: Scaffold(body: MemoTree(store: store, memoId: 1)),
        ),
      );
      await tester.pumpAndSettle();
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      viewer.transformationController!.value = Matrix4.diagonal3Values(
        .5,
        .5,
        1,
      );
      await tester.pump();
      expect(find.text('내 생각'), findsOneWidget);
      expect(find.text('+ 가지'), findsNothing);
      viewer.transformationController!.value = Matrix4.identity();
      await tester.pump();
      expect(find.text('+ 가지'), findsNothing);
      expect(store.treeItems.single['text'], '내 생각');
      final center = tester.getCenter(find.byType(InteractiveViewer));
      final left = await tester.startGesture(
        center + const Offset(-80, 0),
        pointer: 1,
      );
      final right = await tester.startGesture(
        center + const Offset(80, 0),
        pointer: 2,
      );
      await left.moveTo(center + const Offset(-40, 0));
      await right.moveTo(center + const Offset(40, 0));
      await tester.pump();
      expect(viewer.transformationController!.value.storage[0], lessThan(.9));
      await left.up();
      await right.up();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('전체 보기'));
      await tester.pumpAndSettle();
      expect(
        viewer.transformationController!.value.storage[0],
        greaterThan(.5),
      );
    },
  );

  testWidgets('long pressing a branch moves and saves its position', (
    tester,
  ) async {
    final store = MemoryStore();
    store.treeItems.add({
      'id': 1,
      'memo_id': 1,
      'parent_id': null,
      'text': '이동할 가지',
      'position': 1,
    });
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: const [Locale('ko')],
        localizationsDelegates: [
          ...GlobalMaterialLocalizations.delegates,
          quill.FlutterQuillLocalizations.delegate,
        ],
        home: Scaffold(body: MemoTree(store: store, memoId: 1)),
      ),
    );
    await tester.pumpAndSettle();
    final start = tester.getCenter(find.text('이동할 가지'));
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(80, 35));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(store.treeItems.single['x'], isA<double>());
    expect(store.treeItems.single['y'], isA<double>());
    final moved = store.treeItems.single['x'];
    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    expect(store.treeItems.single['x'], isNot(moved));
  });

  testWidgets('tapping a branch reveals its text and editing actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final store = MemoryStore();
    store.treeItems.add({
      'id': 1,
      'memo_id': 1,
      'parent_id': null,
      'text': '기존 생각',
      'position': 1,
    });
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: const [Locale('ko')],
        localizationsDelegates: [
          ...GlobalMaterialLocalizations.delegates,
          quill.FlutterQuillLocalizations.delegate,
        ],
        home: Scaffold(body: MemoTree(store: store, memoId: 1)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('이 메모의 생각 나무'), findsNothing);
    await tester.tap(find.text('기존 생각'));
    await tester.pumpAndSettle();
    expect(find.text('내용을 눌러 수정'), findsNothing);
    expect(find.text('가지 추가'), findsNothing);
    await tester.tap(find.byTooltip('가지 메뉴'));
    await tester.pumpAndSettle();
    expect(find.text('가지 추가'), findsNothing);
    expect(find.text('연결 변경'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('branch-preview-edit')));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(quill.QuillEditor).last).width,
      greaterThan(300),
    );
    await tester.enterText(find.byType(TextField), '노드 제목');
    final nodeEditor = tester.widget<quill.QuillEditor>(
      find.byType(quill.QuillEditor).last,
    );
    nodeEditor.controller.replaceText(
      0,
      nodeEditor.controller.document.length - 1,
      '수정한 생각\n두 번째 줄',
      const TextSelection.collapsed(offset: 0),
    );
    await tester.pump();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(store.treeItems.single['text'], '수정한 생각\n두 번째 줄');
    await tester.tap(find.text('노드 제목'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('branch-preview-edit')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<quill.QuillEditor>(find.byType(quill.QuillEditor).last)
          .controller
          .document
          .toPlainText()
          .trim(),
      '수정한 생각\n두 번째 줄',
    );
  });

  testWidgets(
    'recognized handwriting is reviewed before being added to the note',
    (tester) async {
      final store = MemoryStore();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel('memo_graph/handwriting');
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'recognize');
        expect(call.arguments['language'], 'ko');
        expect(call.arguments['strokes'], isNotEmpty);
        return '인식된 문장';
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
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
          home: Editor(store, 1, '기존 메모'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('손글씨'));
      await tester.pumpAndSettle();
      await tester.dragFrom(
        tester.getCenter(find.byKey(const ValueKey('handwriting-canvas'))),
        const Offset(35, 25),
      );
      await tester.pump(const Duration(milliseconds: 1700));
      await tester.pumpAndSettle();
      expect(find.text('인식된 문장'), findsOneWidget);
      final ink = store.savedInk;
      await tester.tap(find.text('글자로 변환'));
      await tester.pumpAndSettle();
      expect(find.text('변환 결과 확인'), findsOneWidget);
      expect(store.value, isNot(contains('인식된 문장')));
      await tester.enterText(find.byType(TextField), '사용자가 수정한 문장');
      await tester.tap(find.text('메모에 추가'));
      await tester.pumpAndSettle();
      expect(store.value, '기존 메모\n사용자가 수정한 문장');
      expect(store.savedInk, ink);
      await tester.pump(const Duration(milliseconds: 600));
    },
  );

  testWidgets('settings changes and saves the app theme', (tester) async {
    final store = MemoryStore();
    await tester.pumpWidget(MemoApp(store));
    await tester.pumpAndSettle();
    final originalBackground = Theme.of(
      tester.element(find.byType(Scaffold).first),
    ).scaffoldBackgroundColor;
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('설정 · 테마'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('이끼'));
    await tester.tap(find.text('이끼'));
    await tester.pumpAndSettle();
    expect(store.theme, 'sage');
    final updated = Theme.of(tester.element(find.byType(Scaffold).first));
    expect(updated.scaffoldBackgroundColor, isNot(originalBackground));
    expect(
      updated.scaffoldBackgroundColor,
      paperTheme('sage').scaffoldBackgroundColor,
    );
    expect(
      updated.colorScheme.primaryContainer,
      paperTheme('sage').colorScheme.primaryContainer,
    );
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).colorScheme.primary,
      paperTheme('sage').colorScheme.primary,
    );
  });

  testWidgets(
    'unsupported device language defaults to English and user can override',
    (tester) async {
      tester.binding.platformDispatcher.localesTestValue = const [Locale('fr')];
      final store = MemoryStore();
      await tester.pumpWidget(MemoApp(store));
      await tester.pumpAndSettle();
      expect(find.text('New note'), findsOneWidget);
      expect(
        Theme.of(
          tester.element(find.text('New note')),
        ).textTheme.bodyMedium?.fontFamily,
        'GondutHand',
      );
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings · theme'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('한국어'));
      await tester.pumpAndSettle();
      expect(store.language, 'ko');
      expect(find.text('새 메모'), findsOneWidget);
      expect(
        Theme.of(
          tester.element(find.text('새 메모')),
        ).textTheme.bodyMedium?.fontFamily,
        'GondutHand',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(MemoApp(store, initialLanguage: store.language));
      await tester.pumpAndSettle();
      expect(find.text('새 메모'), findsOneWidget);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('설정 · 테마'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('기기 설정 따르기'));
      await tester.pumpAndSettle();
      expect(store.language, 'system');
      expect(find.text('New note'), findsOneWidget);
    },
  );

  for (final entry in <(String, String)>[
    ('ja', '新しいメモ'),
    ('zh', '新建笔记'),
    ('es', 'Nueva nota'),
  ]) {
    testWidgets('device language ${entry.$1} selects translated interface', (
      tester,
    ) async {
      tester.binding.platformDispatcher.localesTestValue = [Locale(entry.$1)];
      await tester.pumpWidget(MemoApp(MemoryStore()));
      await tester.pumpAndSettle();
      expect(find.text(entry.$2), findsOneWidget);
      expect(
        Theme.of(
          tester.element(find.text(entry.$2)),
        ).textTheme.bodyMedium?.fontFamily,
        'GondutHand',
      );
    });
  }

  for (final entry in <(String, String, String)>[
    ('ko', '빈 곳을 두 번 눌러 노드를 추가하세요', 'AI 과정 초안'),
    ('en', 'Double-tap an empty spot to add a node', 'AI process draft'),
    ('ja', '空いている場所をダブルタップしてノードを追加', 'AIの過程下書き'),
    ('zh', '双击空白处添加节点', 'AI 过程草稿'),
    (
      'es',
      'Toca dos veces un espacio vacío para añadir un nodo',
      'Borrador de proceso con IA',
    ),
  ]) {
    testWidgets('tree controls use the selected ${entry.$1} language', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(entry.$1),
          supportedLocales: [Locale(entry.$1)],
          localizationsDelegates: [
            ...GlobalMaterialLocalizations.delegates,
            quill.FlutterQuillLocalizations.delegate,
          ],
          home: Scaffold(body: MemoTree(store: MemoryStore(), memoId: 1)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(entry.$2), findsOneWidget);
      expect(find.text(entry.$3), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the editor fits a phone with Spanish labels', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          quill.FlutterQuillLocalizations.delegate,
        ],
        home: Editor(MemoryStore(), 1, 'note'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Manuscrito'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a manually selected language overrides the device language', (
    tester,
  ) async {
    tester.binding.platformDispatcher.localesTestValue = const [Locale('ko')];
    final store = MemoryStore();
    await tester.pumpWidget(MemoApp(store));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('설정 · 테마'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Español'));
    await tester.tap(find.text('Español'));
    await tester.pumpAndSettle();
    expect(store.language, 'es');
    expect(find.text('Nueva nota'), findsOneWidget);
  });
}
