import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/storage_image_url.dart';
import '../../../../shared/models/professional.dart';
import '../../../../shared/models/review.dart';
import '../../../../shared/widgets/async_value_widget.dart';
import '../../../../shared/widgets/premium_button.dart';
import '../../../../shared/widgets/save_professional_button.dart';
import 'professional_owner_gallery_section.dart';
import '../../../../shared/widgets/profession_tags_row.dart';
import '../../../../shared/widgets/message_email_notification_card.dart';
import '../../../../shared/widgets/push_notification_setup_card.dart';
import '../../../../shared/widgets/rating_stars.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../../shared/widgets/resilient_network_image.dart';
import '../../../../shared/widgets/spring_pressable.dart';
import '../../../../shared/widgets/work_gallery_strip.dart';
import '../../../saved/providers/saved_professional_providers.dart';

/// Vista pública del perfil profesional (la misma que ven los clientes).
class ProfessionalPublicProfileBody extends ConsumerWidget {
  const ProfessionalPublicProfileBody({
    super.key,
    required this.companyId,
    this.bottomPadding = 80,
    this.isOwnerView = false,
  });

  final String companyId;
  final double bottomPadding;
  final bool isOwnerView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyAsync = ref.watch(professionalDetailProvider(companyId));
    final reviewsAsync = ref.watch(professionalReviewsProvider(companyId));
    ref.watch(professionalSavedCountRealtimeProvider(companyId));
    final dateFormat = DateFormat('d MMM yyyy', 'es');

    return companyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('Error al cargar: $e', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              PremiumButton(
                label: 'Reintentar',
                expand: false,
                onPressed: () =>
                    ref.invalidate(professionalDetailProvider(companyId)),
              ),
            ],
          ),
        ),
      ),
      data: (company) {
        if (company == null) {
          return const Center(child: Text('Profesional no encontrado'));
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.read(savedCountDeltaProvider.notifier).update((d) {
              final next = Map<String, int>.from(d);
              next.remove(companyId);
              return next;
            });
            ref.invalidate(professionalDetailProvider(companyId));
            ref.invalidate(professionalReviewsProvider(companyId));
            await Future.wait([
              ref.read(professionalDetailProvider(companyId).future),
              ref.read(professionalReviewsProvider(companyId).future),
            ]);
          },
          child: ResponsiveContent(
            maxWidth: 900,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
              child: _ProfessionalProfileContent(
                company: company,
                reviewsAsync: reviewsAsync,
                dateFormat: dateFormat,
                isOwnerView: isOwnerView,
                companyId: companyId,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SavedCountChip extends StatelessWidget {
  const _SavedCountChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count == 1 ? '1 guardado' : '$count guardados';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.favorite_rounded, size: 14, color: Colors.redAccent),
          const SizedBox(width: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: child,
            ),
            child: Text(
              label,
              key: ValueKey<int>(count),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfessionalProfileContent extends ConsumerWidget {
  const _ProfessionalProfileContent({
    required this.company,
    required this.reviewsAsync,
    required this.dateFormat,
    required this.companyId,
    this.isOwnerView = false,
  });

  final Professional company;
  final AsyncValue<List<Review>> reviewsAsync;
  final DateFormat dateFormat;
  final String companyId;
  final bool isOwnerView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedCount = ref.watch(effectiveSavedCountProvider(companyId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Identidad del perfil PRIMERO: si la tarjeta push falla en release
        // (ErrorWidget gris enorme), foto y nombre siguen visibles arriba.
        _HeaderImage(imageUrl: company.profilePhoto),
        const SizedBox(height: 16),
        Text(
          company.name,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            RatingStars(rating: company.rating, size: 16),
            Text(
              '${company.reviewCount} reseñas',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            if (savedCount > 0 || isOwnerView)
              _SavedCountChip(count: savedCount),
          ],
        ),
        const SizedBox(height: 12),
        ProfessionTagsRow(
          professions: company.professions.isNotEmpty
              ? company.professions
              : [company.profession],
          maxVisible: 12,
        ),
        if (!isOwnerView) ...[
          const SizedBox(height: 12),
          SaveProfessionalButton(
            professionalId: companyId,
            showLabel: true,
          ),
        ],
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 16,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              company.city,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],
        ),
        if (company.serviceRadiusKm > 0) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.directions_car_outlined,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                company.travelRadiusLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            ],
          ),
        ],
        if (isOwnerView) ...[
          const SizedBox(height: 16),
          const MessageEmailNotificationCard(),
          const SizedBox(height: 12),
          const PushNotificationSetupCard(),
        ],
        if (company.description != null && _cleanDescription(company.description!).isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Sobre este profesional',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          _ExpandableDescription(text: _cleanDescription(company.description!)),
        ],
        const SizedBox(height: 24),
        _ContactCard(
          city: company.city,
          address: company.address,
          email: company.email,
          phone: company.phone,
          website: company.website,
        ),
        if (!isOwnerView) ...[
          const SizedBox(height: 16),
          _SendMessageButton(
            professionalId: company.id,
            professionalName: company.name,
            professionalPhoto: company.profilePhoto,
          ),
        ],
        const SizedBox(height: 24),
        Text(
          'Galería de trabajos',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        if (isOwnerView)
          ProfessionalOwnerGallerySection(
            professionalId: company.id,
            photoUrls: company.workGalleryPhotos,
          )
        else
          WorkGalleryStrip(photoUrls: company.workGalleryPhotos),
        const Divider(height: 40),
        AsyncValueWidget<List<Review>>(
          value: reviewsAsync,
          loadingMessage: 'Cargando reseñas...',
          empty: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reseñas',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  isOwnerView
                      ? 'Aún no tienes reseñas. Cuando los clientes te valoren, aparecerán aquí.'
                      : 'Aún no hay reseñas. ¡Sé el primero!',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          data: (reviews) => _ReviewsSection(
            reviews: reviews,
            dateFormat: dateFormat,
            isOwnerView: isOwnerView,
            professionalId: company.id,
          ),
        ),
      ],
    );
  }
}

