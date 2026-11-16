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
  dropping,
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
    this.landingAt,
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
  final Offset? Function(Offset)? landingAt;
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
  Offset? heldFoot, seat, approachFrom, dropTarget;
  Offset? lastGlobal;
  bool reduced = false,
      startled = false,
      atNode = false,
      returningFromSeat = false,
      firstWalk = true;
  int poseFrame = 0;
  int carriedPhase = 0;
  bool _facingLeft = false;

  Offset pointAt(GardenRoute route, double value) {
    final points = route.points;
    final position = value.clamp(0.0, 1.0) * (points.length - 1);
    final index = position.floor().clamp(0, points.length - 1);
    return index == points.length - 1
        ? points.last
        : Offset.lerp(points[index], points[index + 1], position - index)!;
  }

  Offset get currentFoot {
    if (motion == _Motion.idle && atNode && seat != null) return seat!;
    if (motion == _Motion.carried && widget.dragFoot != null)
      return widget.dragFoot!;
    if (motion == _Motion.dropping && heldFoot != null && dropTarget != null) {
      return Offset.lerp(
        heldFoot!,
        dropTarget!,
        Curves.easeIn.transform(walk.value),
      )!;
    }
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

  // Use the local direction along a curved branch, rather than its endpoints.
  bool get walkingLeft {
    if (!walk.isAnimating) return _facingLeft;
    if (motion == _Motion.approaching && approachFrom != null && seat != null) {
      final dx = seat!.dx - approachFrom!.dx;
      if (dx.abs() > .01) _facingLeft = dx < 0;
      return _facingLeft;
    }
    if (motion != _Motion.walking) return _facingLeft;
    final before = (walk.value - .005).clamp(0.0, 1.0);
    final after = (walk.value + .005).clamp(0.0, 1.0);
    final a = pointAt(widget.route, from + (target - from) * before);
    final b = pointAt(widget.route, from + (target - from) * after);
    // Ignore floating-point noise when the sampled curve is vertical or still.
    final dx = b.dx - a.dx;
    if (dx.abs() > .01) _facingLeft = dx < 0;
    return _facingLeft;
  }

  @override
  void initState() {
    super.initState();
    walk.addStatusListener((status) {
      if (status != AnimationStatus.completed || !mounted) return;
      if (motion == _Motion.dropping) {
        heldFoot = dropTarget;
        finishLanding();
      } else if (motion == _Motion.approaching) {
        if (returningFromSeat) {
          setState(() {
            returningFromSeat = false;
            seat = null;
            motion = _Motion.idle;
          });
          scheduleNext();
        } else {
          waitAtNode();
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
    if (atNode) {
      // A node may have been removed while the character was waiting.
      if (seat == null || !widget.restSpots.contains(seat)) {
        leaveSeat();
        return;
      }
      switch (random.nextInt(3)) {
        case 0:
          leaveSeat();
        case 1:
          startSit();
        case 2:
          startYawn();
      }
      return;
    }
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
        approachFrom = foot;
        seat = choices.first;
        setState(() => motion = _Motion.approaching);
        walk.duration = walkingDuration(
          ((seat! - foot).distance * 28).round().clamp(500, 2000),
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
    walk.duration = walkingDuration(
      (1400 + 2200 * (target - from).abs()).round(),
    );
    setState(() => motion = _Motion.walking);
    walk.forward(from: 0);
  }

  void waitAtNode() {
    setState(() {
      atNode = true;
      motion = _Motion.idle;
    });
    scheduleNext(const Duration(seconds: 5));
  }

  // Finish on the same frame as the standing pose, even for short walks.
  Duration walkingDuration(int milliseconds) => Duration(
    milliseconds: math.max(1, (milliseconds / 1000).round()) * 1000,
  );

  void animateFrames(
    _Motion state, {
    required Duration duration,
    required VoidCallback done,
    Duration frameInterval = const Duration(milliseconds: 125),
  }) {
    frameTimer?.cancel();
    actionEnd?.cancel();
    setState(() {
      motion = state;
      poseFrame = 0;
    });
    frameTimer = Timer.periodic(frameInterval, (_) {
      if (!mounted) return;
      final loops = state == _Motion.sitting || state == _Motion.sleeping;
      setState(
        () => poseFrame = loops
            ? (poseFrame + 1) % 8
            : math.min(poseFrame + 1, 7),
      );
    });
    actionEnd = Timer(duration, () {
      frameTimer?.cancel();
      if (mounted) done();
    });
  }

  void startSit() => animateFrames(
    _Motion.sitting,
    duration: const Duration(milliseconds: 4000),
    frameInterval: const Duration(milliseconds: 250),
    done: waitAtNode,
  );
  void startYawn() => animateFrames(
    _Motion.yawning,
    duration: const Duration(milliseconds: 2000),
    frameInterval: const Duration(milliseconds: 250),
    done: startSleep,
  );
  void startSleep() => animateFrames(
    _Motion.sleeping,
    duration: Duration(seconds: 60 + random.nextInt(121)),
    done: startWake,
  );
  void startWake() => animateFrames(
    _Motion.waking,
    duration: const Duration(milliseconds: 1000),
    done: waitAtNode,
  );
  void leaveSeat() {
    final position = seat ?? currentFoot;
    atNode = false;
    approachFrom = position;
    seat = pointAt(widget.route, progress);
    returningFromSeat = true;
    setState(() => motion = _Motion.approaching);
    walk.duration = walkingDuration(
      ((seat! - position).distance * 28).round().clamp(500, 2000),
    );
    walk.forward(from: 0);
  }

  void react() {
    if (motion == _Motion.carried) return;
    if (motion == _Motion.sleeping) {
      startWake();
      return;
    }
    if (motion == _Motion.waking) return;
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
    atNode = false;
    walk.stop();
    surprise.stop();
    heldFoot = position;
    lastGlobal = details.globalPosition;
    carriedPhase = 0;
    setState(() {
      motion = _Motion.carried;
      startled = false;
      poseFrame = 0;
    });
    if (!reduced)
      frameTimer = Timer.periodic(const Duration(milliseconds: 125), (_) {
        if (mounted) {
          setState(() {
            carriedPhase = (carriedPhase + 1) % 14;
            poseFrame = carriedPhase <= 7 ? carriedPhase : 14 - carriedPhase;
          });
        }
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
    dropTarget = widget.landingAt?.call(global) ?? heldFoot;
    widget.onDragEnd?.call(global);
    if (reduced) {
      setState(() => motion = _Motion.idle);
      scheduleNext();
      return;
    }
    final distance = ((dropTarget?.dy ?? 0) - (heldFoot?.dy ?? 0));
    if (distance > 4) {
      setState(() {
        motion = _Motion.dropping;
      });
      walk.duration = Duration(
        milliseconds: (300 + math.sqrt(distance) * 55).round().clamp(300, 1800),
      );
      walk.forward(from: 0);
      return;
    }
    heldFoot = dropTarget;
    finishLanding();
  }

  void finishLanding() {
    final falls = random.nextDouble() < .35;
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
      final frame = moving
          ? (((walk.lastElapsedDuration?.inMilliseconds ?? 0) ~/ 125) + 2) % 8
          : 2;
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
                  (gardenSpriteHeight * .8 - 1.5) +
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
                        width: gardenSpriteWidth,
                        height: gardenSpriteHeight,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: AnimatedSwitcher(
                                // Showing outgoing and incoming transparent
                                // sprites together doubles hands and faces.
                                duration: Duration.zero,
                                child: KeyedSubtree(
                                  key: ValueKey(
                                    startled
                                        ? 'surprise'
                                        : switch (motion) {
                                            _Motion.idle ||
                                            _Motion.walking ||
                                            _Motion.approaching => 'walk',
                                            _Motion.yawning ||
                                            _Motion.sleeping ||
                                            _Motion.waking => 'sleep',
                                            _Motion.dropping => 'drop',
                                            _ => motion.name,
                                          },
                                  ),
                                  child: Transform.translate(
                                    key: ValueKey(
                                      startled
                                          ? 'garden-pose-surprised'
                                          : motion == _Motion.idle || moving
                                          ? 'garden-step-$frame'
                                          : 'garden-${motion.name}-$poseFrame',
                                    ),
                                    offset: startled
                                        ? _actionOffset(widget.index)
                                        : {
                                            _Motion.idle,
                                            _Motion.walking,
                                            _Motion.approaching,
                                            _Motion.landing,
                                          }.contains(motion)
                                        ? _walkOffset(widget.index)
                                        : motion == _Motion.sitting
                                        ? _sittingOffset(widget.index)
                                        : _actionOffset(widget.index),
                                    child: startled
                                        ? surprisedSprite()
                                        : activitySprite(frame),
                                  ),
                                ),
                              ),
                            ),
                            if (motion == _Motion.sleeping && !startled)
                              Positioned(
                                left: gardenSpriteWidth * .72,
                                top:
                                    gardenSpriteHeight -
                                    gardenSpriteWidth +
                                    gardenSpriteWidth * .02 +
                                    _actionOffset(widget.index).dy,
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    key: const ValueKey('garden-sleep-zzz'),
                                    size: const Size(11, 13),
                                    painter: _SleepMarks(poseFrame),
                                  ),
                                ),
                              ),
                            if ((motion == _Motion.landing ||
                                    motion == _Motion.falling) &&
                                poseFrame < 8)
                              Positioned(
                                left: -4,
                                right: -4,
                                bottom: 10,
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
    if (motion == _Motion.landing) {
      // A normal landing is a small compression of the standing pose. The
      // separate falling sheet includes a seated fall and must not be reused.
      const compression = [1.0, .94, .90, .92, .96, .98, 1.0, 1.0];
      return Transform.scale(
        alignment: Alignment.bottomCenter,
        scaleY: compression[poseFrame],
        child: walkSprite(2),
      );
    }
    if (motion == _Motion.sitting) return sittingSprite(poseFrame);
    final row = switch (motion) {
      _Motion.sitting => 0,
      _Motion.yawning || _Motion.sleeping || _Motion.waking => 1,
      _Motion.carried || _Motion.dropping => 2,
      _ => 3,
    };
    final frame = switch (motion) {
      _Motion.sleeping => 7,
      _Motion.waking => 7 - poseFrame,
      _Motion.falling => poseFrame,
      _ => poseFrame,
    };
    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox.square(
        dimension: gardenSpriteWidth,
        child: sheetSprite(
          row == 1 && (widget.index == 1 || widget.index == 2)
              ? 'assets/characters/actions-sleep-${widget.index}.png'
              : 'assets/characters/actions-${widget.index}.png',
          8,
          4,
          frame,
          row,
          square: true,
        ),
      ),
    );
  }

  Widget sittingSprite(int frame) {
    const ratio = 271.5 / 724;
    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: gardenSpriteWidth * 1.5 * ratio,
        height: gardenSpriteWidth * 1.5,
        child: sheetSprite(
          widget.index == 2
              ? 'assets/characters/sit-clean-2.png'
              : 'assets/characters/sit-${widget.index}.png',
          8,
          1,
          frame,
          0,
          frameWidth: gardenSpriteWidth * 1.5 * ratio,
          frameHeight: gardenSpriteWidth * 1.5,
        ),
      ),
    );
  }

  // Align each source sheet's drawn feet with the walking sheet. The sheets
  // have different transparent margins; keep the artwork's proportions intact.
  Offset _actionOffset(int index) => [
    const Offset(-.3, -8.1),
    const Offset(-1.6, -8.3),
    const Offset(.1, -7.9),
    const Offset(-1.2, -7.1),
    const Offset(-2.1, -7.3),
  ][index.clamp(0, 4)];

  Offset _walkOffset(int index) => [
    const Offset(0, -3.1),
    const Offset(0, -1.1),
    const Offset(0, -1.1),
    const Offset(0, -.9),
    const Offset(0, -1.9),
  ][index.clamp(0, 4)];

  // Sitting frames use the bottom of the torso as the contact point;
  // the feet hang below the branch or node instead of being placed on it.
  Offset _sittingOffset(int index) => [
    const Offset(0, -.5),
    const Offset(0, -.2),
    const Offset(0, -.2),
    const Offset(0, 0),
    const Offset(0, -.4),
  ][index.clamp(0, 4)];

  Widget walkSprite(int frame) => Align(
    alignment: Alignment.bottomCenter,
    child: SizedBox(
      // Each walking frame is 271.5 × 724 pixels. Preserve that aspect ratio
      // instead of stretching the figure horizontally to fill a square.
      width: gardenSpriteWidth * 1.5 * (271.5 / 724),
      height: gardenSpriteWidth * 1.5,
      child: _walkingLayers(frame),
    ),
  );

  Widget _walkingLayers(int frame) {
    const width = gardenSpriteWidth * 1.5 * (271.5 / 724);
    const height = gardenSpriteWidth * 1.5;
    final path = widget.index == 1
        ? 'assets/characters/walk-body-clean-1.png'
        : 'assets/characters/walk-body-${widget.index}.png';
    Widget sprite(int column) => sheetSprite(
      path,
      8,
      1,
      column,
      0,
      frameWidth: width,
      frameHeight: height,
    );
    // Render a single complete frame to avoid detached or doubled limbs.
    final image = sprite(frame);
    final isWalking = walk.isAnimating &&
        (motion == _Motion.walking || motion == _Motion.approaching) && !reduced;
    final swing = isWalking
        ? math.sin((walk.lastElapsedDuration?.inMicroseconds ?? 0) *
            2 * math.pi / 1000000)
        : 0.0;
    final person = Stack(fit: StackFit.expand, children: [
      CustomPaint(painter: _StraightWalkingArm(swing, widget.index, foreground: false)),
      image,
      CustomPaint(painter: _StraightWalkingArm(swing, widget.index, foreground: true)),
    ]);
    if (!walkingLeft) return person;
    return Transform.flip(
      key: ValueKey('garden-facing-left-${widget.index}'),
      flipX: true,
      child: person,
    );
  }

  Widget surprisedSprite() => Align(
    alignment: Alignment.bottomCenter,
    child: SizedBox.square(
      dimension: gardenSpriteWidth,
      child: sheetSprite(
        'assets/characters/actions-${widget.index}.png',
        8,
        4,
        0,
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
    double? frameWidth,
    double? frameHeight,
  }) {
    final w = frameWidth ?? gardenSpriteWidth;
    final h = frameHeight ?? (square ? gardenSpriteWidth : gardenSpriteHeight);
    final frame = ClipRect(
      child: OverflowBox(
        minWidth: w * columns,
        maxWidth: w * columns,
        minHeight: h * rows,
        maxHeight: h * rows,
        child: Transform.translate(
          offset: Offset(
            ((columns - 1) / 2 - column) * w,
            ((rows - 1) / 2 - row) * h,
          ),
          child: Image.asset(
            path,
            width: w * columns,
            height: h * rows,
            fit: BoxFit.fill,
            excludeFromSemantics: true,
          ),
        ),
      ),
    );
    return frame;
  }
}

class _StraightWalkingArm extends CustomPainter {
  _StraightWalkingArm(this.swing, this.index, {required this.foreground});
  final double swing;
  final int index;
  final bool foreground;

  @override
  void paint(Canvas canvas, Size size) {
    // Anchor each character's arms to their own sleeve/shoulder outline.
    // The foreground arm crosses the torso while the rear arm stays behind it.
    const frontX = [.435, .41, .41, .38, .385];
    const rearX = [.625, .63, .62, .65, .605];
    const shoulderY = [.58, .56, .54, .54, .58];
    final shoulder = Offset(
      size.width * (foreground ? frontX[index] : rearX[index]),
      size.height * (shoulderY[index] - (foreground ? 0 : .005)),
    );
    final angle = foreground ? .12 - swing * .55 : .38 + swing * .35;
    final length = size.height * .105;
    final hand = shoulder + Offset(math.sin(angle) * length, math.cos(angle) * length);
    final outline = Paint()
      ..color = const Color(0xff72564a)
      ..strokeWidth = size.width * .035
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(shoulder, hand, outline);
    canvas.drawCircle(hand, size.width * .038, outline);
    canvas.drawCircle(hand, size.width * .024, Paint()..color = const Color(0xffa27f68));
  }

  @override
  bool shouldRepaint(covariant _StraightWalkingArm oldDelegate) =>
      oldDelegate.swing != swing || oldDelegate.index != index ||
      oldDelegate.foreground != foreground;
}

class _SleepMarks extends CustomPainter {
  _SleepMarks(this.frame);
  final int frame;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xff806e58).withValues(alpha: .72)
      ..strokeWidth = .65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 3; i++) {
      final drift = math.sin(frame * math.pi / 4) * .45;
      final x = 1.0 + i * 3.2;
      final y = 9.7 - i * 3.0 - drift;
      final width = 1.6 + i * .35;
      final path = Path()
        ..moveTo(x, y)
        ..quadraticBezierTo(x + width * .5, y - .2, x + width, y - .15)
        ..quadraticBezierTo(x + width * .45, y + width * .5, x, y + width)
        ..quadraticBezierTo(
          x + width * .45,
          y + width - .1,
          x + width,
          y + width - .15,
        );
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
      ..color = const Color(0xff857e69).withValues(alpha: (8 - frame) * .09);
    canvas.drawCircle(
      Offset(size.width * .2 - frame, size.height / 2),
      2.0 + frame * .5,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * .8 + frame, size.height / 2),
      1.8 + frame * .45,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _LandingDust old) => old.frame != frame;
}
