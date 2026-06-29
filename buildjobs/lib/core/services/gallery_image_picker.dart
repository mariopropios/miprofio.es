import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/utils/x_file_bytes_reader.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/responsive_layout.dart';
import '../../shared/widgets/spring_pressable.dart';

enum _PickSource { gallery, camera, files }

const _allowedImageExtensions = [
  'jpg',
  'jpeg',
  'png',
  'webp',
  'gif',
  'bmp',
  'tif',
  'tiff',
  'heic',
  'heif',
  'avif',
];

/// Selector de imágenes adaptado: móvil (galería/cámara/archivos) y PC (explorador).
class GalleryImagePicker {
  GalleryImagePicker._();

  static final _imagePicker = ImagePicker();

  static Future<List<XFile>> pickImages({
    required BuildContext context,
    required int maxCount,
  }) async {
    if (maxCount <= 0) return [];

    // En web móvil el input nativo es más fiable; en escritorio usamos
    // el explorador de archivos para admitir más formatos (BMP, TIFF, etc.).
    if (kIsWeb) {
      if (ResponsiveLayout.isMobile(context)) {
        return _pickFromWebGallery(maxCount);
      }
      return _pickFromFiles(maxCount);
    }

    final isMobile = ResponsiveLayout.isMobile(context);

    if (isMobile) {
      final source = await _showMobileSourceSheet(context);
      if (source == null) return [];
      return _pickFromSource(source, maxCount);
    }

    return _pickFromFiles(maxCount);
  }

  static Future<List<XFile>> _pickFromWebGallery(int maxCount) async {
    // Para una sola foto usamos pickImage (más fiable en web móvil).
    if (maxCount == 1) {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (picked == null) return [];
      return _normalizePicked([picked]);
    }
    final picked = await _imagePicker.pickMultiImage(limit: maxCount);
    return _normalizePicked(picked.take(maxCount).toList(growable: false));
  }

  static Future<List<XFile>> _normalizePicked(List<XFile> picked) async {
    if (picked.isEmpty) return picked;

    final normalized = <XFile>[];
    for (final file in picked) {
      try {
        final bytes = await readXFileBytes(file);
        normalized.add(
          XFile.fromData(
            bytes,
            name: file.name.isNotEmpty ? file.name : 'photo.jpg',
            mimeType: file.mimeType ?? _mimeTypeFromExtension(
              file.name.contains('.') ? file.name.split('.').last : null,
            ),
          ),
        );
      } catch (_) {
        normalized.add(file);
      }
    }
    return normalized;
  }

  static Future<_PickSource?> _showMobileSourceSheet(BuildContext context) {
    final showCamera = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);

    return showModalBottomSheet<_PickSource>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Añadir fotos',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Elige de dónde quieres subirlas',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _SourceTile(
                icon: Icons.photo_library_outlined,
                title: 'Galería del móvil',
                subtitle: 'Fotos guardadas en tu dispositivo',
                onTap: () => Navigator.pop(ctx, _PickSource.gallery),
              ),
              if (showCamera) ...[
                const SizedBox(height: 8),
                _SourceTile(
                  icon: Icons.photo_camera_outlined,
                  title: 'Hacer una foto',
                  subtitle: 'Abrir la cámara ahora',
                  onTap: () => Navigator.pop(ctx, _PickSource.camera),
                ),
              ],
              const SizedBox(height: 8),
              _SourceTile(
                icon: Icons.folder_open_outlined,
                title: 'Archivos',
                subtitle: 'Buscar en carpetas o almacenamiento',
                onTap: () => Navigator.pop(ctx, _PickSource.files),
              ),
              const SizedBox(height: 8),
              SpringPressable(
                onTap: () => Navigator.pop(ctx),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<List<XFile>> _pickFromSource(
    _PickSource source,
    int maxCount,
  ) async {
    switch (source) {
      case _PickSource.gallery:
        final picked = await _imagePicker.pickMultiImage(
          imageQuality: 85,
          limit: maxCount,
        );
        return _normalizePicked(picked.take(maxCount).toList());
      case _PickSource.camera:
        final photo = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );
        return photo != null ? _normalizePicked([photo]) : [];
      case _PickSource.files:
        return _pickFromFiles(maxCount);
    }
  }

  static Future<List<XFile>> _pickFromFiles(int maxCount) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedImageExtensions,
      allowMultiple: maxCount > 1,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return [];

    final files = <XFile>[];
    for (final file in result.files.take(maxCount)) {
      final xFile = await _toXFile(file);
      if (xFile != null) files.add(xFile);
    }
    return _normalizePicked(files);
  }

  static Future<XFile?> _toXFile(PlatformFile file) async {
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      return XFile.fromData(
        file.bytes!,
        name: file.name,
        mimeType: _mimeTypeFromExtension(file.extension),
      );
    }
    if (file.path != null) {
      return XFile(file.path!, name: file.name);
    }
    if (file.readStream != null) {
      final builder = BytesBuilder(copy: false);
      await for (final chunk in file.readStream!) {
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      if (bytes.isEmpty) return null;
      return XFile.fromData(
        bytes,
        name: file.name,
        mimeType: _mimeTypeFromExtension(file.extension),
      );
    }
    return null;
  }

  static String? _mimeTypeFromExtension(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      case 'bmp':
        return 'image/bmp';
      case 'tif':
      case 'tiff':
        return 'image/tiff';
      case 'avif':
        return 'image/avif';
      default:
        return null;
    }
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SpringPressable(
      onTap: onTap,
      pressedScale: 0.98,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
