import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';
import 'x_file_bytes_reader.dart';

/// Miniatura de un [XFile] estable entre rebuilds (evita spinner infinito).
class XFilePreviewImage extends StatefulWidget {
  const XFilePreviewImage({
    super.key,
    required this.file,
    this.width = 88,
    this.height = 88,
    this.borderRadius = 10,
    this.fit = BoxFit.cover,
  });

  final XFile file;
  final double width;
  final double height;
  final double borderRadius;
  final BoxFit fit;

  @override
  State<XFilePreviewImage> createState() => _XFilePreviewImageState();
}

class _XFilePreviewImageState extends State<XFilePreviewImage> {
  Uint8List? _bytes;
  bool _loading = true;
  String? _webPreviewUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(XFilePreviewImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path ||
        oldWidget.file.name != widget.file.name) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _bytes = null;
      _webPreviewUrl = null;
    });

    final path = widget.file.path;
    if (kIsWeb && _isWebDisplayUrl(path)) {
      if (mounted) {
        setState(() {
          _webPreviewUrl = path;
          _loading = false;
        });
      }
      return;
    }

    try {
      final bytes = await readXFileBytes(widget.file);
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      if (kIsWeb && path.isNotEmpty && _isWebDisplayUrl(path)) {
        setState(() {
          _webPreviewUrl = path;
          _loading = false;
        });
        return;
      }
      setState(() {
        _loading = false;
      });
    }
  }

  bool _isWebDisplayUrl(String path) {
    return path.startsWith('blob:') || path.startsWith('data:');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _box(
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_webPreviewUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Image.network(
          _webPreviewUrl!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (_, __, ___) => _broken(),
        ),
      );
    }

    if (_bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Image.memory(
          _bytes!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (_, __, ___) => _broken(),
        ),
      );
    }

    return _broken();
  }

  Widget _box({required Widget child}) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      child: child,
    );
  }

  Widget _broken() {
    return _box(
      child: const Icon(
        Icons.broken_image_outlined,
        color: AppTheme.textSecondary,
        size: 22,
      ),
    );
  }
}
