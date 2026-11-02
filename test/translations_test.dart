import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:memo_graph/app_strings.dart';
import 'package:memo_graph/extra_translations.dart';

void main() {
  test(
    'all app-owned strings have Japanese, Chinese and Spanish translations',
    () {
      final missing = <String>[];
      for (final entry in englishTranslationsForTest.entries) {
        for (final code in ['ja', 'zh', 'es']) {
          final translation = additionalTranslation(code, entry.value);
          if (translation == null || translation.trim().isEmpty)
            missing.add('$code: ${entry.key} => ${entry.value}');
        }
      }
      expect(missing, isEmpty, reason: missing.join('\n'));
    },
  );

  test('literal UI translation keys exist in the English catalog', () {
    final missing = <String>[];
    final expression = RegExp(
      r"tr\(\s*(?:context|c|sheetContext|dialogContext)\s*,\s*'((?:\\.|[^'\\])*)'",
    );
    for (final file in Directory(
      'lib',
    ).listSync().whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();
      for (final match in expression.allMatches(source)) {
        final key = match
            .group(1)!
            .replaceAll(r'\n', '\n')
            .replaceAll(r"\'", "'");
        if (!englishTranslationsForTest.containsKey(key))
          missing.add('${file.path}: $key');
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });
}
