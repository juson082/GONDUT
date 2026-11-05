import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memo_graph/main.dart';

void main() {
  test(
    'selected text respects reversed ranges and the editor trailing newline',
    () {
      const source = '시작\n선택한 내용';
      expect(
        selectedNoteText(
          source,
          const TextSelection(baseOffset: 3, extentOffset: 9),
        ),
        '선택한 내용',
      );
      expect(
        selectedNoteText(
          source,
          const TextSelection(baseOffset: 9, extentOffset: 3),
        ),
        '선택한 내용',
      );
      expect(
        selectedNoteText(
          source,
          TextSelection(baseOffset: 0, extentOffset: source.length + 1),
        ),
        source,
      );
      expect(
        selectedNoteText(source, const TextSelection.collapsed(offset: 0)),
        isNull,
      );
      expect(
        selectedNoteText(
          source,
          const TextSelection(baseOffset: 2, extentOffset: 3),
        ),
        isNull,
      );
      expect(
        selectedNoteText(
          source,
          const TextSelection(baseOffset: 0, extentOffset: 99),
        ),
        isNull,
      );
    },
  );
}
