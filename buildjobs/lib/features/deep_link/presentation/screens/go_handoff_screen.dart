import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/tab_coordinator.dart';
import '../../../../core/theme/app_theme.dart';

/// Deep link de email: reutiliza otra pestaña viva o navega aquí.
class GoHandoffScreen extends ConsumerStatefulWidget {
  const GoHandoffScreen({super.key, required this.target});

  final String target;

  @override
  ConsumerState<GoHandoffScreen> createState() => _GoHandoffScreenState();
}

class _GoHandoffScreenState extends ConsumerState<GoHandoffScreen> {
  bool _busy = true;
  bool _handedOff = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final target = widget.target.trim();
    if (target.isEmpty || !target.startsWith('/')) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Enlace no válido.';
      });
      return;
    }

    if (target == '/go' || target.startsWith('/go?')) {
      if (!mounted) return;
      context.go('/');
      return;
    }

    try {
      final handed = await TabCoordinator.tryHandoff(target);
      if (!mounted) return;
      if (handed) {
        setState(() {
          _busy = false;
          _handedOff = true;
        });
        await Future<void>.delayed(const Duration(milliseconds: 150));
        TabCoordinator.closeWindowIfPossible();
        return;
      }
    } catch (e) {
      debugPrint('GoHandoff tryHandoff: $e');
    }

    if (!mounted) return;
    context.go(target);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_busy) ...[
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Abriendo…',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ] else if (_handedOff) ...[
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppTheme.primary,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Abierto en tu otra pestaña de miProfio',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Puedes cerrar esta ventana. Así no se acumulan pestañas '
                      'al abrir notificaciones del correo.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                            height: 1.45,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: TabCoordinator.closeWindowIfPossible,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                      ),
                      child: const Text('Cerrar esta pestaña'),
                    ),
                    TextButton(
                      onPressed: () => context.go(widget.target),
                      child: const Text(
                        'Abrir aquí igualmente',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  ] else if (_error != null) ...[
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.go('/'),
                      child: const Text('Ir al inicio'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
