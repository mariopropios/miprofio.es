import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/services/gallery_image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/x_file_preview_image.dart';
import '../../../../shared/widgets/spring_pressable.dart';

enum ProfileAvatarKind {
  professional,
  client,
}

/// Selector de foto de perfil con recomendaciones según el tipo de cuenta.
class ProfileAvatarPicker extends StatefulWidget {
  const ProfileAvatarPicker({
    super.key,
    required this.kind,
    required this.image,
    required this.onImageChanged,
    this.compact = false,
  });

  final ProfileAvatarKind kind;
  final XFile? image;
  final ValueChanged<XFile?> onImageChanged;
  final bool compact;

  @override
  State<ProfileAvatarPicker> createState() => _ProfileAvatarPickerState();
}

class _ProfileAvatarPickerState extends State<ProfileAvatarPicker> {
  bool _isPicking = false;

  String get _title => switch (widget.kind) {
        ProfileAvatarKind.professional => 'Tu logo o imagen de perfil',
        ProfileAvatarKind.client => 'Tu foto de perfil',
      };

  String get _subtitle => switch (widget.kind) {
        ProfileAvatarKind.professional =>
          'Te recomendamos subir el logo de tu negocio para que los clientes te reconozcan al instante.',
        ProfileAvatarKind.client =>
          'Elige la foto que quieras que aparezca en tu perfil.',
      };

  IconData get _placeholderIcon => switch (widget.kind) {
        ProfileAvatarKind.professional => Icons.storefront_outlined,
        ProfileAvatarKind.client => Icons.person_outline,
      };

  String get _pickLabel => switch (widget.kind) {
        ProfileAvatarKind.professional => 'Subir logo o imagen',
        ProfileAvatarKind.client => 'Elegir foto',
      };

  Future<void> _pickImage() async {
    if (_isPicking) return;

    final pickFuture = GalleryImagePicker.pickImages(
      context: context,
      maxCount: 1,
    );

    setState(() => _isPicking = true);
    try {
      final picked = await pickFuture;
      if (!mounted || picked.isEmpty) return;
      widget.onImageChanged(picked.first);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cargar la imagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.compact ? 88.0 : 104.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          _subtitle,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: widget.compact ? 13 : 14,
            height: 1.4,
          ),
        ),
        SizedBox(height: widget.compact ? 16 : 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SpringPressable(
              onTap: _isPicking ? null : _pickImage,
              child: Stack(
                children: [
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(size * 0.22),
                      border: Border.all(
                        color: widget.image != null
                            ? AppTheme.primary.withValues(alpha: 0.5)
                            : AppTheme.divider,
                        width: widget.image != null ? 2 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: widget.image == null
                        ? Center(
                            child: _isPicking
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    _placeholderIcon,
                                    size: size * 0.38,
                                    color: AppTheme.textSecondary,
                                  ),
                          )
                        : XFilePreviewImage(
                            file: widget.image!,
                            width: size,
                            height: size,
                            borderRadius: size * 0.22,
                          ),
                  ),
                  if (widget.image != null && !_isPicking)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.surface),
                        ),
                        child: const Icon(
                          Icons.edit_outlined,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isPicking ? null : _pickImage,
                    icon: _isPicking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_photo_alternate_outlined, size: 18),
                    label: Text(_isPicking ? 'Abriendo...' : _pickLabel),
                  ),
                  if (widget.image != null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _isPicking
                          ? null
                          : () => widget.onImageChanged(null),
                      child: const Text('Quitar foto'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
