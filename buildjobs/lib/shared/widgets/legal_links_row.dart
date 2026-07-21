import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';

/// Fila compacta de enlaces legales (login, perfil, footer).
class LegalLinksRow extends StatelessWidget {
  const LegalLinksRow({
    super.key,
    this.dense = false,
    this.alignment = WrapAlignment.center,
  });

  final bool dense;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: AppTheme.textSecondary.withValues(alpha: 0.9),
      fontSize: dense ? 11.5 : 12.5,
      fontWeight: FontWeight.w500,
    );

    Widget link(String label, String route) {
      return InkWell(
        onTap: () => context.push(route),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(label, style: style),
        ),
      );
    }

    return Wrap(
      alignment: alignment,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 2,
      runSpacing: 2,
      children: [
        link('Acerca de', AppRoutes.about),
        _dot(style),
        link('Privacidad', AppRoutes.privacy),
        _dot(style),
        link('Cookies', AppRoutes.cookies),
        _dot(style),
        link('Términos', AppRoutes.terms),
        _dot(style),
        link('Aviso legal', AppRoutes.legalNotice),
      ],
    );
  }

  Widget _dot(TextStyle style) => Text('·', style: style);
}
