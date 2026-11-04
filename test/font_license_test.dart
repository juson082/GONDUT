import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memo_graph/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'the bundled handwriting font notice is available in the license registry',
    () async {
      registerNotebookFontLicense();
      final entry = await LicenseRegistry.licenses.firstWhere(
        (item) => item.packages.contains('Xiaolai'),
      );
      final text = entry.paragraphs
          .map((paragraph) => paragraph.text)
          .join('\n');
      expect(text, contains('Copyright 2020-2024 LXGW'));
      expect(text, contains('Copyright 2014 Nozomi Seto'));
      expect(text, contains('SIL OPEN FONT LICENSE Version 1.1'));
    },
  );
}
