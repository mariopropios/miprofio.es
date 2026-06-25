import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Indicador de progreso estilo iOS (puntos + barra).
class RegisterStepIndicator extends StatelessWidget {
  const RegisterStepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.labels = const [],
  });

  final int currentStep;
  final int totalSteps;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final progress = totalSteps <= 1 ? 1.0 : currentStep / (totalSteps - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(totalSteps, (index) {
            final active = index <= currentStep;
            return Expanded(
              child: AnimatedContainer(
                duration: AppTheme.hoverDuration,
                curve: Curves.easeOutCubic,
                height: 4,
                margin: EdgeInsets.only(right: index < totalSteps - 1 ? 6 : 0),
                decoration: BoxDecoration(
                  color: active
                      ? AppTheme.primary
                      : AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        if (labels.isNotEmpty && currentStep < labels.length) ...[
          const SizedBox(height: 10),
          Text(
            'Paso ${currentStep + 1} de $totalSteps · ${labels[currentStep]}',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ] else ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: AppTheme.divider,
              color: AppTheme.primary,
            ),
          ),
        ],
      ],
    );
  }
}