/// Elimina el fragmento "Tel: ..." que se añadía al bio durante el registro antiguo.
String _cleanDescription(String description) {
  return description
      .replaceAll(RegExp(r'\n\nTel:.*$', dotAll: true), '')
      .trim();
}

/// Descripción expandible: 4 líneas por defecto + «Ver más» si hay overflow real.
class _ExpandableDescription extends StatefulWidget {
  const _ExpandableDescription({required this.text});
  final String text;

  static const _maxCollapsedLines = 4;

  @override
  State<_ExpandableDescription> createState() =>
      _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  bool _expanded = false;
  bool _overflows = false;
  double? _lastMeasuredWidth;

  TextStyle _bodyStyle(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondary,
            height: 1.55,
          ) ??
      const TextStyle(color: AppTheme.textSecondary, height: 1.55);

  bool _textOverflowsAtWidth({
    required String text,
    required TextStyle style,
    required double maxWidth,
  }) {
    if (maxWidth <= 0) return false;

    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: _ExpandableDescription._maxCollapsedLines,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);

    return painter.didExceedMaxLines;
  }

  void _measureOverflow(BuildContext context, double maxWidth) {
    if (maxWidth <= 0) return;
    // Evitar setState en bucle si el ancho no cambió de forma significativa.
    if (_lastMeasuredWidth != null &&
        (maxWidth - _lastMeasuredWidth!).abs() < 0.5) {
      return;
    }
    _lastMeasuredWidth = maxWidth;

    final overflows = _textOverflowsAtWidth(
      text: widget.text,
      style: _bodyStyle(context),
      maxWidth: maxWidth,
    );

    if (overflows != _overflows) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _overflows = overflows;
          if (!overflows) _expanded = false;
        });
      });
    }
  }

  @override
  void didUpdateWidget(covariant _ExpandableDescription oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _lastMeasuredWidth = null;
      _expanded = false;
      _overflows = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _bodyStyle(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        _measureOverflow(context, constraints.maxWidth);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              alignment: Alignment.topLeft,
              child: Text(
                widget.text,
                maxLines: _expanded
                    ? null
                    : _ExpandableDescription._maxCollapsedLines,
                overflow:
                    _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                style: style,
              ),
            ),
            if (_overflows)
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _expanded ? 'Ver menos' : 'Ver más',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HeaderImage extends StatelessWidget {
  const _HeaderImage({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final cacheWidth =
        (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context))
            .ceil()
            .clamp(400, 960);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 220,
        width: double.infinity,
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: StorageImageUrl.display(
                  imageUrl!,
                  maxWidth: cacheWidth,
                ),
                fit: BoxFit.cover,
                width: double.infinity,
                height: 220,
                memCacheWidth: cacheWidth,
                maxWidthDiskCache: cacheWidth,
                fadeInDuration: const Duration(milliseconds: 150),
                placeholder: (_, __) => Container(
                  color: AppTheme.surfaceElevated,
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (_, __, ___) => CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 220,
                  memCacheWidth: cacheWidth,
                  errorWidget: (_, __, ___) => _placeholder(),
                ),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppTheme.surfaceElevated,
      child: const Center(
        child: Icon(Icons.construction, size: 64, color: AppTheme.textSecondary),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.city,
    required this.address,
    this.email,
    this.phone,
    this.website,
  });

  final String city;
  final String address;
  final String? email;
  final String? phone;
  final String? website;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contacto',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            _ContactRow(icon: Icons.location_city, label: 'Ciudad', value: city),
            if (email != null && email!.isNotEmpty)
              _ContactRow(
                icon: Icons.email_outlined,
                label: 'Correo',
                value: email!,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: email!.trim()));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Correo copiado al portapapeles'),
                    ),
                  );
                },
                trailing: const Icon(Icons.copy, size: 18),
              ),
            if (phone != null && phone!.isNotEmpty)
              _ContactRow(
                icon: Icons.phone,
                label: 'Teléfono',
                value: phone!,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: phone!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Teléfono copiado al portapapeles'),
                    ),
                  );
                },
                trailing: const Icon(Icons.copy, size: 18),
              ),
            if (website != null && website!.isNotEmpty)
              _ContactRow(
                icon: Icons.language,
                label: 'Web',
                value: website!,
                isLink: true,
                onTap: () async {
                  final raw = website!.trim();
                  final uri = Uri.tryParse(
                    raw.startsWith('http') ? raw : 'https://$raw',
                  );
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    Clipboard.setData(ClipboardData(text: raw));
                  }
                },
                trailing: const Icon(Icons.open_in_new_rounded,
                    size: 16, color: AppTheme.primary),
              ),
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.trailing,
    this.isLink = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isLink;

  @override
  Widget build(BuildContext context) {
    return SpringPressable(
      onTap: onTap,
      pressedScale: 0.98,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppTheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isLink ? AppTheme.primary : null,
                      decoration:
                          isLink ? TextDecoration.underline : null,
                      decorationColor:
                          isLink ? AppTheme.primary : null,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

// ── Ordenado de reseñas ───────────────────────────────────────────────────────

enum _ReviewSort {
  recent('Más recientes', Icons.schedule_rounded),
  oldest('Más antiguas', Icons.history_rounded),
  best('Mejor valoradas', Icons.star_rounded),
  worst('Peor valoradas', Icons.star_outline_rounded);

  const _ReviewSort(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _ReviewsSection extends StatefulWidget {
  const _ReviewsSection({
    required this.reviews,
    required this.dateFormat,
    required this.isOwnerView,
    required this.professionalId,
  });

  final List<Review> reviews;
  final DateFormat dateFormat;
  final bool isOwnerView;
  final String professionalId;

  @override
  State<_ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<_ReviewsSection> {
  _ReviewSort _sort = _ReviewSort.recent;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prefetchReviewPhotos();
  }

  void _prefetchReviewPhotos() {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    const thumbSize = _ReviewPhotoThumb.size;
    final cacheSize = (thumbSize * dpr).ceil().clamp(80, 240);

    for (final review in widget.reviews) {
      for (final url in review.photoUrls.take(3)) {
        final optimized = StorageImageUrl.thumbnail(
          url,
          width: cacheSize,
          height: cacheSize,
        );
        precacheImage(
          CachedNetworkImageProvider(
            optimized,
            maxWidth: cacheSize,
            maxHeight: cacheSize,
          ),
          context,
        );
      }
    }
  }

  List<Review> get _sorted {
    final list = [...widget.reviews];
    switch (_sort) {
      case _ReviewSort.recent:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _ReviewSort.oldest:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case _ReviewSort.best:
        list.sort((a, b) {
          final cmp = b.rating.compareTo(a.rating);
          return cmp != 0 ? cmp : b.createdAt.compareTo(a.createdAt);
        });
      case _ReviewSort.worst:
        list.sort((a, b) {
          final cmp = a.rating.compareTo(b.rating);
          return cmp != 0 ? cmp : b.createdAt.compareTo(a.createdAt);
        });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _sorted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Cabecera con contador y selector de orden ──────────────────
        Row(
          children: [
            Text(
              'Reseñas',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${sorted.length}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const Spacer(),
            // Selector de orden
            PopupMenuButton<_ReviewSort>(
              initialValue: _sort,
              onSelected: (v) => setState(() => _sort = v),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: AppTheme.surface,
              itemBuilder: (_) => _ReviewSort.values
                  .map(
                    (s) => PopupMenuItem<_ReviewSort>(
                      value: s,
                      child: Row(
                        children: [
                          Icon(
                            s.icon,
                            size: 18,
                            color: s == _sort
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            s.label,
                            style: TextStyle(
                              color: s == _sort
                                  ? AppTheme.primary
                                  : AppTheme.textPrimary,
                              fontWeight: s == _sort
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_sort.icon, size: 15, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      _sort.label,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_drop_down,
                      size: 18,
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Lista de reseñas ordenadas ──────────────────────────────────
        ...sorted.map(
          (review) => _ReviewTile(
            review: review,
            dateFormat: widget.dateFormat,
            isOwnerView: widget.isOwnerView,
            professionalId: widget.professionalId,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ReviewTile extends ConsumerStatefulWidget {
  const _ReviewTile({
    required this.review,
    required this.dateFormat,
    required this.isOwnerView,
    required this.professionalId,
  });

  final Review review;
  final DateFormat dateFormat;
  final bool isOwnerView;
  final String professionalId;

  @override
  ConsumerState<_ReviewTile> createState() => _ReviewTileState();
}

class _ReviewTileState extends ConsumerState<_ReviewTile> {
  bool _showReplyField = false;
  final _replyController = TextEditingController();
  bool _isSavingReply = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _saveReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSavingReply = true);
    try {
      await ref.read(reviewRepositoryProvider).replyToReview(
            reviewId: widget.review.id,
            reply: text,
          );
      ref.invalidate(professionalReviewsProvider(widget.professionalId));
      if (mounted) setState(() => _showReplyField = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar respuesta: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingReply = false);
    }
  }

  Future<void> _deleteReply() async {
    await ref
        .read(reviewRepositoryProvider)
        .deleteReply(widget.review.id);
    ref.invalidate(professionalReviewsProvider(widget.professionalId));
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabecera: avatar + nombre + fecha + estrellas ──────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (review.reviewerIsProfessional) {
                        context.push(
                          AppRoutes.companyDetailPath(
                            review.reviewerProfessionalId!,
                          ),
                        );
                      } else {
                        context.push(AppRoutes.userProfilePath(review.userId));
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Row(
                        children: [
                          _UserAvatar(
                            name: review.userName,
                            avatarUrl: review.userAvatarUrl,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        review.userName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ),
                                    if (review.reviewerIsProfessional) ...[
                                      const SizedBox(width: 5),
                                      const Icon(
                                        Icons.storefront_outlined,
                                        size: 13,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  widget.dateFormat.format(review.createdAt),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                RatingStars(
                  rating: review.rating.toDouble(),
                  showValue: false,
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Título y cuerpo ────────────────────────────────────────
            Text(
              review.title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(review.body),

            // ── Fotos de la reseña ─────────────────────────────────────
            if (review.photoUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              _ReviewPhotoRow(photoUrls: review.photoUrls),
            ],

            // ── Respuesta del profesional ──────────────────────────────
            if (review.ownerReply != null && review.ownerReply!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.storefront_outlined,
                          size: 16,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Respuesta del profesional',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const Spacer(),
                        if (widget.isOwnerView)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  _replyController.text = review.ownerReply!;
                                  setState(() => _showReplyField = true);
                                },
                                child: const Icon(
                                  Icons.edit_outlined,
                                  size: 16,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: _deleteReply,
                                child: const Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(review.ownerReply!),
                  ],
                ),
              ),
            ],

            // ── Botón + campo de respuesta (solo owner) ─────────────────
            if (widget.isOwnerView) ...[
              const SizedBox(height: 10),
              if (!_showReplyField && (review.ownerReply == null || review.ownerReply!.isEmpty))
                TextButton.icon(
                  onPressed: () => setState(() => _showReplyField = true),
                  icon: const Icon(Icons.reply_outlined, size: 18),
                  label: const Text('Responder'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              if (_showReplyField) ...[
                TextField(
                  controller: _replyController,
                  decoration: InputDecoration(
                    hintText: 'Escribe tu respuesta...',
                    isDense: true,
                    contentPadding: const EdgeInsets.all(10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.divider),
                    ),
                  ),
                  maxLines: 3,
                  autofocus: true,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => setState(() {
                        _showReplyField = false;
                        _replyController.clear();
                      }),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _isSavingReply ? null : _saveReply,
                      child: _isSavingReply
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Publicar respuesta'),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// FAB para escribir reseña (solo en vista pública ajena).
class ProfessionalWriteReviewFab extends ConsumerWidget {
  const ProfessionalWriteReviewFab({super.key, required this.companyId});

  final String companyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return PremiumFab(
      label: 'Escribir reseña',
      icon: Icons.rate_review,
      onPressed: () {
        if (user == null) {
          context.push(
            AppRoutes.loginWithRedirect(
              AppRoutes.writeReviewPath(companyId),
            ),
          );
          return;
        }
        context.push(AppRoutes.writeReviewPath(companyId));
      },
    );
  }
}

// ── Botón enviar mensaje ──────────────────────────────────────────────────────

class _SendMessageButton extends ConsumerWidget {
  const _SendMessageButton({
    required this.professionalId,
    required this.professionalName,
    this.professionalPhoto,
  });

  final String professionalId;
  final String professionalName;
  final String? professionalPhoto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          if (user == null) {
            context.push(AppRoutes.loginWithRedirect(
              AppRoutes.companyDetailPath(professionalId),
            ));
            return;
          }
          context.push(
            AppRoutes.chatPath(professionalId),
            extra: {
              'name': professionalName,
              'photo': professionalPhoto,
            },
          );
        },
        icon: const Icon(Icons.chat_bubble_outline_rounded),
        label: const Text('Enviar mensaje'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: AppTheme.primary),
          foregroundColor: AppTheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// ── Miniaturas de fotos en reseñas ────────────────────────────────────────────

class _ReviewPhotoThumb {
  _ReviewPhotoThumb._();

  static const size = 80.0;
}

class _ReviewPhotoRow extends StatelessWidget {
  const _ReviewPhotoRow({required this.photoUrls});

  final List<String> photoUrls;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheSize =
        (_ReviewPhotoThumb.size * dpr).ceil().clamp(80, 240);

    return SizedBox(
      height: _ReviewPhotoThumb.size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photoUrls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final url = photoUrls[i];
          final optimized = StorageImageUrl.thumbnail(
            url,
            width: cacheSize,
            height: cacheSize,
          );

          return GestureDetector(
            onTap: () => PhotoGalleryLightbox.show(
              context,
              photoUrls: photoUrls,
              initialIndex: i,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ResilientNetworkImage(
                originalUrl: url,
                optimizedUrl: optimized,
                width: _ReviewPhotoThumb.size,
                height: _ReviewPhotoThumb.size,
                fit: BoxFit.cover,
                memCacheWidth: cacheSize,
                fadeInDuration: Duration.zero,
                placeholder: Container(
                  width: _ReviewPhotoThumb.size,
                  height: _ReviewPhotoThumb.size,
                  color: AppTheme.surfaceElevated,
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: Container(
                  width: _ReviewPhotoThumb.size,
                  height: _ReviewPhotoThumb.size,
                  color: AppTheme.surfaceElevated,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Avatar del autor de la reseña ─────────────────────────────────────────────

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.name, this.avatarUrl});

  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      const diameter = 40.0;
      final cacheSize = (diameter * dpr).ceil().clamp(40, 120);
      final optimized = StorageImageUrl.thumbnail(
        avatarUrl!,
        width: cacheSize,
        height: cacheSize,
      );

      return CircleAvatar(
        backgroundColor: AppTheme.surfaceElevated,
        radius: 20,
        child: ClipOval(
          child: ResilientNetworkImage(
            originalUrl: avatarUrl!,
            optimizedUrl: optimized,
            width: diameter,
            height: diameter,
            fit: BoxFit.cover,
            memCacheWidth: cacheSize,
            fadeInDuration: Duration.zero,
            placeholder: SizedBox(
              width: diameter,
              height: diameter,
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            error: SizedBox(
              width: diameter,
              height: diameter,
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return CircleAvatar(
      backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
      radius: 20,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: AppTheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
