import 'package:flutter/material.dart';

/// Interacción estilo iOS: sin ripple de Material, opacidad al 80% y
/// escala elástica (0.96 → 1.0 con rebote) al presionar.
class SpringPressable extends StatefulWidget {
  const SpringPressable({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
    this.pressedScale = 0.96,
    this.pressedOpacity = 0.8,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final double pressedScale;
  final double pressedOpacity;

  @override
  State<SpringPressable> createState() => _SpringPressableState();
}

class _SpringPressableState extends State<SpringPressable>
    with SingleTickerProviderStateMixin {
  late AnimationController _springController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  bool get _canInteract => widget.enabled && widget.onTap != null;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _scaleAnimation = Tween<double>(
      begin: widget.pressedScale,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _springController,
        curve: Curves.elasticOut,
      ),
    );
    _springController.value = 1.0;
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent _) {
    if (!_canInteract) return;
    setState(() => _isPressed = true);
    _springController.value = 0.0;
  }

  void _handlePointerUp(PointerUpEvent _) {
    if (!_canInteract) return;
    setState(() => _isPressed = false);
    _springController.forward(from: 0.0);
    widget.onTap?.call();
  }

  void _handlePointerCancel(PointerCancelEvent _) {
    if (!_canInteract) return;
    setState(() => _isPressed = false);
    _springController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          final scale = _canInteract
              ? (_isPressed ? widget.pressedScale : _scaleAnimation.value)
              : 1.0;
          final opacity = _canInteract && _isPressed
              ? widget.pressedOpacity
              : 1.0;

          return Opacity(
            opacity: opacity,
            child: Transform.scale(scale: scale, child: child),
          );
        },
        child: widget.child,
      ),
    );
  }
}
