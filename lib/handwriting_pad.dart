import 'dart:convert';
import 'package:flutter/material.dart';
import 'store.dart';
import 'app_strings.dart';
import 'garden_person.dart';
import 'garden_routes.dart';
import 'notebook_motion.dart';

/// Ink coordinates are normalized, so the drawing survives a size change.
class HandwritingPad extends StatefulWidget {
  const HandwritingPad({super.key, required this.store, required this.memoId});
  final Store store;
  final int memoId;
  @override
  State<HandwritingPad> createState() => _HandwritingPadState();
}

class _HandwritingPadState extends State<HandwritingPad> {
  List<List<Offset>> strokes = [];
  final List<List<Offset>> undoneStrokes = [];
  bool loading = true;
  bool failed = false;
  bool showCharacters = false;
  Future<void> pending = Future.value();

  @override
  void initState() {
    super.initState();
    load();
    widget.store.charactersEnabled().catchError((_) => false).then((value) {
      if (mounted) setState(() => showCharacters = value);
    });
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
                        },
                  icon: const Icon(Icons.redo),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, size) {
              Offset normalized(Offset p) => Offset(
                (p.dx / size.maxWidth).clamp(0, 1),
                (p.dy / size.maxHeight).clamp(0, 1),
              );
              return Stack(
                children: [
                  Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (e) => setState(() {
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
                    },
                    onPointerCancel: (_) {
                      save();
                    },
                    child: CustomPaint(
                      key: const ValueKey('handwriting-canvas'),
                      painter: _InkPainter(
                        strokes,
                        Theme.of(context).colorScheme.onSurface,
                      ),
                      child: SizedBox.expand(),
                    ),
                  ),
                  if (showCharacters)
                    for (final entry in inkRoutes([
                      for (final stroke in strokes)
                        [
                          for (final p in stroke)
                            Offset(p.dx * size.maxWidth, p.dy * size.maxHeight),
                        ],
                    ]).take(5).indexed)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: GardenPerson(
                            key: ValueKey('ink-person-${entry.$1}'),
                            index: entry.$1,
                            route: entry.$2,
                            sceneBounds:
                                Offset.zero &
                                Size(size.maxWidth, size.maxHeight),
                          ),
                        ),
                      ),
                ],
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

class InkPreview extends StatelessWidget {
  const InkPreview({super.key, required this.data});
  final String data;
  @override
  Widget build(BuildContext context) {
    try {
      final strokes = (jsonDecode(data) as List)
          .map(
            (s) => (s as List)
                .map(
                  (p) => Offset(
                    (p[0] as num).toDouble(),
                    (p[1] as num).toDouble(),
                  ),
                )
                .toList(),
          )
          .toList();
      if (strokes.isEmpty) return const SizedBox.shrink();
      return SizedBox(
        height: 180,
        child: CustomPaint(
          painter: _InkPainter(
            strokes,
            Theme.of(context).colorScheme.onSurface,
          ),
          child: const SizedBox.expand(),
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}
