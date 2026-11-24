import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:memo_graph/main.dart';
import 'package:memo_graph/store.dart';
import 'package:memo_graph/spotlight_tutorial.dart';

class TutorialTestStore extends Store {
  bool completed = false;
  int notesCreated = 0;
  @override
  Future<bool> tutorialComplete() async => completed;
  @override
  Future<void> setTutorialComplete() async {
    completed = true;
  }

  @override
  Future<List<Map<String, Object?>>> memos([String query = '']) async => [];
  @override
  Future<List<Map<String, Object?>>> folders() async => [];
  @override
  Future<List<Map<String, Object?>>> nodes() async => [];
  @override
  Future<List<Map<String, Object?>>> edges() async => [];
  @override
  Future<int> addMemo(String text) async {
    notesCreated++;
    return 1;
  }
}

void main() {
  testWidgets('new users see a complete tour without creating a note', (
    tester,
  ) async {
    final store = TutorialTestStore();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: const [Locale('ko'), Locale('en')],
        localizationsDelegates: const [
          ...GlobalMaterialLocalizations.delegates,
          quill.FlutterQuillLocalizations.delegate,
        ],
        home: Home(store),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SpotlightTutorial), findsOneWidget);
    expect(find.text('새 메모에서 노트, 그래프, 폴더를 만들어요.'), findsOneWidget);
    for (var i = 0; i < 9; i++) {
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
    }
    expect(find.text('완료'), findsOneWidget);
    await tester.tap(find.text('완료'));
    await tester.pumpAndSettle();
    expect(store.completed, isTrue);
    expect(store.notesCreated, 0);
    expect(find.byType(SpotlightTutorial), findsNothing);
  });

  testWidgets('completed tour stays hidden and can be replayed', (
    tester,
  ) async {
    final store = TutorialTestStore()..completed = true;
    await tester.pumpWidget(MaterialApp(home: Home(store)));
    await tester.pumpAndSettle();
    expect(find.byType(SpotlightTutorial), findsNothing);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('How to use'));
    await tester.pumpAndSettle();
    expect(find.byType(SpotlightTutorial), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.byType(SpotlightTutorial), findsNothing);
  });
}
