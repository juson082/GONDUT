import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:memo_graph/process_draft_page.dart';
import 'package:memo_graph/store.dart';

class DraftStore extends Store {
  List<Map<String, String>>? saved;
  @override
  Future<bool> appendReviewedProcessDraft(
      int memoId, String source, List<Map<String, String>> items,
      {Map<String, String>? categoryNames}) async {
    saved = items;
    return true;
  }
}

void main() {
  testWidgets('review lets user edit or discard suggestions before saving',
      (tester) async {
    final store = DraftStore();
    await tester.pumpWidget(MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: const [Locale('ko'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: ProcessDraftPage(
          store: store,
          memoId: 1,
          source: 'First. Second.',
          items: const [
            {'kind': '관찰', 'quote': 'First.'},
            {'kind': '결과', 'quote': 'Second.'},
          ],
        )));
    expect(store.saved, isNull);
    await tester.enterText(find.byType(TextField).first, 'Edited by user');
    await tester.tap(find.byTooltip('초안 항목 삭제').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('확인한 초안을 나무에 추가'));
    await tester.tap(find.text('확인한 초안을 나무에 추가'));
    await tester.pumpAndSettle();
    expect(store.saved, [
      {'kind': '관찰', 'quote': 'Edited by user'}
    ]);
  });
}
