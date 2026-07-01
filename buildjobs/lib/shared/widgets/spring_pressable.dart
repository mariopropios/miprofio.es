import 'dart:math' as math;

import 'package:flutter/gestures.dart';
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
    /// Distancia máxima de arrastre para contar como tap (evita taps al scroll).
    this.tapSlop = kTouchSlop,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final double pressedScale;
  final double pressedOpacity;
  final double tapSlop;

  @override
  State<SpringPressable> createState() => _SpringPressableState();
}

class _SpringPressableState extends State<SpringPressable>
    with SingleTickerProviderStateMixin {
  late AnimationController _springController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;
  Offset? _downGlobalPosition;
  bool _exceededSlop = false;

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

  void _releasePress({required bool fireTap}) {
    if (!_canInteract) return;
    final shouldTap = fireTap && !_exceededSlop;
    setState(() {
      _isPressed = false;
      _downGlobalPosition = null;
      _exceededSlop = false;
    });
    _springController.forward(from: 0.0);
    if (shouldTap) widget.onTap?.call();
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!_canInteract) return;
    _downGlobalPosition = event.position;
    _exceededSlop = false;
    setState(() => _isPressed = true);
    _springController.value = 0.0;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_canInteract || _downGlobalPosition == null || _exceededSlop) {
      return;
    }

    final delta = event.position - _downGlobalPosition!;
    if (math.sqrt(delta.dx * delta.dx + delta.dy * delta.dy) > widget.tapSlop) {
      _exceededSlop = true;
      setState(() => _isPressed = false);
      _springController.forward(from: 0.0);
    }
  }

  void _handlePointerUp(PointerUpEvent _) {
    _releasePress(fireTap: true);
  }

  void _handlePointerCancel(PointerCancelEvent _) {
    _releasePress(fireTap: false);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
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
