import 'package:flutter/material.dart';

/// Drop-in replacement for a tappable GestureDetector: the child eases down
/// slightly while pressed and springs back, so every button feels responsive.
class TapScale extends StatefulWidget {
  const TapScale({
    super.key,
    required this.child,
    this.onTap,
    this.behavior,
    this.pressedScale = 0.96,
  });

  final Widget child;
  final VoidCallback? onTap;
  final HitTestBehavior? behavior;
  final double pressedScale;

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> {
  bool _down = false;

  void _set(bool v) {
    if (mounted && _down != v) setState(() => _down = v);
  }

  // Hold the pressed look briefly so very quick taps still read as a press.
  void _release() => Future.delayed(const Duration(milliseconds: 90), () => _set(false));

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _release() : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: _down ? 0.88 : 1,
          duration: const Duration(milliseconds: 130),
          child: widget.child,
        ),
      ),
    );
  }
}
