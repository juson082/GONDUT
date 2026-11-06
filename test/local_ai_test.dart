import 'package:flutter_test/flutter_test.dart';
import 'package:memo_graph/local_ai.dart';

void main() {
  test('explicit causes keep source text and connect cause to effect', () {
    final result = extractExplicitCauses('금리를 고려하면 주가가 하락할 것이다');
    expect(result, [
      {'kind': '이유', 'quote': '금리를', 'id': '0'},
      {'kind': '판단', 'quote': '주가가 하락할 것이다', 'id': '1', 'parent': '0'},
    ]);
    final english = extractExplicitCauses('I stayed home because it rained');
    expect(english[0]['quote'], 'it rained');
    expect(english[1]['parent'], english[0]['id']);
    expect(extractExplicitCauses('금리가 높다'), isEmpty);
  });
  test('model relationships only connect valid earlier excerpts', () {
    final result = validateLocalDraft(
      'Rain fell and the road flooded',
      '{"items":[{"kind":"reason","quote":"Rain fell"},'
          '{"kind":"outcome","quote":"the road flooded","parent":0},'
          '{"kind":"outcome","quote":"invented","parent":0}]}',
    );
    expect(result.length, 2);
    expect(result.last['parent'], result.first['id']);
  });
  test('generated title must be an exact short excerpt from the source', () {
    const source = '오늘 차를 골랐다. 내일은 쉬자.';
    expect(validateLocalTitle(source, '{"title":"차를 골랐다"}'), '차를 골랐다');
    expect(validateLocalTitle(source, '{"title":"커피를 골랐다"}'), isNull);
    expect(validateLocalTitle(source, 'invalid'), isNull);
    expect(validateLocalTitle('x' * 101, '{"title":"${'x' * 101}"}'), isNull);
  });
  test('only verbatim supported categories survive the model response', () {
    const source = 'I chose tea. Next I will rest.';
    final result = validateLocalDraft(
      source,
      '{"items":[{"kind":"decision","quote":"I chose tea"},'
      '{"kind":"plan","quote":"Next I will rest"},'
      '{"kind":"outcome","quote":"I chose coffee"},'
      '{"kind":"command","quote":"I chose tea"}]}',
    );
    expect(result, [
      {'kind': '결정', 'quote': 'I chose tea'},
      {'kind': '후속 계획', 'quote': 'Next I will rest'},
    ]);
  });

  test('unparseable responses and duplicate claims are safe', () {
    expect(
      () => validateLocalDraft('hello', 'not json'),
      throwsFormatException,
    );
    expect(
      validateLocalDraft(
        'hello',
        '{"items":[{"kind":"plan","quote":"hello"},{"kind":"plan","quote":"hello"}]}',
      ).length,
      1,
    );
  });

  test(
    'process steps require verbatim source and reject invented outcomes',
    () {
      const source = '금리가 높다. 주가가 내릴 것으로 판단했다. 내일 다시 확인할 계획이다.';
      final result = validateLocalDraft(
        source,
        '{"items":[{"kind":"observation","quote":"금리가 높다"},'
        '{"kind":"judgment","quote":"주가가 내릴 것으로 판단했다"},'
        '{"kind":"outcome","quote":"주가가 내렸다"},'
        '{"kind":"plan","quote":"내일 다시 확인할 계획이다"}]}',
      );
      expect(result, [
        {'kind': '관찰', 'quote': '금리가 높다'},
        {'kind': '판단', 'quote': '주가가 내릴 것으로 판단했다'},
        {'kind': '후속 계획', 'quote': '내일 다시 확인할 계획이다'},
      ]);
    },
  );
}
