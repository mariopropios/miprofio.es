import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/premium_button.dart';
import '../../../../shared/widgets/profession_tags_row.dart';
import '../../../../shared/widgets/rating_stars.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../models/registered_professional_preview.dart';

/// Pantalla de éxito con vista previa del perfil publicado (solo visual).
class ProfessionalRegisterSuccessScreen extends StatefulWidget {
  const ProfessionalRegisterSuccessScreen({super.key, required this.preview});

  final RegisteredProfessionalPreview preview;

  @override
  State<ProfessionalRegisterSuccessScreen> createState() =>
      _ProfessionalRegisterSuccessScreenState();
}

class _ProfessionalRegisterSuccessScreenState
    extends State<ProfessionalRegisterSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _fade;

  RegisteredProfessionalPreview get preview => widget.preview;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Registro completado'),
      ),
      body: ResponsiveContent(
        maxWidth: 720,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FadeTransition(
                opacity: _fade,
                child: _SuccessBanner(scale: _scale),
              ),
              const SizedBox(height: 28),
              FadeTransition(
                opacity: _fade,
                child: Text(
                  'Así verán los clientes tu perfil',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Vista previa · Tu perfil ya está publicado en ${AppConstants.appName}',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 20),
              FadeTransition(
                opacity: _fade,
                child: _ProfilePreviewCard(preview: preview),
              ),
              const SizedBox(height: 28),
              PremiumButton(
                label: 'Ir al inicio',
                onPressed: () => context.go(AppRoutes.home),
              ),
              if (preview.professionalId != null) ...[
                const SizedBox(height: 12),
                PremiumOutlinedButton(
                  label: 'Ver perfil público',
                  onPressed: () => context.go(
                    AppRoutes.companyDetailPath(preview.professionalId!),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner({required this.scale});

  final Animation<double> scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.22),
            AppTheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScaleTransition(
            scale: scale,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 30),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡Registro realizado correctamente!',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Has superado el proceso de alta. Tu perfil ya forma parte del directorio.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePreviewCard extends StatelessWidget {
  const _ProfilePreviewCard({required this.preview});

  final RegisteredProfessionalPreview preview;

  @override
  Widget build(BuildContext context) {
    final hasGallery = preview.galleryImages.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.divider),
        boxShadow: AppTheme.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CoverImage(
            networkUrl: preview.profilePhotoUrl,
            localFile: preview.galleryImages.isNotEmpty
                ? preview.galleryImages.first
                : null,
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        preview.name,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Nuevo',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Row(
                  children: [
                    RatingStars(rating: 0, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Sin reseñas aún',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ProfessionTagsRow(
                  professions: preview.professions,
                  maxVisible: 8,
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  text: preview.city,
                ),
                if (preview.phone.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _InfoRow(
                    icon: Icons.phone_outlined,
                    text: preview.phone,
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  'Sobre este profesional',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  preview.bio,
                  style: const TextStyle(height: 1.5, fontSize: 15),
                ),
                if (hasGallery && preview.galleryImages.length > 1) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Galería de trabajos',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 88,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: preview.galleryImages.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _LocalThumb(file: preview.galleryImages[index]),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.visibility_outlined,
                          color: AppTheme.textSecondary, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Vista previa · Los clientes podrán contactarte y dejarte reseñas.',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({this.networkUrl, this.localFile});

  final String? networkUrl;
  final XFile? localFile;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: networkUrl != null && networkUrl!.isNotEmpty
          ? Image.network(networkUrl!, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _localOrPlaceholder())
          : _localOrPlaceholder(),
    );
  }

  Widget _localOrPlaceholder() {
    if (localFile != null) {
      return FutureBuilder<Uint8List>(
        future: localFile!.readAsBytes(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return _placeholder();
          }
          return Image.memory(snapshot.data!, fit: BoxFit.cover);
        },
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      color: AppTheme.surfaceElevated,
      child: Center(
        child: Icon(
          Icons.construction,
          size: 56,
          color: AppTheme.textSecondary.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

class _LocalThumb extends StatelessWidget {
  const _LocalThumb({required this.file});

  final XFile file;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            width: 88,
            height: 88,
            color: AppTheme.surfaceElevated,
          );
        }
        return Image.memory(
          snapshot.data!,
          width: 88,
          height: 88,
          fit: BoxFit.cover,
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
        ),
      ],
    );
  }
}
