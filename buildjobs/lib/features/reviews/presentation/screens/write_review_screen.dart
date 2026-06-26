import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/services/gallery_image_picker.dart';
import '../../../../core/services/profile_photo_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/x_file_preview_image.dart';
import '../../../../shared/widgets/premium_button.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../../shared/widgets/spring_pressable.dart';

class WriteReviewScreen extends ConsumerStatefulWidget {
  const WriteReviewScreen({super.key, required this.companyId});

  final String companyId;

  @override
  ConsumerState<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends ConsumerState<WriteReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  int _rating = 5;
  bool _isSubmitting = false;
  final List<XFile> _photos = [];
  static const _maxPhotos = 4;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(currentUserProvider);
      if (user == null && mounted) {
        context.pushReplacement(
          AppRoutes.loginWithRedirect(
            AppRoutes.writeReviewPath(widget.companyId),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final remaining = _maxPhotos - _photos.length;
    if (remaining <= 0) return;
    final picked = await GalleryImagePicker.pickImages(
      context: context,
      maxCount: remaining,
    );
    if (picked.isNotEmpty) {
      setState(() => _photos.addAll(picked.take(remaining)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isMobile = ResponsiveLayout.isMobile(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escribir reseña'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.companyDetailPath(widget.companyId));
            }
          },
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              isMobile ? 16 : 32,
              20,
              isMobile ? 16 : 32,
              32,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Valoración ─────────────────────────────────────────
                  Text(
                    'Tu valoración',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: List.generate(5, (index) {
                      return SpringPressable(
                        onTap: () => setState(() => _rating = index + 1),
                        pressedScale: 0.88,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Icon(
                            index < _rating ? Icons.star_rounded : Icons.star_border_rounded,
                            color: AppTheme.primary,
                            size: 40,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),

                  // ── Título ─────────────────────────────────────────────
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Título de la reseña',
                      hintText: 'Resume tu experiencia en pocas palabras',
                    ),
                    validator: (v) =>
                        v == null || v.trim().length < 3
                            ? 'Mínimo 3 caracteres'
                            : null,
                  ),
                  const SizedBox(height: 16),

                  // ── Cuerpo ─────────────────────────────────────────────
                  TextFormField(
                    controller: _bodyController,
                    decoration: const InputDecoration(
                      labelText: 'Tu reseña',
                      hintText: 'Cuéntanos los detalles de tu experiencia...',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 5,
                    validator: (v) =>
                        v == null || v.trim().length < 20
                            ? 'Mínimo 20 caracteres'
                            : null,
                  ),
                  const SizedBox(height: 20),

                  // ── Fotos opcionales ───────────────────────────────────
                  Row(
                    children: [
                      Text(
                        'Fotos (opcional)',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const Spacer(),
                      Text(
                        '${_photos.length} / $_maxPhotos',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _PhotoPicker(
                    photos: _photos,
                    maxPhotos: _maxPhotos,
                    onAdd: _pickPhotos,
                    onRemove: (i) => setState(() => _photos.removeAt(i)),
                  ),
                  const SizedBox(height: 28),

                  // ── Botón publicar ─────────────────────────────────────
                  PremiumButton(
                    label: _isSubmitting ? 'Publicando…' : 'Publicar reseña',
                    isLoading: _isSubmitting,
                    onPressed: _isSubmitting ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      await ref.read(reviewRepositoryProvider).createReview(
            professionalId: widget.companyId,
            rating: _rating,
            title: _titleController.text.trim(),
            body: _bodyController.text.trim(),
            photos: List.unmodifiable(_photos),
          );

      ref.invalidate(professionalReviewsProvider(widget.companyId));
      ref.invalidate(professionalDetailProvider(widget.companyId));
      ref.invalidate(featuredProfessionalsProvider);
      ref.invalidate(professionalsProvider);

      if (mounted) {
        // Ir al perfil del profesional para que el usuario vea su reseña publicada.
        // Usamos go() en vez de pop() para garantizar el destino independientemente
        // de cómo se llegó a esta pantalla.
        context.go(AppRoutes.companyDetailPath(widget.companyId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Reseña publicada! Ya aparece en el perfil.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al publicar: ${e.message}')),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al publicar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

// ── Selector de fotos ─────────────────────────────────────────────────────────

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.photos,
    required this.maxPhotos,
    required this.onAdd,
    required this.onRemove,
  });

  final List<XFile> photos;
  final int maxPhotos;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  static const _size = 88.0;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ...List.generate(photos.length, (i) => _thumb(context, i)),
        if (photos.length < maxPhotos) _addButton(context),
      ],
    );
  }

  Widget _thumb(BuildContext context, int index) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: XFilePreviewImage(
            file: photos[index],
            width: _size,
            height: _size,
          ),
        ),
        Positioned(
          top: -8,
          right: -8,
          child: GestureDetector(
            onTap: () => onRemove(index),
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _addButton(BuildContext context) {
    return SpringPressable(
      onTap: onAdd,
      pressedScale: 0.96,
      child: Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.5),
            style: BorderStyle.solid,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              color: AppTheme.primary,
              size: 28,
            ),
            SizedBox(height: 4),
            Text(
              'Añadir',
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
