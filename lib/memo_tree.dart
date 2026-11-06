import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'store.dart';
import 'app_strings.dart';
import 'plant_layout.dart';
import 'plant_lines.dart';
import 'notebook_motion.dart';
import 'garden_person.dart';

/// A tree belongs to one memo; it never links separate memos together.
class MemoTree extends StatefulWidget {
  const MemoTree({super.key, required this.store, required this.memoId});
  final Store store;
  final int memoId;
  @override
  State<MemoTree> createState() => _MemoTreeState();
}

class _MemoTreeState extends State<MemoTree>
    with SingleTickerProviderStateMixin {
  List<Map<String, Object?>> items = [];
  final collapsed = <int>{};
  final transformation = TransformationController();
  bool fittedInitially = false;
  Map<int, Offset> visiblePositions = {};
  int? draggingId;
  Offset? dragOrigin;
  Offset? dragPosition;
  Offset? doubleTapPosition;
  Size graphViewport = Size.zero;
  static const rootPosition = Offset(2800, 2800);

  Set<int> descendants(int id) {
    final result = <int>{id};
    var changed = true;
    while (changed) {
      changed = false;
      for (final item in items) {
        if (result.contains(item['parent_id']) && result.add(item['id'] as int))
          changed = true;
      }
    }
    return result;
  }

  Future<void> finishDrag(int id) async {
    final destination = dragPosition;
    if (destination == null) return;
    final original = dragOrigin;
    if (original == null || (destination - original).distance < 5) {
      setState(() {
        draggingId = null;
        dragOrigin = null;
        dragPosition = null;
      });
      return;
    }
    final previousParent =
        items.firstWhere((e) => e['id'] == id)['parent_id'] as int?;
    final blocked = descendants(id);
    final candidates =
        visiblePositions.entries.where((e) => !blocked.contains(e.key)).toList()
          ..sort(
            (a, b) => (a.value - destination).distanceSquared.compareTo(
              (b.value - destination).distanceSquared,
            ),
          );
    final parent = candidates.isEmpty || candidates.first.key == 0
        ? null
        : candidates.first.key;
    final all = <int, (double, double)>{
      for (final e in visiblePositions.entries.where((e) => e.key != 0))
        e.key: (
          (e.key == id ? destination : e.value).dx,
          (e.key == id ? destination : e.value).dy,
        ),
    };
    setState(() {
      draggingId = null;
      dragOrigin = null;
      dragPosition = null;
    });
    try {
      await widget.store.saveBranchPlacement(widget.memoId, id, parent, all);
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(tr(context, '가지를 옮겼습니다.')),
              action: SnackBarAction(
                label: tr(context, '되돌리기'),
                onPressed: () async {
                  try {
                    await widget.store.saveBranchPlacement(
                      widget.memoId,
                      id,
                      previousParent,
                      {id: (original.dx, original.dy)},
                    );
                    await load();
                  } catch (_) {
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(tr(context, '되돌리지 못했습니다. 다시 시도해 주세요.')),
                        ),
                      );
                  }
                },
              ),
            ),
          );
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, '위치를 저장하지 못했습니다. 다시 시도해 주세요.'))),
        );
      await load();
    }
  }

  late final fitAnimation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  Animation<Matrix4>? fitTween;
  void fitGraph(Size viewport) {
    final values = visiblePositions.values;
    if (values.isEmpty) return;
    var left = values.map((p) => p.dx).reduce(math.min) - 35;
    var top = values.map((p) => p.dy).reduce(math.min) - 35;
    var right = values.map((p) => p.dx + 174).reduce(math.max) + 35;
    var bottom = values.map((p) => p.dy + 86).reduce(math.max) + 35;
    if (showCharacters) {
      for (final p in _characterPositions(visiblePositions)) {
        left = math.min(left, p.dx - 20);
        top = math.min(top, p.dy - 20);
        right = math.max(right, p.dx + 92);
        bottom = math.max(bottom, p.dy + 143);
      }
    }
    final scale =
        math
            .min(
              viewport.width / (right - left),
              viewport.height / (bottom - top),
            )
            .clamp(.054, 1.0) *
        .94;
    final target = Matrix4.identity()
      ..translateByDouble(
        viewport.width / 2 - (left + right) / 2 * scale,
        viewport.height / 2 - (top + bottom) / 2 * scale,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, scale, 1);
    fitAnimation.stop();
    if (MediaQuery.disableAnimationsOf(context)) {
      transformation.value = target;
      return;
    }
    fitTween = Matrix4Tween(begin: transformation.value.clone(), end: target)
        .animate(
          CurvedAnimation(parent: fitAnimation, curve: Curves.easeOutCubic),
        );
    fitAnimation.forward(from: 0);
  }

  bool loading = true;
  bool showCharacters = true;
  @override
  void initState() {
    super.initState();
    fitAnimation.addListener(() {
      if (fitTween != null) transformation.value = fitTween!.value;
    });
    load();
  }

  @override
  void dispose() {
    fitAnimation.dispose();
    transformation.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final enabled = await widget.store.charactersEnabled();
    var next = await widget.store.branches(widget.memoId);
    if (next.any((row) => row['x'] is! num || row['y'] is! num)) {
      final positions = placePlantNodes(
        next,
        layoutPlant(next, {}),
        rootPosition,
      );
      await widget.store.saveMissingBranchPositions(widget.memoId, {
        for (final row in next)
          if ((row['x'] is! num || row['y'] is! num) &&
              positions.containsKey(row['id']))
            row['id'] as int: (
              positions[row['id']]!.dx,
              positions[row['id']]!.dy,
            ),
      });
      next = await widget.store.branches(widget.memoId);
    }
    if (mounted)
      setState(() {
        items = next;
        showCharacters = enabled;
        loading = false;
      });
  }

  Future<void> edit({int? id, int? parent, Offset? position}) async {
    final existing = id == null
        ? ''
        : items.firstWhere((e) => e['id'] == id)['text'] as String;
    final text = await showDialog<String>(
      context: context,
      builder: (c) => _BranchDialog(initial: existing, isNew: id == null),
    );
    if (text == null || text.isEmpty) return;
    if (id == null) {
      Offset? placement = position;
      if (placement == null &&
          items.any((item) => item['x'] is num && item['y'] is num)) {
        final origin = visiblePositions[parent ?? 0] ?? rootPosition;
        const offsets = [
          Offset(0, -145),
          Offset(205, 0),
          Offset(-205, 0),
          Offset(0, 145),
          Offset(205, -145),
          Offset(-205, -145),
          Offset(205, 145),
          Offset(-205, 145),
        ];
        for (var ring = 1; ring <= 8 && placement == null; ring++) {
          for (final offset in offsets) {
            final candidate = origin + offset * ring.toDouble();
            if (candidate.dx < 0 ||
                candidate.dx > 5826 ||
                candidate.dy < 0 ||
                candidate.dy > 5914)
              continue;
            if (visiblePositions.values.every(
              (other) =>
                  (other.dx - candidate.dx).abs() >= 174 ||
                  (other.dy - candidate.dy).abs() >= 100,
            )) {
              placement = candidate;
              break;
            }
          }
        }
      }
      await widget.store.addBranch(
        widget.memoId,
        text,
        parentId: parent,
        x: placement?.dx,
        y: placement?.dy,
      );
    } else {
      await widget.store.renameBranch(widget.memoId, id, text);
    }
    if (parent != null) collapsed.remove(parent);
    await load();
  }

  Future<void> addAt(Offset scenePosition) async {
    final scene = scenePosition - const Offset(87, 43);
    final position = Offset(scene.dx.clamp(0, 5826), scene.dy.clamp(0, 5914));
    final nearest = visiblePositions.entries.toList()
      ..sort(
        (a, b) => (a.value - position).distanceSquared.compareTo(
          (b.value - position).distanceSquared,
        ),
      );
    final parent = nearest.isEmpty || nearest.first.key == 0
        ? null
        : nearest.first.key;
    await edit(parent: parent, position: position);
  }

  Future<void> move(int id) async {
    final target = await showDialog<int>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text(tr(context, '어느 가지에 연결할까요?')),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(c, 0),
            child: Text(tr(context, '이 메모의 첫 번째 가지')),
          ),
          for (final item in items.where((e) => e['id'] != id))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, item['id'] as int),
              child: Text(
                '${tr(context, '아래')} ${item['text']}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
    if (target == null) return;
    try {
      await widget.store.moveBranch(
        widget.memoId,
        id,
        target == 0 ? null : target,
      );
      await load();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, '자기 자신이나 하위 가지로는 옮길 수 없습니다.'))),
        );
    }
  }

  Future<void> remove(int id) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr(context, '가지 삭제')),
        content: Text(tr(context, '이 가지와 그 아래의 가지가 함께 삭제됩니다.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(tr(context, '취소')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(tr(context, '삭제')),
          ),
        ],
      ),
    );
    if (yes == true) {
      await widget.store.deleteBranch(widget.memoId, id);
      await load();
    }
  }

  Future<void> chooseShape(Map<String, Object?> item) async {
    final options = <(String, String)>[
      ('rounded', '둥근 사각형'),
      ('pill', '알약'),
      ('circle', '원'),
      ('diamond', '마름모'),
    ];
    final chosen = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr(c, '노드 모양')),
        content: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final option in options)
                  Tooltip(
                    message: tr(c, option.$2),
                    child: InkWell(
                      onTap: () => Navigator.pop(c, option.$1),
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 90,
                        child: Center(
                          child: Material(
                            shape: branchShape(
                              option.$1,
                              BorderSide(
                                color: Theme.of(c).colorScheme.primary,
                              ),
                            ),
                            color: Theme.of(c).colorScheme.primaryContainer,
                            child: SizedBox(
                              width: 70,
                              height: 48,
                              child: Center(
                                child:
                                    item['shape'] == option.$1 ||
                                        (item['shape'] == null &&
                                            option.$1 == 'rounded')
                                    ? const Icon(Icons.check, size: 18)
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(tr(c, '취소')),
          ),
        ],
      ),
    );
    if (chosen == null) return;
    try {
      await widget.store.setBranchShape(
        widget.memoId,
        item['id'] as int,
        chosen,
      );
      await load();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, '모양을 저장하지 못했습니다. 다시 시도해 주세요.'))),
        );
    }
  }

  Future<void> showBranch(Map<String, Object?> item) async {
    final id = item['id'] as int;
    final hasChildren = items.any((e) => e['parent_id'] == id);
    final action = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black38,
      transitionDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 220),
      transitionBuilder: (context, animation, _, child) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: .88, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      ),
      pageBuilder: (sheetContext, _, _) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        backgroundColor: Theme.of(
          sheetContext,
        ).colorScheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: SizedBox(
          width: 520,
          height: (MediaQuery.sizeOf(sheetContext).height * .6).clamp(
            220.0,
            520.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PopupMenuButton<String>(
                    tooltip: tr(sheetContext, '가지 메뉴'),
                    icon: Icon(
                      Icons.more_horiz,
                      color: Theme.of(
                        sheetContext,
                      ).colorScheme.onSurfaceVariant,
                    ),
                    onSelected: (value) => Navigator.pop(sheetContext, value),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'shape',
                        child: Text(tr(sheetContext, '노드 모양')),
                      ),
                      PopupMenuItem(
                        value: 'move',
                        child: Text(tr(sheetContext, '연결 변경')),
                      ),
                      if (hasChildren)
                        PopupMenuItem(
                          value: 'collapse',
                          child: Text(
                            tr(
                              sheetContext,
                              collapsed.contains(id) ? '펼치기' : '접기',
                            ),
                          ),
                        ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(tr(sheetContext, '삭제')),
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: tr(sheetContext, '닫기'),
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              Expanded(
                child: InkWell(
                  onTap: () => Navigator.pop(sheetContext, 'edit'),
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item['text'] as String,
                            textAlign: TextAlign.center,
                            style: Theme.of(
                              sheetContext,
                            ).textTheme.headlineSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'edit':
        await edit(id: id);
      case 'move':
        await move(id);
      case 'shape':
        await chooseShape(item);
      case 'delete':
        await remove(id);
      case 'collapse':
        setState(() {
          if (!collapsed.add(id)) collapsed.remove(id);
        });
    }
  }

  Widget node(Map<String, Object?> item, {required double controlOpacity}) {
    final id = item['id'] as int;
    return NotebookPress(
      child: GestureDetector(
        onTap: () => showBranch(item),
        onLongPressStart: (_) => setState(() {
          draggingId = id;
          dragOrigin = visiblePositions[id];
          dragPosition = dragOrigin;
        }),
        onLongPressMoveUpdate: (details) => setState(() {
          if (dragOrigin != null) {
            final p =
                dragOrigin! +
                details.offsetFromOrigin /
                    transformation.value.storage[0].abs();
            dragPosition = Offset(p.dx.clamp(0, 5826), p.dy.clamp(0, 5914));
          }
        }),
        onLongPressEnd: (_) => finishDrag(id),
        child: AnimatedScale(
          scale: draggingId == id ? 1.06 : 1,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 140),
          child: Material(
            elevation: draggingId == id ? 5 : 0,
            color: Theme.of(context).colorScheme.surfaceContainerLowest
                .withValues(alpha: .85 * controlOpacity),
            shape: branchShape(
              item['shape'] as String? ?? 'rounded',
              BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: controlOpacity),
              ),
            ),
            child: SizedBox(
              width: 174,
              height: 86,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: SizedBox(
                    width:
                        (item['shape'] == 'circle' ||
                            item['shape'] == 'diamond')
                        ? 75
                        : 150,
                    child: Text(
                      item['text'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return Center(child: CircularProgressIndicator());
    final layout = layoutPlant(items, collapsed);
    final positions = placePlantNodes(items, layout, rootPosition);
    if (draggingId != null && dragPosition != null)
      positions[draggingId!] = dragPosition!;
    visiblePositions = positions;
    const canvasWidth = 6000.0;
    const canvasHeight = 6000.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              graphViewport = constraints.biggest;
              final displayPositions = positions;
              if (!fittedInitially) {
                fittedInitially = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) fitGraph(constraints.biggest);
                });
              }
              return Stack(
                children: [
                  Positioned.fill(
                    child: InteractiveViewer(
                      transformationController: transformation,
                      onInteractionStart: (_) => fitAnimation.stop(),
                      trackpadScrollCausesScale: true,
                      constrained: false,
                      minScale: .05,
                      maxScale: 2.5,
                      boundaryMargin: EdgeInsets.all(double.infinity),
                      child: SizedBox(
                        width: canvasWidth < constraints.maxWidth
                            ? constraints.maxWidth
                            : canvasWidth,
                        height: canvasHeight < constraints.maxHeight
                            ? constraints.maxHeight
                            : canvasHeight,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: AnimatedBuilder(
                                animation: transformation,
                                builder: (context, _) => CustomPaint(
                                  painter: TreeLines(
                                    items,
                                    displayPositions,
                                    Theme.of(context).colorScheme.outline,
                                    zoomScale: transformation.value.storage[0]
                                        .abs(),
                                  ),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onDoubleTapDown: (details) =>
                                    doubleTapPosition = details.localPosition,
                                onDoubleTap: () {
                                  final position = doubleTapPosition;
                                  if (position != null) addAt(position);
                                },
                              ),
                            ),
                            if (showCharacters && draggingId == null)
                              for (final entry in _characterPositions(
                                displayPositions,
                              ).indexed)
                                Positioned(
                                  left: entry.$2.dx,
                                  top: entry.$2.dy,
                                  child: GardenPerson(
                                    key: ValueKey('garden-person-${entry.$1}'),
                                    index: entry.$1,
                                  ),
                                ),
                            if (displayPositions.containsKey(0))
                              Positioned(
                                left: displayPositions[0]!.dx,
                                top: displayPositions[0]!.dy,
                                child: DragTarget<int>(
                                  onAcceptWithDetails: (details) async {
                                    await widget.store.moveBranch(
                                      widget.memoId,
                                      details.data,
                                      null,
                                    );
                                    await load();
                                  },
                                  builder: (context, candidates, rejected) =>
                                      Material(
                                        color: candidates.isNotEmpty
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primaryContainer
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(14),
                                        child: SizedBox(
                                          width: 174,
                                          height: 86,
                                          child: Center(
                                            child: Text(tr(context, '이 메모')),
                                          ),
                                        ),
                                      ),
                                ),
                              ),
                            for (final item in items)
                              if (displayPositions.containsKey(item['id']))
                                Positioned(
                                  key: ValueKey('branch-${item['id']}'),
                                  left: displayPositions[item['id']]!.dx,
                                  top: displayPositions[item['id']]!.dy,
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(begin: .9, end: 1),
                                    duration:
                                        MediaQuery.disableAnimationsOf(context)
                                        ? Duration.zero
                                        : const Duration(milliseconds: 240),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, scale, child) => Opacity(
                                      opacity: ((scale - .9) * 10).clamp(0, 1),
                                      child: Transform.scale(
                                        scale: scale,
                                        child: child,
                                      ),
                                    ),
                                    child: AnimatedBuilder(
                                      animation: transformation,
                                      builder: (context, _) => node(
                                        item,
                                        controlOpacity:
                                            ((transformation.value.storage[0]
                                                            .abs() -
                                                        .55) /
                                                    .25)
                                                .clamp(0.0, 1.0),
                                      ),
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (items.isEmpty)
                    Positioned(
                      top: 20,
                      left: 16,
                      right: 16,
                      child: IgnorePointer(
                        child: Text(
                          tr(context, '빈 곳을 두 번 눌러 노드를 추가하세요'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        if (items.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: NotebookPress(
                child: Tooltip(
                  message: tr(context, '전체 보기'),
                  child: TextButton.icon(
                    onPressed: () => fitGraph(graphViewport),
                    icon: const Icon(Icons.fit_screen),
                    label: Text(tr(context, '전체 보기')),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<Offset> _characterPositions(Map<int, Offset> positions) {
    if (items.isEmpty) return [];
    final count = (1 + (items.length - 1) ~/ 3).clamp(1, 5);
    final occupied = positions.values
        .map((p) => Rect.fromLTWH(p.dx - 8, p.dy - 8, 190, 102))
        .toList();
    final result = <Offset>[];
    for (final item in items) {
      final origin = positions[item['id']];
      if (origin == null) continue;
      for (final offset in const [
        Offset(185, -110),
        Offset(-82, -110),
        Offset(185, 92),
        Offset(-82, 92),
      ]) {
        final p = origin + offset;
        final rect = Rect.fromLTWH(p.dx, p.dy, 72, 123);
        if (p.dx < 0 || p.dy < 0 || p.dx + 72 > 6000 || p.dy + 123 > 6000)
          continue;
        if (occupied.any((other) => other.overlaps(rect))) continue;
        occupied.add(rect.inflate(8));
        result.add(p);
        break;
      }
      if (result.length == count) break;
    }
    return result;
  }
}

ShapeBorder branchShape(String value, BorderSide side) => switch (value) {
  'pill' => _SketchBorder(side, 'pill'),
  'circle' => _SketchBorder(side, 'circle'),
  'diamond' => _DiamondBorder(side),
  _ => _SketchBorder(side, 'rounded'),
};

class _SketchBorder extends ShapeBorder {
  const _SketchBorder(this.side, this.kind);
  final BorderSide side;
  final String kind;
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    if (kind == 'circle')
      rect = Rect.fromCircle(
        center: rect.center,
        radius: rect.shortestSide / 2,
      );
    final r = kind == 'rounded'
        ? math.min(rect.shortestSide * .17, 14.0)
        : rect.shortestSide / 2;
    final l = rect.left, t = rect.top, right = rect.right, b = rect.bottom;
    final wobble = math.min(1.4, rect.shortestSide * .02);
    return Path()
      ..moveTo(l + r, t + wobble)
      ..cubicTo(
        l + rect.width * .36,
        t - wobble,
        l + rect.width * .68,
        t + wobble * 2,
        right - r,
        t + wobble,
      )
      ..quadraticBezierTo(right - wobble, t + wobble, right - wobble, t + r)
      ..cubicTo(
        right + wobble,
        t + rect.height * .35,
        right - wobble * 2,
        t + rect.height * .7,
        right - wobble,
        b - r,
      )
      ..quadraticBezierTo(right - wobble, b - wobble, right - r, b - wobble)
      ..cubicTo(
        l + rect.width * .66,
        b + wobble,
        l + rect.width * .32,
        b - wobble * 2,
        l + r,
        b - wobble,
      )
      ..quadraticBezierTo(l + wobble, b - wobble, l + wobble, b - r)
      ..cubicTo(
        l - wobble,
        t + rect.height * .68,
        l + wobble * 2,
        t + rect.height * .33,
        l + wobble,
        t + r,
      )
      ..quadraticBezierTo(l + wobble, t + wobble, l + r, t + wobble)
      ..close();
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect.deflate(side.width), textDirection: textDirection);
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style != BorderStyle.none)
      canvas.drawPath(
        getOuterPath(rect, textDirection: textDirection),
        side.toPaint(),
      );
  }

  @override
  ShapeBorder scale(double t) => _SketchBorder(side.scale(t), kind);
}

class _DiamondBorder extends ShapeBorder {
  const _DiamondBorder(this.side);
  final BorderSide side;
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => Path()
    ..moveTo(rect.center.dx, rect.top)
    ..lineTo(rect.right, rect.center.dy)
    ..lineTo(rect.center.dx, rect.bottom)
    ..lineTo(rect.left, rect.center.dy)
    ..close();
  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect.deflate(side.width), textDirection: textDirection);
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style != BorderStyle.none)
      canvas.drawPath(
        getOuterPath(rect, textDirection: textDirection),
        side.toPaint(),
      );
  }

  @override
  ShapeBorder scale(double t) => _DiamondBorder(side.scale(t));
}

class _BranchDialog extends StatefulWidget {
  const _BranchDialog({required this.initial, required this.isNew});
  final String initial;
  final bool isNew;
  @override
  State<_BranchDialog> createState() => _BranchDialogState();
}

class _BranchDialogState extends State<_BranchDialog> {
  late final controller = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    child: SizedBox(
      width: 520,
      height:
          (MediaQuery.sizeOf(context).height -
                  MediaQuery.viewInsetsOf(context).bottom -
                  24)
              .clamp(0.0, 560.0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.isNew ? tr(context, '가지 추가') : tr(context, '가지 수정'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                expands: true,
                maxLines: null,
                maxLength: 200,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: tr(context, '생각을 적어 보세요'),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(tr(context, '취소')),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, controller.text.trim()),
                  child: Text(tr(context, '저장')),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
