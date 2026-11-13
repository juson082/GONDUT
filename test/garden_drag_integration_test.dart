import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:memo_graph/garden_person.dart';
import 'package:memo_graph/memo_tree.dart';
import 'package:memo_graph/store.dart';

class _GraphStore extends Store {
  final rows = <Map<String, Object?>>[
    {
      'id': 1,
      'memo_id': 1,
      'parent_id': null,
      'text': 'branch',
      'position': 1,
      'x': 2800.0,
      'y': 2550.0,
    },
  ];
  @override
  Future<bool> charactersEnabled() async => true;
  @override
  Future<List<Map<String, Object?>>> branches(int memoId) async =>
      rows.map((e) => Map<String, Object?>.of(e)).toList();
}

void main() {
  testWidgets('dropping onto a node lands above its text', (tester) async {
    final store = _GraphStore();
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
        home: Scaffold(body: MemoTree(store: store, memoId: 1)),
      ),
    );
    await tester.pumpAndSettle();
    final character = find.bySemanticsLabel('소인 캐릭터');
    final start = tester.getCenter(character);
    final target = tester.getCenter(find.text('branch'));
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(target);
    await tester.pump();
    await gesture.up();
    await tester.pump();
    final updated = tester.widget<GardenPerson>(find.byType(GardenPerson));
    expect(updated.route.branchId, -1);
    expect(updated.route.points.single.dy, closeTo(2550, .1));
    expect(store.rows.single['y'], 2550.0);
  });
  testWidgets(
    'full-canvas people leave node taps working and drag without moving nodes',
    (tester) async {
      final store = _GraphStore();
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
          home: Scaffold(body: MemoTree(store: store, memoId: 1)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GardenPerson), findsOneWidget);
      await tester.tap(find.text('branch'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('가지 메뉴'), findsOneWidget);
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();

      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      final transform = viewer.transformationController!;
      final savedTransform = transform.value.clone();
      transform.value = Matrix4.diagonal3Values(.2, .2, 1);
      await tester.pump();
      expect(
        tester.widget<GardenPerson>(find.byType(GardenPerson)).hitSize,
        220,
      );
      transform.value = savedTransform;
      await tester.pump();
      final beforePan = transform.value.getTranslation().clone();
      final corner =
          tester.getTopLeft(find.byType(InteractiveViewer)) +
          const Offset(20, 20);
      await tester.dragFrom(corner, const Offset(40, 15));
      await tester.pump();
      expect(transform.value.getTranslation(), isNot(beforePan));

      final character = find.bySemanticsLabel('소인 캐릭터');
      expect(character, findsOneWidget);
      final gesture = await tester.startGesture(tester.getCenter(character));
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveBy(const Offset(80, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      final updated = tester.widget<GardenPerson>(find.byType(GardenPerson));
      expect(updated.route.branchId, -1);
      expect(store.rows.single['x'], 2800.0);
      expect(store.rows.single['y'], 2550.0);
    },
  );
}
