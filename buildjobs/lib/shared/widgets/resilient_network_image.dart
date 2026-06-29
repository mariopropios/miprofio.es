import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Intenta URL optimizada (p. ej. Supabase render); si falla, usa el original.
class ResilientNetworkImage extends StatefulWidget {
  const ResilientNetworkImage({
    super.key,
    required this.originalUrl,
    required this.optimizedUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
    this.fadeInDuration = const Duration(milliseconds: 120),
    this.placeholder,
    this.error,
  });

  final String originalUrl;
  final String optimizedUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int? memCacheWidth;
  final Duration fadeInDuration;
  final Widget? placeholder;
  final Widget? error;

  @override
  State<ResilientNetworkImage> createState() => _ResilientNetworkImageState();
}

class _ResilientNetworkImageState extends State<ResilientNetworkImage> {
  var _useOriginal = false;

  @override
  Widget build(BuildContext context) {
    final url =
        _useOriginal || widget.optimizedUrl == widget.originalUrl
            ? widget.originalUrl
            : widget.optimizedUrl;

    return CachedNetworkImage(
      imageUrl: url,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      memCacheWidth: widget.memCacheWidth,
      maxWidthDiskCache: widget.memCacheWidth,
      fadeInDuration: widget.fadeInDuration,
      placeholder: (_, __) => widget.placeholder ?? const SizedBox.shrink(),
      errorWidget: (_, __, ___) {
        if (!_useOriginal && widget.optimizedUrl != widget.originalUrl) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _useOriginal = true);
          });
          return widget.placeholder ?? const SizedBox.shrink();
        }
        return widget.error ??
            const Icon(
              Icons.broken_image_outlined,
              color: AppTheme.textSecondary,
            );
      },
    );
  }
}
