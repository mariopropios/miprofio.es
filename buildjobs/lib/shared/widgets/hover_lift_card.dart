import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'spring_pressable.dart';

/// Tarjeta interactiva con hover lift (web/desktop) y press spring (iOS-like).
class HoverLiftCard extends StatefulWidget {
  const HoverLiftCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = AppTheme.radiusMd,
    this.padding = EdgeInsets.zero,
    this.enableHover = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final bool enableHover;

  @override
  State<HoverLiftCard> createState() => _HoverLiftCardState();
}

class _HoverLiftCardState extends State<HoverLiftCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final lift = widget.enableHover && _hovering && !kIsWeb;

    return MouseRegion(
      onEnter: widget.enableHover ? (_) => setState(() => _hovering = true) : null,
      onExit: widget.enableHover ? (_) => setState(() => _hovering = false) : null,
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: AnimatedContainer(
        duration: AppTheme.hoverDuration,
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, lift ? -4 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: kIsWeb
              ? const []
              : (lift ? AppTheme.cardShadowHover : AppTheme.cardShadow),
        ),
        child: widget.onTap != null
            ? SpringPressable(onTap: widget.onTap, child: _cardContent())
            : _cardContent(),
      ),
    );
  }

  Widget _cardContent() => Container(
        padding: widget.padding,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(color: AppTheme.divider, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: widget.child,
      );
}
