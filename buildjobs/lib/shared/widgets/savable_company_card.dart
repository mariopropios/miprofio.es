import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/repository_providers.dart';
import '../../features/saved/providers/saved_professional_providers.dart';
import '../models/company.dart';
import 'company_card.dart';
import 'save_professional_button.dart';

/// Tarjeta de profesional con botón de guardar en la foto.
class SavableCompanyCard extends ConsumerWidget {
  const SavableCompanyCard({
    super.key,
    required this.company,
    this.onTap,
    this.highlightProfession,
  });

  final Company company;
  final VoidCallback? onTap;
  /// Oficio activo en el filtro de búsqueda para reordenar/resaltar tags.
  final String? highlightProfession;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final viewAsync = ref.watch(currentUserProfessionalViewProvider);

    final isProfessional = viewAsync.maybeWhen(
      data: (view) => view.isProfessional,
      orElse: () => false,
    );

    final isOwnListing = viewAsync.maybeWhen(
      data: (view) =>
          view.isProfessional &&
          view.hasListing &&
          view.professionalId == company.id,
      orElse: () => false,
    );

    // Aplica el delta optimista al contador de likes
    final deltas = ref.watch(savedCountDeltaProvider);
    final delta = deltas[company.id] ?? 0;
    final effectiveSavedCount = (company.savedCount + delta).clamp(0, 999999);

    // Los profesionales no ven el botón de like en las tarjetas
    final showSaveButton = user != null && !isOwnListing && !isProfessional;

    return CompanyCard(
      company: company,
      onTap: onTap,
      savedCountOverride: effectiveSavedCount,
      highlightProfession: highlightProfession,
      photoOverlay: showSaveButton
          ? SaveProfessionalButton(
              professionalId: company.id,
              compact: true,
            )
          : null,
    );
  }
}
