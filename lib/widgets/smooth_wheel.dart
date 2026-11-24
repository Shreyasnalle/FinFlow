import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Place this inside a vertical scroll view's content. Mouse-wheel / trackpad
/// steps (which the framework applies as instant jumps) become an eased
/// animation, so scrolling glides instead of snapping. Touch scrolling is
/// unaffected.
class SmoothWheel extends StatelessWidget {
  const SmoothWheel({super.key, required this.child});
  final Widget child;

  static final _targets = Expando<double>();

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerSignal: (e) => _onSignal(context, e),
      child: child,
    );
  }

  static void _onSignal(BuildContext context, PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    final dy = e.scrollDelta.dy;
    if (dy == 0) return;
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null || scrollable.position.axis != Axis.vertical) return;
    final pos = scrollable.position;
    // Registering first (we sit inside the scrollable) stops the default instant jump.
    GestureBinding.instance.pointerSignalResolver.register(e, (_) {
      final running = pos.isScrollingNotifier.value ? _targets[pos] : null;
      final base = running ?? pos.pixels;
      final target = math.min(math.max(base + dy, pos.minScrollExtent), pos.maxScrollExtent);
      _targets[pos] = target;
      pos.animateTo(target, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    });
  }
}
