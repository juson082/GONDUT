import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'store.dart';
import 'app_strings.dart';
import 'ink_recognition.dart';
import 'notebook_motion.dart';

/// Ink coordinates are normalized, so the drawing survives a size change.
class HandwritingPad extends StatefulWidget {
  const HandwritingPad({
    super.key,
    required this.store,
    required this.memoId,
    required this.onUseText,
  });
  final Store store;
  final int memoId;
  final Future<void> Function(String text, bool createGraph) onUseText;
  @override
  State<HandwritingPad> createState() => _HandwritingPadState();
}

class _HandwritingPadState extends State<HandwritingPad> {
  List<List<Offset>> strokes = [];
  final List<List<Offset>> undoneStrokes = [];
  bool loading = true;
  bool failed = false;
  bool recognizing = false;
  String? language;
  Future<void> pending = Future.value();
  Timer? recognitionTimer;
  int revision = 0;
  String? automaticText;
  double canvasAspect = 1024 / 1400;

  @override
  void dispose() {
    recognitionTimer?.cancel();
    super.dispose();
  }

  void scheduleRecognition() {
    revision++;
    recognitionTimer?.cancel();
    if (strokes.isEmpty) {
      setState(() => automaticText = null);
      return;
    }
    final current = revision;
    recognitionTimer = Timer(const Duration(milliseconds: 1600), () async {
      if (!mounted || current != revision) return;
      final snapshot = strokes.map((s) => List<Offset>.of(s)).toList();
      final lang =
          language ??
          (handwritingLanguages.containsKey(
                Localizations.localeOf(context).languageCode,
              )
              ? Localizations.localeOf(context).languageCode
              : 'en');
      setState(() => recognizing = true);
      try {
        final text = await recognizeHandwriting(
          snapshot,
          lang,
          aspectRatio: canvasAspect,
        );
        if (mounted && current == revision)
          setState(() => automaticText = text);
      } catch (_) {
        if (mounted && current == revision) setState(() => automaticText = '');
      } finally {
        if (mounted && current == revision) setState(() => recognizing = false);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await widget.store.memoInk(widget.memoId);
      if (data != null) {
        final raw = jsonDecode(data) as List;
        strokes = raw
            .map(
              (stroke) => (stroke as List).map((point) {
                final p = point as List;
                return Offset(
                  (p[0] as num).toDouble(),
                  (p[1] as num).toDouble(),
                );
              }).toList(),
            )
            .toList();
      }
      if (mounted) setState(() => loading = false);
    } catch (_) {
      if (mounted)
        setState(() {
          loading = false;
          failed = true;
        });
    }
  }

  void save() {
    final data = jsonEncode(
      strokes.map((s) => s.map((p) => [p.dx, p.dy]).toList()).toList(),
    );
    pending = pending
        .catchError((_) {})
        .then((_) => widget.store.saveMemoInk(widget.memoId, data));
    pending.catchError((_) {
      if (mounted) setState(() => failed = true);
    });
  }

  Future<void> recognize() async {
    if (strokes.isEmpty) return;
    recognitionTimer?.cancel();
    revision++;
    setState(() => recognizing = true);
    try {
      await pending;
      if (!mounted) return;
      final lang =
          language ??
          (handwritingLanguages.containsKey(
                Localizations.localeOf(context).languageCode,
              )
              ? Localizations.localeOf(context).languageCode
              : 'en');
      final text = automaticText?.isNotEmpty == true
          ? automaticText!
          : await recognizeHandwriting(
              strokes.map((s) => List<Offset>.of(s)).toList(),
              lang,
              aspectRatio: canvasAspect,
            );
      if (!mounted) return;
      if (text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr(context, '손글씨를 읽지 못했습니다. 글씨와 언어를 확인해 주세요.')),
          ),
        );
        return;
      }
      final controller = TextEditingController(text: text);
      final result = await showDialog<(String, bool)>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(tr(context, '변환 결과 확인')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(context, '인식 결과를 확인하고 수정해 주세요. 손글씨 원본은 그대로 보관됩니다.')),
                TextField(
                  controller: controller,
                  autofocus: false,
                  minLines: 3,
                  maxLines: 8,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(tr(context, '취소')),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, (controller.text.trim(), false)),
              child: Text(tr(context, '메모에 추가')),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, (controller.text.trim(), true)),
              child: Text(tr(context, '추가하고 AI 그래프 만들기')),
            ),
          ],
        ),
      );
      // Let the dialog exit animation finish using its text field before disposal.
      Future<void>.delayed(
        const Duration(milliseconds: 500),
        controller.dispose,
      );
      if (!mounted || result == null) return;
      if (result.$1.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr(context, '추가할 텍스트가 없습니다.'))));
        return;
      }
      await widget.onUseText(result.$1, result.$2);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, '변환하지 못했습니다. 손글씨 원본은 보관됩니다.'))),
        );
    } finally {
      if (mounted) setState(() => recognizing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return Center(child: CircularProgressIndicator());
    if (failed)
      return Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(tr(context, '손글씨를 불러오거나 저장하지 못했습니다. 기존 백업을 확인해 주세요.')),
        ),
      );
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(child: Text(tr(context, '손가락이나 펜으로 적어 보세요'))),
              NotebookPress(
                enabled: strokes.isNotEmpty,
                child: IconButton(
                  tooltip: tr(context, '마지막 획 되돌리기'),
                  onPressed: strokes.isEmpty
                      ? null
                      : () {
                          setState(
                            () => undoneStrokes.add(strokes.removeLast()),
                          );
                          save();
                          scheduleRecognition();
                        },
                  icon: Icon(Icons.undo),
                ),
              ),
              NotebookPress(
                enabled: undoneStrokes.isNotEmpty,
                child: IconButton(
                  tooltip: tr(context, '마지막 획 다시 실행'),
                  onPressed: undoneStrokes.isEmpty
                      ? null
                      : () {
                          setState(
                            () => strokes.add(undoneStrokes.removeLast()),
                          );
                          save();
                          scheduleRecognition();
                        },
                  icon: const Icon(Icons.redo),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value:
                      language ??
                      (handwritingLanguages.containsKey(
                            Localizations.localeOf(context).languageCode,
                          )
                          ? Localizations.localeOf(context).languageCode
                          : 'en'),
                  items: [
                    for (final entry in handwritingLanguages.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      language = value;
                      automaticText = null;
                    });
                    scheduleRecognition();
                  },
                ),
              ),
              const SizedBox(width: 8),
              NotebookPress(
                enabled: !recognizing && strokes.isNotEmpty,
                child: FilledButton.tonal(
                  onPressed: recognizing || strokes.isEmpty ? null : recognize,
                  child: Text(
                    tr(context, recognizing ? '손글씨 인식 중…' : '글자로 변환'),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                recognizing
                    ? tr(context, '손글씨 인식 중…')
                    : (automaticText == ''
                          ? tr(context, '손글씨를 읽지 못했습니다. 글씨와 언어를 확인해 주세요.')
                          : automaticText ?? ''),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, size) {
              if (size.maxHeight > 0)
                canvasAspect = size.maxWidth / size.maxHeight;
              Offset normalized(Offset p) => Offset(
                (p.dx / size.maxWidth).clamp(0, 1),
                (p.dy / size.maxHeight).clamp(0, 1),
              );
              return Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) => setState(() {
                  recognitionTimer?.cancel();
                  revision++;
                  recognizing = false;
                  automaticText = null;
                  undoneStrokes.clear();
                  strokes.add([normalized(e.localPosition)]);
                }),
                onPointerMove: (e) {
                  if (strokes.isNotEmpty)
                    setState(
                      () => strokes.last.add(normalized(e.localPosition)),
                    );
                },
                onPointerUp: (_) {
                  save();
                  scheduleRecognition();
                },
                onPointerCancel: (_) {
                  save();
                  scheduleRecognition();
                },
                child: CustomPaint(
                  key: const ValueKey('handwriting-canvas'),
                  painter: _InkPainter(
                    strokes,
                    Theme.of(context).colorScheme.onSurface,
                  ),
                  child: SizedBox.expand(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _InkPainter extends CustomPainter {
  _InkPainter(this.strokes, this.color);
  final List<List<Offset>> strokes;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      Offset point(Offset p) => Offset(p.dx * size.width, p.dy * size.height);
      if (stroke.length == 1) {
        canvas.drawCircle(
          point(stroke.first),
          1.25,
          paint..style = PaintingStyle.fill,
        );
        paint.style = PaintingStyle.stroke;
        continue;
      }
      final path = Path()
        ..moveTo(point(stroke.first).dx, point(stroke.first).dy);
      for (final p in stroke.skip(1)) {
        final q = point(p);
        path.lineTo(q.dx, q.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _InkPainter oldDelegate) => true;
}
