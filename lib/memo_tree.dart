import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'store.dart';
import 'app_strings.dart';
import 'plant_layout.dart';
import 'plant_lines.dart';
import 'notebook_motion.dart';
import 'garden_person.dart';
import 'garden_routes.dart';
import 'handwriting_pad.dart';

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
  final graphKey = GlobalKey();
  final random = math.Random();
  final personRoutes = <int, GardenRoute>{};
  final personDrag = <int, ValueNotifier<Offset?>>{};
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
      for (final route in _characterPositions(visiblePositions)) {
        left = math.min(left, route.bounds.left - 20);
        top = math.min(top, route.bounds.top - 20);
        right = math.max(right, route.bounds.right + 20);
        bottom = math.max(bottom, route.bounds.bottom + 20);
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
    for (final notifier in personDrag.values) {
      notifier.dispose();
    }
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
        // Routes attached to changed branches are recomputed; explicit drops
        // remain where the user placed them for this editor session.
        personRoutes.removeWhere((_, route) => route.branchId >= 0);
        showCharacters = enabled;
        loading = false;
      });
  }

  Offset? _scenePoint(Offset global) {
    final box = graphKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final point = transformation.toScene(box.globalToLocal(global));
    return Offset(point.dx.clamp(0, 6000), point.dy.clamp(0, 6000));
  }

  Offset _safePersonDrop(Offset position, Map<int, Offset> positions) {
    var foot = position;
    // When dropped on text, land at the top of that node rather than hiding
    // behind the text. The drop changes only the character, never the graph.
    for (final p in positions.values) {
      final textArea = Rect.fromLTWH(p.dx + 12, p.dy + 14, 150, 58);
      final sprite = Rect.fromLTWH(
        foot.dx - gardenSpriteWidth / 2,
        foot.dy - gardenSpriteHeight * .8,
        gardenSpriteWidth,
        gardenSpriteHeight,
      );
      if (sprite.overlaps(textArea)) {
        foot = Offset(foot.dx.clamp(p.dx + 12, p.dx + 162), p.dy);
      }
    }
    return foot;
  }

  void _requestPersonRoute(
    int index,
    Offset foot,
    Map<int, Offset> positions,
    GardenRoute current,
  ) {
    final candidates = gardenRoutes(
      items,
      positions,
      limit: 1000,
      allowOverlaps: true,
    );
    final neighbors = <GardenRoute>[];
    for (final candidate in candidates) {
      if (candidate.points.isEmpty ||
          (candidate.branchId == current.branchId &&
              candidate.bounds == current.bounds))
        continue;
      final first = (candidate.points.first - foot).distance;
      final last = (candidate.points.last - foot).distance;
      if (math.min(first, last) > 6) continue;
      final points = first <= last
          ? candidate.points
          : candidate.points.reversed.toList();
      neighbors.add(
        GardenRoute([foot, ...points], candidate.bounds, candidate.branchId),
      );
    }
    if (neighbors.isEmpty) return;
    setState(
      () => personRoutes[index] = neighbors[random.nextInt(neighbors.length)],
    );
  }

  Widget _person(int index, GardenRoute route, Map<int, Offset> positions) {
    final drag = personDrag.putIfAbsent(
      index,
      () => ValueNotifier<Offset?>(null),
    );
    return ValueListenableBuilder<Offset?>(
      valueListenable: drag,
      builder: (context, foot, _) => AnimatedBuilder(
        animation: transformation,
        builder: (context, _) => GardenPerson(
          key: ValueKey('garden-person-$index'),
          index: index,
          route: route,
          sceneBounds: const Rect.fromLTWH(0, 0, 6000, 6000),
          dragFoot: foot,
          hitSize:
              (44 /
                      math
                          .sqrt(
                            math.pow(transformation.value.storage[0], 2) +
                                math.pow(transformation.value.storage[1], 2),
                          )
                          .clamp(.05, 2.5))
                  .clamp(44, 220)
                  .toDouble(),
          restSpots: gardenRestSpots(positions),
          onDragStart: () {},
          onDragUpdate: (global) {
            final point = _scenePoint(global);
            if (point != null) drag.value = point;
          },
          onDragEnd: (global) {
            final scene = _scenePoint(global) ?? drag.value;
            if (scene == null) {
              drag.value = null;
              return;
            }
            final drop = _safePersonDrop(scene, positions);
            drag.value = drop;
            setState(() => personRoutes[index] = gardenStationaryRoute(drop));
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) drag.value = null;
            });
          },
          onRouteRequested: (foot) =>
              _requestPersonRoute(index, foot, positions, route),
        ),
      ),
    );
  }

  Future<void> edit({int? id, int? parent, Offset? position}) async {
    final existing = id == null
        ? <String, Object?>{}
        : items.firstWhere((e) => e['id'] == id);
    final result = await showDialog<(String, String, String, String?)>(
      context: context,
      builder: (c) => _BranchDialog(
        initial: existing['text'] as String? ?? '',
        initialTitle: existing['title'] as String? ?? '',
        initialRich: existing['rich_text'] as String?,
        initialInk: existing['ink'] as String?,
        isNew: id == null,
      ),
    );
    final text = result?.$2 ?? '';
    if (result == null ||
        (text.isEmpty &&
            result.$1.isEmpty &&
            (result.$4 == null || result.$4 == '[]')))
      return;
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
      final newId = await widget.store.addBranch(
        widget.memoId,
        text,
        parentId: parent,
        x: placement?.dx,
        y: placement?.dy,
      );
      await widget.store.saveBranchContent(
        widget.memoId,
        newId,
        result!.$1,
        text,
        result.$3,
        ink: result.$4,
      );
    } else {
      await widget.store.saveBranchContent(
        widget.memoId,
        id,
        result!.$1,
        text,
        result.$3,
        ink: result.$4,
      );
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
                  key: const ValueKey('branch-preview-edit'),
                  onTap: () => Navigator.pop(sheetContext, 'edit'),
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if ((item['title'] as String? ?? '').isNotEmpty)
                            Text(
                              item['title'] as String,
                              style: Theme.of(
                                sheetContext,
                              ).textTheme.titleLarge,
                            ),
                          _BranchPreview(
                            text: item['text'] as String,
                            rich: item['rich_text'] as String?,
                          ),
                          if (item['ink'] is String)
                            InkPreview(data: item['ink'] as String),
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
                      (item['title'] as String? ?? '').isNotEmpty
                          ? item['title'] as String
                          : item['text'] as String,
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
                      key: graphKey,
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
                                Positioned.fill(
                                  child: _person(
                                    entry.$1,
                                    personRoutes[entry.$1] ?? entry.$2,
                                    displayPositions,
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

  List<GardenRoute> _characterPositions(Map<int, Offset> positions) {
    if (items.isEmpty) return [];
    final count = (1 + (items.length - 1) ~/ 3).clamp(1, 5);
    final routes = gardenRoutes(items, positions, limit: count);
    return [
      for (var i = 0; i < count; i++)
        if (personRoutes[i] != null)
          personRoutes[i]!
        else if (i < routes.length)
          routes[i],
    ];
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

class _BranchPreview extends StatefulWidget {
  const _BranchPreview({required this.text, required this.rich});
  final String text;
  final String? rich;
  @override
  State<_BranchPreview> createState() => _BranchPreviewState();
}

class _BranchPreviewState extends State<_BranchPreview> {
  late final quill.QuillController controller;
  @override
  void initState() {
    super.initState();
    quill.Document doc;
    try {
      doc = widget.rich == null
          ? quill.Document()
          : quill.Document.fromJson(jsonDecode(widget.rich!) as List);
      if (widget.rich == null && widget.text.isNotEmpty)
        doc.insert(0, widget.text);
    } catch (_) {
      doc = quill.Document();
      if (widget.text.isNotEmpty) doc.insert(0, widget.text);
    }
    controller = quill.QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: quill.QuillEditor.basic(
      controller: controller,
      config: const quill.QuillEditorConfig(scrollable: false),
    ),
  );
}

class _BranchDialog extends StatefulWidget {
  const _BranchDialog({
    required this.initial,
    required this.initialTitle,
    required this.initialRich,
    required this.initialInk,
    required this.isNew,
  });
  final String initial, initialTitle;
  final String? initialRich, initialInk;
  final bool isNew;
  @override
  State<_BranchDialog> createState() => _BranchDialogState();
}

class _BranchDialogState extends State<_BranchDialog> {
  late final title = TextEditingController(text: widget.initialTitle);
  late final quill.QuillController controller;
  late final _BranchInkBuffer ink = _BranchInkBuffer(widget.initialInk);
  bool handwriting = false;
  @override
  void initState() {
    super.initState();
    quill.Document document;
    try {
      document = widget.initialRich == null
          ? quill.Document()
          : quill.Document.fromJson(jsonDecode(widget.initialRich!) as List);
      if (widget.initialRich == null && widget.initial.isNotEmpty)
        document.insert(0, widget.initial);
    } catch (_) {
      document = quill.Document();
      if (widget.initial.isNotEmpty) document.insert(0, widget.initial);
    }
    controller = quill.QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  @override
  void dispose() {
    title.dispose();
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.isNew ? tr(context, '가지 추가') : tr(context, '가지 수정'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextField(
              controller: title,
              maxLength: 80,
              decoration: InputDecoration(hintText: tr(context, '노드 제목')),
            ),
            Expanded(
              child: handwriting
                  ? HandwritingPad(
                      store: ink,
                      memoId: 0,
                      onUseText: (text, _) async {
                        final at = controller.document.length - 1;
                        final insertion = '${at > 0 ? '\n' : ''}$text';
                        controller.replaceText(
                          at,
                          0,
                          insertion,
                          TextSelection.collapsed(
                            offset: at + insertion.length,
                          ),
                        );
                        if (mounted) setState(() => handwriting = false);
                      },
                    )
                  : quill.QuillEditor.basic(
                      controller: controller,
                      config: quill.QuillEditorConfig(
                        placeholder: tr(context, '생각을 적어 보세요'),
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
            ),
            Row(
              children: [
                IconButton(
                  tooltip: tr(context, handwriting ? '키보드 입력' : '손글씨'),
                  onPressed: () => setState(() => handwriting = !handwriting),
                  icon: Icon(
                    handwriting ? Icons.keyboard_outlined : Icons.gesture,
                  ),
                ),
                if (!handwriting)
                  Expanded(
                    child: TextFieldTapRegion(
                      child: quill.QuillSimpleToolbar(
                        controller: controller,
                        config: const quill.QuillSimpleToolbarConfig(
                          multiRowsDisplay: false,
                          showInlineCode: false,
                          showCodeBlock: false,
                          showSubscript: false,
                          showSuperscript: false,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(tr(context, '취소')),
                ),
                FilledButton(
                  onPressed: () {
                    final text = controller.document.toPlainText().trim();
                    if (text.isNotEmpty ||
                        title.text.trim().isNotEmpty ||
                        (ink.value != null && ink.value != '[]'))
                      Navigator.pop(context, (
                        title.text.trim(),
                        text,
                        jsonEncode(controller.document.toDelta().toJson()),
                        ink.value,
                      ));
                  },
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

class _BranchInkBuffer extends Store {
  _BranchInkBuffer(this.value);
  String? value;
  @override
  Future<String?> memoInk(int id) async => value;
  @override
  Future<void> saveMemoInk(int id, String ink) async {
    value = ink;
  }
}
