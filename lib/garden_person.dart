import 'dart:async';
import 'package:flutter/material.dart';
import 'app_strings.dart';

/// One cell of the shared transparent character sheet.
class GardenPerson extends StatefulWidget {
  const GardenPerson({super.key, required this.index});
  final int index;
  @override
  State<GardenPerson> createState() => _GardenPersonState();
}

class _GardenPersonState extends State<GardenPerson> {
  bool reacting = false;
  bool hiding = false;
  Timer? timer;

  void react() {
    timer?.cancel();
    setState(() {
      reacting = true;
      hiding = !hiding;
    });
    timer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => reacting = false);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    const width = 72.0;
    const height = 123.0;
    return Semantics(
      button: true,
      label: tr(context, '소인 캐릭터'),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: react,
        child: SizedBox(
          width: width,
          height: height,
          child: AnimatedOpacity(
            opacity: reacting && hiding && !reduced ? .25 : 1,
            duration: Duration(milliseconds: reduced ? 0 : 220),
            child: AnimatedSlide(
              offset: reacting && !reduced
                  ? Offset(0, hiding ? .18 : -.16)
                  : Offset.zero,
              duration: Duration(milliseconds: reduced ? 0 : 250),
              curve: Curves.easeOutBack,
              child: AnimatedRotation(
                turns: reacting && !reduced ? (hiding ? -.035 : .035) : 0,
                duration: Duration(milliseconds: reduced ? 0 : 220),
                child: ClipRect(
                  child: OverflowBox(
                    minWidth: width * 5,
                    maxWidth: width * 5,
                    minHeight: height,
                    maxHeight: height,
                    child: Transform.translate(
                      offset: Offset((2 - widget.index) * width, 0),
                      child: Image.asset(
                        'assets/characters/garden_people.png',
                        width: width * 5,
                        height: height,
                        fit: BoxFit.fill,
                        excludeFromSemantics: true,
                      ),
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
}
