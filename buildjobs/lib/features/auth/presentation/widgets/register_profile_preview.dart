import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/phone_validation_utils.dart';
import '../../../../core/utils/x_file_preview_image.dart';
import '../../../../shared/widgets/spring_pressable.dart';

/// Vista previa en vivo del perfil que se va construyendo (reduce ansiedad del wizard).
class RegisterProfilePreview extends StatelessWidget {
  const RegisterProfilePreview({
    super.key,
    required this.businessName,
    required this.city,
    required this.phone,
    required this.professions,
    required this.bio,
    required this.galleryImages,
    required this.activeSection,
    this.profileAvatar,
    this.accountReady = false,
    this.expanded = true,
    this.onToggleExpanded,
  });

  final String businessName;
  final String city;
  final String phone;
  final Set<String> professions;
  final String bio;
  final List<XFile> galleryImages;
  final XFile? profileAvatar;
  /// Sección activa del checklist: 0 contacto, 1 especialidades, 2 descripción, 3 fotos, 4 cuenta.
  final int activeSection;
  final bool accountReady;
  final bool expanded;
  final VoidCallback? onToggleExpanded;

  static const totalSections = 5;

  bool get _hasName => businessName.trim().length >= 2;
  bool get _hasPhone => PhoneValidationUtils.digitsOnly(phone).length >= 6;
  bool get _hasCity => city.trim().length >= 2;
  bool get _hasProfessions => professions.isNotEmpty;
  bool get _hasBio => bio.trim().length >= 20;
  bool get _hasGallery => galleryImages.isNotEmpty;

  int get _completedSections {
    var n = 0;
    if (_hasName && _hasPhone && _hasCity) n++;
    if (_hasProfessions) n++;
    if (_hasBio) n++;
    if (_hasGallery) n++;
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final displayName =
        _hasName ? businessName.trim() : 'Tu nombre comercial';
    final displayCity = _hasCity ? city.trim() : 'Tu ciudad';
    final displayPhone = _hasPhone ? phone.trim() : null;

    return AnimatedContainer(
      duration: AppTheme.hoverDuration,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.divider),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SpringPressable(
            onTap: onToggleExpanded,
            pressedScale: 0.995,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Icon(
                    Icons.visibility_outlined,
                    size: 18,
                    color: AppTheme.primary.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Vista previa de tu perfil',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '$_completedSections de $totalSections secciones · ~3 min',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onToggleExpanded != null)
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: AppTheme.hoverDuration,
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstCurve: Curves.easeOutCubic,
            secondCurve: Curves.easeInCubic,
            sizeCurve: Curves.easeOutCubic,
            crossFadeState: expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: AppTheme.hoverDuration,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PreviewAvatar(
                        image: profileAvatar ??
                            (galleryImages.isNotEmpty
                                ? galleryImages.first
                                : null),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: TextStyle(
                                color: _hasName
                                    ? AppTheme.textPrimary
                                    : AppTheme.textSecondary,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 14,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    displayCity,
                                    style: TextStyle(
                                      color: _hasCity
                                          ? AppTheme.textSecondary
                                          : AppTheme.textSecondary
                                              .withValues(alpha: 0.6),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (displayPhone != null) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.phone_outlined,
                                    size: 14,
                                    color: AppTheme.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    displayPhone,
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (professions.isEmpty)
                    const _PlaceholderChip(label: 'Tus especialidades')
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: professions.map((p) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Text(
                            p,
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  if (bio.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      bio.trim(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _hasBio
                            ? AppTheme.textSecondary
                            : AppTheme.textSecondary.withValues(alpha: 0.7),
                        fontSize: 13,
                        height: 1.4,
                        fontStyle: _hasBio ? FontStyle.normal : FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _ChecklistRow(
                    label: 'Contacto',
                    done: _hasName && _hasPhone && _hasCity,
                    active: activeSection == 0,
                  ),
                  _ChecklistRow(
                    label: 'Especialidades',
                    done: _hasProfessions,
                    active: activeSection == 1,
                  ),
                  _ChecklistRow(
                    label: 'Descripción',
                    done: _hasBio,
                    active: activeSection == 2,
                  ),
                  _ChecklistRow(
                    label: 'Fotos (opcional)',
                    done: _hasGallery,
                    active: activeSection == 3,
                  ),
                  _ChecklistRow(
                    label: 'Cuenta de acceso',
                    done: accountReady,
                    active: activeSection == 4,
                  ),
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _PreviewAvatar extends StatelessWidget {
  const _PreviewAvatar({this.image});

  final XFile? image;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: image == null
          ? const Icon(Icons.person_outline, color: AppTheme.textSecondary)
          : XFilePreviewImage(
              file: image!,
              width: 56,
              height: 56,
              borderRadius: 14,
            ),
    );
  }
}

class _PlaceholderChip extends StatelessWidget {
  const _PlaceholderChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.divider,
          style: BorderStyle.solid,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppTheme.textSecondary.withValues(alpha: 0.8),
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.label,
    required this.done,
    required this.active,
  });

  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(
            done
                ? Icons.check_circle_rounded
                : active
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
            size: 16,
            color: done
                ? AppTheme.primary
                : active
                    ? AppTheme.primary.withValues(alpha: 0.8)
                    : AppTheme.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: done ? AppTheme.textPrimary : AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra de ayuda cuando faltan datos para continuar.
class RegisterValidationHint extends StatelessWidget {
  const RegisterValidationHint({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF262E36),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppTheme.primary.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
