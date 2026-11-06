import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const _channel = MethodChannel('memo_graph/handwriting');
const handwritingLanguages = <String, String>{
  'ko': '한국어',
  'en': 'English',
  'ja': '日本語',
  'zh': '中文',
  'es': 'Español',
  'fr': 'Français',
  'de': 'Deutsch',
  'it': 'Italiano',
  'pt': 'Português',
  'nl': 'Nederlands',
  'pl': 'Polski',
  'cs': 'Čeština',
  'sk': 'Slovenčina',
  'hr': 'Hrvatski',
  'bs': 'Bosanski',
  'sl': 'Slovenščina',
  'da': 'Dansk',
  'no': 'Norsk',
  'sv': 'Svenska',
  'is': 'Íslenska',
  'et': 'Eesti',
  'lt': 'Lietuvių',
  'hu': 'Magyar',
  'sq': 'Shqip',
  'cy': 'Cymraeg',
  'ga': 'Gaeilge',
  'tr': 'Türkçe',
  'id': 'Bahasa Indonesia',
  'ms': 'Bahasa Melayu',
  'af': 'Afrikaans',
  'sw': 'Kiswahili',
  'tl': 'Tagalog',
  'uz': 'Oʻzbekcha',
  'la': 'Latina',
};

Future<String> recognizeHandwriting(
  List<List<Offset>> strokes,
  String language, {
  double aspectRatio = 1024 / 1400,
}) async {
  if (strokes.isEmpty || !handwritingLanguages.containsKey(language)) {
    throw ArgumentError('Handwriting and a supported language are required');
  }
  final result = await _channel.invokeMethod<String>('recognize', {
    'language': language,
    'aspectRatio': aspectRatio,
    'strokes': strokes.map((s) => s.map((p) => [p.dx, p.dy]).toList()).toList(),
  });
  return result?.trim() ?? '';
}
