import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/repository_providers.dart';
import '../models/company.dart';
import 'company_card.dart';
import 'save_professional_button.dart';

/// Tarjeta de profesional con botón de guardar en la foto.
class SavableCompanyCard extends ConsumerWidget {
  const SavableCompanyCard({
    super.key,
    required this.company,
    this.onTap,
  });

  final Company company;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final viewAsync = ref.watch(currentUserProfessionalViewProvider);

    final isOwnListing = viewAsync.maybeWhen(
      data: (view) =>
          view.isProfessional &&
          view.hasListing &&
          view.professionalId == company.id,
      orElse: () => false,
    );

    return CompanyCard(
      company: company,
      onTap: onTap,
      photoOverlay: user != null && !isOwnListing
          ? SaveProfessionalButton(
              professionalId: company.id,
              compact: true,
            )
          : null,
    );
  }
}
