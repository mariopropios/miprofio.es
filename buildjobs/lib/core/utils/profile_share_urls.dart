import 'package:flutter/foundation.dart';

import '../constants/seo_constants.dart';
import '../router/routes.dart';

/// Intención al compartir una ficha.
enum ProfileShareIntent {
  /// Mensaje orientado a pedir reseña (enlace a escribir valoración).
  askReview,

  /// Mensaje neutro para difundir la ficha pública.
  shareProfile,
}

/// URL y textos de share de una ficha profesional.
abstract final class ProfileShareUrls {
  ProfileShareUrls._();

  /// En web usa el origen actual (workers.dev o miprofio.es).
  static String originBase() {
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty && origin != 'null') return origin;
    }
    return SeoConstants.siteUrl;
  }

  static String forProfessional(
    String professionalId, {
    ProfileShareIntent intent = ProfileShareIntent.shareProfile,
  }) {
    final path = intent == ProfileShareIntent.askReview
        ? AppRoutes.writeReviewPath(professionalId)
        : AppRoutes.companyDetailPath(professionalId);
    return '${originBase()}$path';
  }

  /// Mensaje completo **con una sola URL** al final (WhatsApp / portapapeles).
  static String shareMessage({
    required String url,
    String? professionalName,
    ProfileShareIntent intent = ProfileShareIntent.shareProfile,
  }) {
    final name = professionalName?.trim();
    final label = (name != null && name.isNotEmpty) ? name : 'mi trabajo';

    switch (intent) {
      case ProfileShareIntent.askReview:
        return '¿He trabajado para ti? ⭐ '
            'Déjame una reseña en miProfio.es (1 minuto). '
            'Tu valoración me ayuda a subir en el ranking y a que más vecinos '
            'confíen en $label:\n$url';
      case ProfileShareIntent.shareProfile:
        if (name != null && name.isNotEmpty) {
          return 'Te paso el perfil de $name en miProfio.es '
              '(reseñas y contacto):\n$url';
        }
        return 'Te paso este perfil en miProfio.es '
            '(reseñas y contacto):\n$url';
    }
  }

  static String shareTitle({
    String? professionalName,
    ProfileShareIntent intent = ProfileShareIntent.shareProfile,
  }) {
    final name = professionalName?.trim();
    if (intent == ProfileShareIntent.askReview) {
      return name != null && name.isNotEmpty
          ? 'Valora a $name en miProfio.es'
          : 'Valora mi trabajo en miProfio.es';
    }
    return name != null && name.isNotEmpty
        ? '$name · miProfio.es'
        : 'miProfio.es';
  }
}
