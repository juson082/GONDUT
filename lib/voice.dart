import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

class VoiceRecorder {
  final AudioRecorder recorder = AudioRecorder();
  Future<List<FileSystemEntity>> recordings() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/recordings');
    if (!await dir.exists()) return [];
    final files = await dir
        .list()
        .where((entry) =>
            entry is File && entry.path.toLowerCase().endsWith('.wav'))
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  Future<String> start() async {
    if (!await recorder.hasPermission()) throw StateError('마이크 권한이 필요합니다');
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/recordings');
    await dir.create(recursive: true);
    final path = '${dir.path}/${DateTime.now().microsecondsSinceEpoch}.wav';
    await recorder.start(
        const RecordConfig(
            encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
        path: path);
    return path;
  }

  Future<String?> stop() => recorder.stop();
  Future<void> dispose() => recorder.dispose();
}

Future<String> transcribe(String wavePath) async {
  final root = await getApplicationSupportDirectory();
  final modelDir = Directory('${root.path}/whisper-tiny-v1');
  await modelDir.create(recursive: true);
  for (final entry in <String, int>{
    'tiny-encoder.int8.onnx': 12937772,
    'tiny-decoder.int8.onnx': 89855401,
    'tiny-tokens.txt': 816730,
  }.entries) {
    final name = entry.key;
    final file = File('${modelDir.path}/$name');
    if (!await file.exists() || await file.length() != entry.value) {
      final asset = await rootBundle.load('assets/whisper/$name');
      await file.writeAsBytes(
          asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes),
          flush: true);
    }
  }
  return compute(_decode, [modelDir.path, wavePath]);
}

String _decode(List<String> paths) {
  sherpa.initBindings();
  final dir = paths[0];
  final model = sherpa.OfflineModelConfig(
      whisper: sherpa.OfflineWhisperModelConfig(
          encoder: '$dir/tiny-encoder.int8.onnx',
          decoder: '$dir/tiny-decoder.int8.onnx',
          task: 'transcribe'),
      tokens: '$dir/tiny-tokens.txt',
      modelType: 'whisper',
      numThreads: 2,
      debug: false);
  final recognizer =
      sherpa.OfflineRecognizer(sherpa.OfflineRecognizerConfig(model: model));
  try {
    final wave = sherpa.readWave(paths[1]);
    final pieces = <String>[];
    final chunkSize = wave.sampleRate * 25;
    for (var start = 0; start < wave.samples.length; start += chunkSize) {
      final end = (start + chunkSize).clamp(0, wave.samples.length);
      final stream = recognizer.createStream();
      try {
        stream.acceptWaveform(
            samples: wave.samples.sublist(start, end),
            sampleRate: wave.sampleRate);
        recognizer.decode(stream);
        final text = recognizer.getResult(stream).text.trim();
        if (text.isNotEmpty) pieces.add(text);
      } finally {
        stream.free();
      }
    }
    return pieces.join('\n');
  } finally {
    recognizer.free();
  }
}

