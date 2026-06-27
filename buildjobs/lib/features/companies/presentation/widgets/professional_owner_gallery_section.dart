import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/services/profile_photo_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/premium_button.dart';
import '../../../../shared/widgets/work_gallery_strip.dart';
import '../../../auth/presentation/widgets/work_gallery_upload.dart';

class ProfessionalOwnerGallerySection extends ConsumerStatefulWidget {
  const ProfessionalOwnerGallerySection({
    super.key,
    required this.professionalId,
    required this.photoUrls,
  });

  final String professionalId;
  final List<String> photoUrls;

  @override
  ConsumerState<ProfessionalOwnerGallerySection> createState() =>
      _ProfessionalOwnerGallerySectionState();
}

class _ProfessionalOwnerGallerySectionState
    extends ConsumerState<ProfessionalOwnerGallerySection> {
  bool _isUploading = false;

  Future<void> _openUploadSheet() async {
    final picked = await showModalBottomSheet<List<XFile>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _GalleryUploadSheet(
        initialCount: widget.photoUrls.length,
      ),
    );

    if (!mounted || picked == null || picked.isEmpty) return;

    // Deja cerrar el modal antes de comprimir/subir (evita UI congelada).
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;

    await _savePhotos(picked);
  }

  Future<void> _savePhotos(List<XFile> files) async {
    setState(() => _isUploading = true);

    try {
      final client = ref.read(supabaseClientProvider);
      final storage = ProfilePhotoStorage(client);
      final urls = await storage.uploadGalleryImages(files, widget.professionalId);

      final mergedUrls = [...widget.photoUrls, ...urls];

      await ref.read(professionalRepositoryProvider).updateGalleryPhotos(
            userId: widget.professionalId,
            galleryPhotoUrls: mergedUrls,
          );

      ref.invalidate(professionalDetailProvider(widget.professionalId));
      ref.invalidate(currentUserProfessionalViewProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fotos guardadas correctamente')),
        );
      }
    } on StorageException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ProfilePhotoStorage.friendlyErrorMessage(e)),
          ),
        );
      }
    } on FormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } on StateError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'La subida tardó demasiado. Comprueba tu conexión e inténtalo de nuevo.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir fotos: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhotos = widget.photoUrls.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasPhotos)
          WorkGalleryStrip(
            photoUrls: widget.photoUrls,
            lightboxTitle: 'Galería de trabajos',
          ),
        if (!hasPhotos && !_isUploading) const _EmptyGalleryHint(),
        if (_isUploading) ...[
          const SizedBox(height: 8),
          const _UploadingHint(),
        ],
        const SizedBox(height: 12),
        PremiumOutlinedButton(
          label: _isUploading
              ? 'Subiendo fotos...'
              : (hasPhotos ? 'Añadir más fotos' : 'Añadir fotos de trabajos'),
          icon: _isUploading ? null : Icons.add_photo_alternate_outlined,
          onPressed: _isUploading ? null : _openUploadSheet,
        ),
      ],
    );
  }
}

class _UploadingHint extends StatelessWidget {
  const _UploadingHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Comprimiendo y subiendo tus fotos...',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryUploadSheet extends StatefulWidget {
  const _GalleryUploadSheet({required this.initialCount});

  final int initialCount;

  @override
  State<_GalleryUploadSheet> createState() => _GalleryUploadSheetState();
}

class _GalleryUploadSheetState extends State<_GalleryUploadSheet> {
  List<XFile> _images = [];
  bool _isSaving = false;

  Future<void> _saveAndClose() async {
    if (_images.isEmpty || _isSaving) return;
    setState(() => _isSaving = true);
    Navigator.of(context).pop(_images);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Fotos de trabajos',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sube fotos de proyectos que hayas realizado. La primera será la imagen principal de tu perfil.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 16),
          WorkGalleryUpload(
            images: _images,
            onImagesChanged: (next) => setState(() => _images = next),
            maxImages: AppConstants.maxGalleryPhotos,
          ),
          const SizedBox(height: 16),
          PremiumButton(
            label: _isSaving ? 'Preparando...' : 'Guardar fotos',
            isLoading: _isSaving,
            onPressed: _images.isEmpty || _isSaving ? null : _saveAndClose,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}

class _EmptyGalleryHint extends StatelessWidget {
  const _EmptyGalleryHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 100,
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              color: AppTheme.textSecondary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 4),
            Text(
              'Sin fotos de trabajos',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
