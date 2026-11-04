import 'package:flutter/material.dart';

/// A small paper-like press that does not compete with the child's gestures.
class NotebookPress extends StatefulWidget {
  const NotebookPress({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;

  @override
  State<NotebookPress> createState() => _NotebookPressState();
}

class _NotebookPressState extends State<NotebookPress> {
  bool pressed = false;

  void setPressed(bool value) {
    if (pressed != value) setState(() => pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Listener(
      onPointerDown: (_) {
        if (widget.enabled) setPressed(true);
      },
      onPointerUp: (_) => setPressed(false),
      onPointerCancel: (_) => setPressed(false),
      child: AnimatedScale(
        scale: pressed && !reduced ? .975 : 1,
        duration: Duration(milliseconds: reduced ? 0 : (pressed ? 90 : 180)),
        curve: pressed ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

/// A quiet page turn for routes while retaining Flutter's normal navigation.
class NotebookPageTransitions extends PageTransitionsBuilder {
  const NotebookPageTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final curve = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, .025),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }
}