/// Each draft is an exact sentence from the source; no generated facts.
List<Map<String, String>> extractDraft(String text) {
  final parts = text
      .split(RegExp(r'(?<=[.!?。！？])\s+|\n+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty);
  final rules = <String, RegExp>{
    '결정': RegExp(r'결정|선택|하기로|decided|chose', caseSensitive: false),
    '회고': RegExp(r'돌아보|회고|놓쳤|고려하지|should have|realized', caseSensitive: false),
    '결과': RegExp(r'결과|손해|손실|성공|실패|result|lost|failed', caseSensitive: false),
    '후속 계획': RegExp(r'다음|앞으로|계획|해야겠|next|plan to', caseSensitive: false),
  };
  return [
    for (final part in parts)
      for (final entry in rules.entries)
        if (entry.value.hasMatch(part)) {'kind': entry.key, 'quote': part}
  ];
}

class ExplicitCommand {
  const ExplicitCommand(this.tree, this.parent, this.content);
  final String tree, parent, content;
}

/// A free-form recording may name its intended destination explicitly. Do not
/// infer a destination from semantic similarity or from model output.
({String tree, String parent})? parseDraftDestination(String text) {
  final patterns = [
    RegExp(
        r'^\s*(?<tree>.+?)\s*트리(?:의)?\s+(?<parent>.+?)\s*노드(?:의)?\s*아래(?:에|에서)?\s*[:：]\s*\S'),
    RegExp(
        r'^\s*in\s+(?:the\s+)?(?<tree>.+?)\s+tree\s+under\s+(?:the\s+)?(?<parent>.+?)\s+node\s*[:：]\s*\S',
        caseSensitive: false),
    RegExp(r'^\s*(?<tree>.+?)\s*ツリーの\s*(?<parent>.+?)\s*ノードの下\s*[:：]\s*\S'),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(text);
    if (match == null) continue;
    final tree = match.namedGroup('tree')!.trim();
    final parent = match.namedGroup('parent')!.trim();
    if (tree.isNotEmpty && parent.isNotEmpty)
      return (tree: tree, parent: parent);
  }
  return null;
}

ExplicitCommand? parseCommand(String text) {
  // Only accept explicit templates; everything else remains an inbox memo.
  final patterns = <RegExp>[
    RegExp(
        r'^\s*(?<tree>.+?)\s*트리(?:의)?\s+(?<parent>.+?)(?:\s*노드(?:의)?)?\s*아래(?:에)?\s+(?<content>.+?)\s*메모(?:를)?\s*추가(?:해|해줘|해주세요)?[.!?。]?\s*$'),
    RegExp(
        r'^\s*add\s+(?:a\s+)?note\s+(?<content>.+?)\s+under\s+(?:the\s+)?(?<parent>.+?)\s+node\s+in\s+(?:the\s+)?(?<tree>.+?)\s+tree[.!?]?\s*$',
        caseSensitive: false),
    RegExp(
        r'^\s*add\s+(?:a\s+)?note\s+(?<content>.+?)\s+to\s+(?:the\s+)?(?<tree>.+?)\s+tree\s+under\s+(?:the\s+)?(?<parent>.+?)\s+node[.!?]?\s*$',
        caseSensitive: false),
    RegExp(
        r'^\s*(?<tree>.+?)\s*ツリーの\s*(?<parent>.+?)\s*ノードの下に\s*(?<content>.+?)\s*(?:という)?メモを追加(?:して|してください)?[。.!?]?\s*$'),
    RegExp(
        r'^\s*(?:añade|agrega)\s+(?:la\s+)?nota\s+(?<content>.+?)\s+debajo\s+del\s+nodo\s+(?<parent>.+?)\s+del\s+árbol\s+(?<tree>.+?)[.!?]?\s*$',
        caseSensitive: false),
    RegExp(
        r"^\s*ajoute\s+(?:la\s+)?note\s+(?<content>.+?)\s+sous\s+le\s+nœud\s+(?<parent>.+?)\s+de\s+l['’]arbre\s+(?<tree>.+?)[.!?]?\s*$",
        caseSensitive: false),
    RegExp(
        r'^\s*adicionar\s+(?:a\s+)?nota\s+(?<content>.+?)\s+abaixo\s+do\s+nó\s+(?<parent>.+?)\s+da\s+árvore\s+(?<tree>.+?)[.!?]?\s*$',
        caseSensitive: false),
    RegExp(
        r'^\s*在\s*(?<tree>.+?)\s*树(?:的)?\s*(?<parent>.+?)\s*节点下(?:面)?\s*添加(?:一条)?\s*(?<content>.+?)\s*笔记[。.!?]?\s*$'),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(text);
    if (match == null) continue;
    final tree = match.namedGroup('tree')!.trim();
    final parent = match.namedGroup('parent')!.trim();
    final content = match.namedGroup('content')!.trim();
    if (tree.isNotEmpty && parent.isNotEmpty && content.isNotEmpty) {
      return ExplicitCommand(tree, parent, content);
    }
  }
  return null;
}
