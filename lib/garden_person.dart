import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'app_strings.dart';
import 'garden_routes.dart';

enum _Motion {
  idle,
  walking,
  approaching,
  sitting,
  yawning,
  sleeping,
  waking,
  carried,
  landing,
  falling,
}

class GardenPerson extends StatefulWidget {
  const GardenPerson({
    super.key,
    required this.index,
    required this.route,
    this.sceneBounds,
    this.restSpots = const [],
    this.dragFoot,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.onRouteRequested,
    this.random,
    this.hitSize = 0,
  });
  final int index;
  final GardenRoute route;
  final Rect? sceneBounds;
  final List<Offset> restSpots;
  final Offset? dragFoot;
  final VoidCallback? onDragStart;
  final ValueChanged<Offset>? onDragUpdate;
  final ValueChanged<Offset>? onDragEnd;
  final ValueChanged<Offset>? onRouteRequested;
  @visibleForTesting
  final math.Random? random;
  final double hitSize;
  @override
  State<GardenPerson> createState() => _GardenPersonState();
}

class _GardenPersonState extends State<GardenPerson>
    with TickerProviderStateMixin {
  late final math.Random random = widget.random ?? math.Random();
  late final walk = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  );
  late final surprise = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  Timer? nextAction, frameTimer, actionEnd, reducedReaction;
  _Motion motion = _Motion.idle;
  double progress = 0, from = 0, target = 0;
  Offset? heldFoot, seat, approachFrom;
  Offset? lastGlobal;
  bool reduced = false,
      startled = false,
      approachingSleep = false,
      returningFromSeat = false,
      firstWalk = true;
  int poseFrame = 0;

  Offset pointAt(GardenRoute route, double value) {
    final points = route.points;
    final position = value.clamp(0.0, 1.0) * (points.length - 1);
    final index = position.floor().clamp(0, points.length - 1);
    return index == points.length - 1
        ? points.last
        : Offset.lerp(points[index], points[index + 1], position - index)!;
  }

  Offset get currentFoot {
    if (motion == _Motion.carried && widget.dragFoot != null)
      return widget.dragFoot!;
    if (motion == _Motion.approaching && approachFrom != null && seat != null)
      return Offset.lerp(approachFrom!, seat!, walk.value)!;
    if ({
          _Motion.sitting,
          _Motion.yawning,
          _Motion.sleeping,
          _Motion.waking,
        }.contains(motion) &&
        seat != null)
      return seat!;
    if ({_Motion.carried, _Motion.landing, _Motion.falling}.contains(motion) &&
        heldFoot != null)
      return heldFoot!;
    final p = walk.isAnimating && motion == _Motion.walking
        ? from + (target - from) * walk.value
        : progress;
    return pointAt(widget.route, p);
  }

  @override
  void initState() {
    super.initState();
    walk.addStatusListener((status) {
      if (status != AnimationStatus.completed || !mounted) return;
      if (motion == _Motion.approaching) {
        if (returningFromSeat) {
          setState(() {
            returningFromSeat = false;
            seat = null;
            motion = _Motion.idle;
          });
          scheduleNext();
        } else if (approachingSleep) {
          startYawn();
        } else {
          startSit();
        }
      } else if (motion == _Motion.walking) {
        setState(() {
          progress = target;
          motion = _Motion.idle;
        });
        scheduleNext();
      }
    });
    surprise.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted)
        setState(() => startled = false);
    });
    scheduleNext(const Duration(milliseconds: 1100));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wasReduced = reduced;
    reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced && !wasReduced) {
      nextAction?.cancel();
      frameTimer?.cancel();
      actionEnd?.cancel();
      walk.stop();
      motion = _Motion.idle;
    }
    if (!reduced && wasReduced) scheduleNext();
  }

  @override
  void didUpdateWidget(covariant GardenPerson oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.route.branchId != widget.route.branchId ||
        oldWidget.route.bounds != widget.route.bounds) {
      if ((motion == _Motion.landing ||
              motion == _Motion.falling ||
              motion == _Motion.carried) &&
          widget.route.branchId == -1) {
        heldFoot = widget.route.points.first;
      }
      final oldPosition = pointAt(oldWidget.route, progress);
      var nearest = 0;
      for (var i = 1; i < widget.route.points.length; i++) {
        if ((widget.route.points[i] - oldPosition).distanceSquared <
            (widget.route.points[nearest] - oldPosition).distanceSquared)
          nearest = i;
      }
      progress = widget.route.points.length < 2
          ? 0
          : nearest / (widget.route.points.length - 1);
    }
  }

  void stopAction() {
    nextAction?.cancel();
    frameTimer?.cancel();
    actionEnd?.cancel();
  }

  void scheduleNext([Duration? delay]) {
    nextAction?.cancel();
    if (reduced) return;
    nextAction = Timer(
      delay ?? Duration(milliseconds: 700 + random.nextInt(2600)),
      chooseAction,
    );
  }

  void chooseAction() {
    if (!mounted || reduced || motion != _Motion.idle) return;
    final roll = firstWalk ? .4 : random.nextDouble();
    firstWalk = false;
    if (widget.restSpots.isNotEmpty && roll < .38) {
      final foot = currentFoot;
      final choices = [...widget.restSpots]
        ..sort(
          (a, b) =>
              (a - foot).distanceSquared.compareTo((b - foot).distanceSquared),
        );
      if ((choices.first - foot).distance < 180) {
        approachingSleep = roll < .14;
        approachFrom = foot;
        seat = choices.first;
        setState(() => motion = _Motion.approaching);
        walk.duration = Duration(
          milliseconds: ((seat! - foot).distance * 28).round().clamp(500, 2000),
        );
        walk.forward(from: 0);
        return;
      }
    }
    if (roll > .84) {
      scheduleNext();
      return;
    }
    if (widget.route.points.length < 2) {
      widget.onRouteRequested?.call(currentFoot);
      scheduleNext();
      return;
    }
    if (roll > .55) widget.onRouteRequested?.call(currentFoot);
    from = progress;
    target = random.nextDouble();
    if ((target - from).abs() < .25) target = from > .5 ? 0 : 1;
    walk.duration = Duration(
      milliseconds: (1400 + 2200 * (target - from).abs()).round(),
    );
    setState(() => motion = _Motion.walking);
    walk.forward(from: 0);
  }

  void animateFrames(
    _Motion state, {
    required Duration duration,
    required VoidCallback done,
  }) {
    frameTimer?.cancel();
    actionEnd?.cancel();
    setState(() {
      motion = state;
      poseFrame = 0;
    });
    frameTimer = Timer.periodic(const Duration(milliseconds: 125), (_) {
      if (mounted) setState(() => poseFrame = (poseFrame + 1) % 8);
    });
    actionEnd = Timer(duration, () {
      frameTimer?.cancel();
      if (mounted) done();
    });
  }

  void startSit() => animateFrames(
    _Motion.sitting,
    duration: Duration(milliseconds: 4000 + random.nextInt(2500)),
    done: leaveSeat,
  );
  void startYawn() => animateFrames(
    _Motion.yawning,
    duration: const Duration(milliseconds: 1000),
    done: startSleep,
  );
  void startSleep() => animateFrames(
    _Motion.sleeping,
    duration: Duration(milliseconds: 5500 + random.nextInt(3500)),
    done: () => animateFrames(
      _Motion.waking,
      duration: const Duration(milliseconds: 1000),
      done: leaveSeat,
    ),
  );
  void leaveSeat() {
    final position = seat ?? currentFoot;
    approachFrom = position;
    seat = pointAt(widget.route, progress);
    returningFromSeat = true;
    setState(() => motion = _Motion.approaching);
    walk.duration = Duration(
      milliseconds: ((seat! - position).distance * 28).round().clamp(500, 2000),
    );
    walk.forward(from: 0);
  }

  void react() {
    if (motion == _Motion.carried) return;
    reducedReaction?.cancel();
    setState(() => startled = true);
    if (reduced) {
      reducedReaction = Timer(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => startled = false);
      });
    } else {
      surprise.forward(from: 0);
    }
  }

  void beginDrag(LongPressStartDetails details) {
    if (widget.onDragStart == null) return;
    final position = currentFoot;
    stopAction();
    walk.stop();
    surprise.stop();
    heldFoot = position;
    lastGlobal = details.globalPosition;
    setState(() {
      motion = _Motion.carried;
      startled = false;
      poseFrame = 0;
    });
    if (!reduced)
      frameTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (mounted) setState(() => poseFrame = (poseFrame + 1) % 8);
      });
    widget.onDragStart?.call();
    widget.onDragUpdate?.call(details.globalPosition);
  }

  void updateDrag(LongPressMoveUpdateDetails details) {
    lastGlobal = details.globalPosition;
    widget.onDragUpdate?.call(details.globalPosition);
  }

  void endDrag(Offset global) {
    frameTimer?.cancel();
    heldFoot = widget.dragFoot ?? heldFoot;
    widget.onDragEnd?.call(global);
    final falls = random.nextDouble() < .35;
    if (reduced) {
      setState(() => motion = _Motion.idle);
      scheduleNext();
      return;
    }
    animateFrames(
      falls ? _Motion.falling : _Motion.landing,
      duration: const Duration(milliseconds: 1000),
      done: () {
        final foot = heldFoot ?? pointAt(widget.route, progress);
        widget.onRouteRequested?.call(foot);
        setState(() {
          motion = _Motion.idle;
          heldFoot = null;
        });
        scheduleNext();
      },
    );
  }

  @override
  void dispose() {
    stopAction();
    reducedReaction?.cancel();
    walk.dispose();
    surprise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([walk, surprise]),
    builder: (context, _) {
      final moving =
          walk.isAnimating &&
          {_Motion.walking, _Motion.approaching}.contains(motion) &&
          !reduced;
      final foot = currentFoot;
      final hop = startled && !reduced
          ? -8 * math.sin(math.pi * surprise.value)
          : 0.0;
      final frame = moving ? (walk.value * 24).floor() % 8 : 2;
      final rect = widget.sceneBounds ?? widget.route.bounds;
      final hitWidth = math.max(gardenSpriteWidth, widget.hitSize);
      final hitHeight = math.max(gardenSpriteHeight, widget.hitSize);
      return SizedBox(
        width: rect.width,
        height: rect.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: foot.dx - rect.left - hitWidth / 2,
              top:
                  foot.dy -
                  rect.top -
                  gardenSpriteHeight * .8 +
                  hop -
                  (hitHeight - gardenSpriteHeight) / 2,
              child: Semantics(
                button: true,
                label: tr(context, '소인 캐릭터'),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: react,
                  onLongPressStart: widget.onDragStart == null
                      ? null
                      : beginDrag,
                  onLongPressMoveUpdate: widget.onDragUpdate == null
                      ? null
                      : updateDrag,
                  onLongPressEnd: widget.onDragEnd == null
                      ? null
                      : (d) => endDrag(d.globalPosition),
                  onLongPressCancel: widget.onDragEnd == null
                      ? null
                      : () {
                          if (motion == _Motion.carried && lastGlobal != null)
                            endDrag(lastGlobal!);
                        },
                  child: SizedBox(
                    width: hitWidth,
                    height: hitHeight,
                    child: Center(
                      child: SizedBox(
                        key: ValueKey(
                          startled
                              ? 'garden-pose-surprised'
                              : motion == _Motion.idle || moving
                              ? 'garden-step-$frame'
                              : 'garden-${motion.name}-$poseFrame',
                        ),
                        width: gardenSpriteWidth,
                        height: gardenSpriteHeight,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: startled
                                  ? surprisedSprite()
                                  : activitySprite(frame),
                            ),
                            if (motion == _Motion.sleeping && !startled)
                              Positioned(
                                left: gardenSpriteWidth * .46,
                                top:
                                    gardenSpriteHeight -
                                    gardenSpriteWidth +
                                    gardenSpriteWidth * .52,
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    key: const ValueKey('garden-sleep-zzz'),
                                    size: const Size(15, 16),
                                    painter: _SleepMarks(poseFrame),
                                  ),
                                ),
                              ),
                            if ((motion == _Motion.landing ||
                                    motion == _Motion.falling) &&
                                poseFrame < 4)
                              Positioned(
                                left: -4,
                                right: -4,
                                bottom: 5,
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    size: const Size(30, 8),
                                    painter: _LandingDust(poseFrame),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget activitySprite(int walkingFrame) {
    if (motion == _Motion.idle ||
        motion == _Motion.walking ||
        motion == _Motion.approaching)
      return walkSprite(walkingFrame);
    final row = switch (motion) {
      _Motion.sitting => 0,
      _Motion.yawning || _Motion.sleeping || _Motion.waking => 1,
      _Motion.carried => 2,
      _ => 3,
    };
    final frame = switch (motion) {
      _Motion.sleeping => 7,
      _Motion.waking => 7 - poseFrame,
      _Motion.landing => poseFrame < 4 ? 0 : 1,
      _Motion.falling => poseFrame,
      _ => poseFrame,
    };
    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox.square(
        dimension: gardenSpriteWidth,
        child: sheetSprite(
          'assets/characters/actions-${widget.index}.png',
          8,
          4,
          frame,
          row,
          square: true,
        ),
      ),
    );
  }

  Widget walkSprite(int frame) =>
      sheetSprite('assets/characters/walk-${widget.index}.png', 8, 1, frame, 0);
  Widget surprisedSprite() => Align(
    alignment: Alignment.bottomCenter,
    child: SizedBox.square(
      dimension: gardenSpriteWidth,
      child: sheetSprite(
        'assets/characters/garden_motion.png',
        5,
        3,
        widget.index,
        2,
        square: true,
      ),
    ),
  );

  Widget sheetSprite(
    String path,
    int columns,
    int rows,
    int column,
    int row, {
    bool square = false,
  }) {
    final h = square ? gardenSpriteWidth : gardenSpriteHeight;
    return ClipRect(
      child: OverflowBox(
        minWidth: gardenSpriteWidth * columns,
        maxWidth: gardenSpriteWidth * columns,
        minHeight: h * rows,
        maxHeight: h * rows,
        child: Transform.translate(
          offset: Offset(
            ((columns - 1) / 2 - column) * gardenSpriteWidth,
            ((rows - 1) / 2 - row) * h,
          ),
          child: Image.asset(
            path,
            width: gardenSpriteWidth * columns,
            height: h * rows,
            fit: BoxFit.fill,
            excludeFromSemantics: true,
          ),
        ),
      ),
    );
  }
}

class _SleepMarks extends CustomPainter {
  _SleepMarks(this.frame);
  final int frame;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xff777d64).withValues(alpha: .8)
      ..strokeWidth = .8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 3; i++) {
      final drift = (frame / 8) * 2;
      final x = 1.0 + i * 4;
      final y = 12.0 - i * 4 - drift;
      final width = 2.0 + i * .45;
      final path = Path()
        ..moveTo(x, y)
        ..lineTo(x + width, y - .2)
        ..lineTo(x, y + width)
        ..lineTo(x + width, y + width - .1);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SleepMarks old) => old.frame != frame;
}

class _LandingDust extends CustomPainter {
  _LandingDust(this.frame);
  final int frame;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xffa8a38a).withValues(alpha: (4 - frame) / 8);
    canvas.drawCircle(
      Offset(size.width * .2 - frame, size.height / 2),
      1.5 + frame * .5,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * .8 + frame, size.height / 2),
      1.3 + frame * .45,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _LandingDust old) => old.frame != frame;
}
