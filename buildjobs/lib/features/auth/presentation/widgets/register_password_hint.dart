import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Aviso bajo el campo de contraseña al registrarse.
class RegisterPasswordHint extends StatelessWidget {
  const RegisterPasswordHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.shield_outlined,
            size: 16,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Usa una contraseña nueva que no uses en otros sitios. '
              'Si Chrome te avisa de una filtración, es porque esa contraseña '
              'ya se filtró en otro servicio, no en Profio.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
