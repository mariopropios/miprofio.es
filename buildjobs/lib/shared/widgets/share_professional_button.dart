import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/profile_share.dart';
import '../../core/utils/profile_share_urls.dart';

/// Botón / icono para compartir el enlace de una ficha profesional.
class ShareProfessionalButton extends StatelessWidget {
  const ShareProfessionalButton({
    super.key,
    required this.professionalId,
    this.professionalName,
    this.asIconButton = true,
    /// Si true (dueño), ofrece elegir «Pedir reseña» o «Compartir perfil».
    this.offerOwnerPresets = false,
  });

  final String professionalId;
  final String? professionalName;
  final bool asIconButton;
  final bool offerOwnerPresets;

  Future<void> _share(
    BuildContext context, {
    required ProfileShareIntent intent,
  }) async {
    final url = ProfileShareUrls.forProfessional(
      professionalId,
      intent: intent,
    );
    final text = ProfileShareUrls.shareMessage(
      url: url,
      professionalName: professionalName,
      intent: intent,
    );
    final title = ProfileShareUrls.shareTitle(
      professionalName: professionalName,
      intent: intent,
    );

    final outcome = await shareProfileLink(
      url: url,
      text: text,
      title: title,
    );
    if (!context.mounted) return;

    switch (outcome) {
      case ProfileShareOutcome.shared:
      case ProfileShareOutcome.openedWhatsApp:
      case ProfileShareOutcome.cancelled:
        break;
      case ProfileShareOutcome.copied:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              intent == ProfileShareIntent.askReview
                  ? 'Mensaje copiado. Pégalo en WhatsApp o SMS.'
                  : 'Enlace copiado',
            ),
          ),
        );
      case ProfileShareOutcome.failed:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo compartir el enlace')),
        );
    }
  }

  Future<void> _onPressed(BuildContext context) async {
    if (!offerOwnerPresets) {
      await _share(context, intent: ProfileShareIntent.shareProfile);
      return;
    }

    final intent = await showModalBottomSheet<ProfileShareIntent>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  '¿Qué quieres compartir?',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.star_outline, color: AppTheme.primary),
                title: const Text(
                  'Pedir reseña a un cliente',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Mensaje listo para WhatsApp: valora mi trabajo',
                ),
                onTap: () =>
                    Navigator.of(ctx).pop(ProfileShareIntent.askReview),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline,
                    color: AppTheme.textSecondary),
                title: const Text(
                  'Compartir mi perfil',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Enlace a tu ficha pública',
                ),
                onTap: () =>
                    Navigator.of(ctx).pop(ProfileShareIntent.shareProfile),
              ),
            ],
          ),
        ),
      ),
    );

    if (intent == null || !context.mounted) return;
    await _share(context, intent: intent);
  }

  @override
  Widget build(BuildContext context) {
    if (asIconButton) {
      return IconButton(
        tooltip: offerOwnerPresets ? 'Compartir / pedir reseña' : 'Compartir perfil',
        icon: const Icon(Icons.ios_share_outlined),
        onPressed: () => _onPressed(context),
      );
    }

    return TextButton.icon(
      onPressed: () => _onPressed(context),
      icon: const Icon(Icons.ios_share_outlined, size: 18),
      label: Text(offerOwnerPresets ? 'Compartir' : 'Compartir'),
      style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
    );
  }
}
