import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/services/auth_callback_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/device_form_factor.dart';
import '../../../../shared/widgets/premium_button.dart';

/// Pantalla tras abrir el enlace de recuperación de Supabase.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.redirectTo});

  final String? redirectTo;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  bool _verifyingLink = true;
  String? _verifyError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureRecoverySession());
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _ensureRecoverySession() async {
    if (ref.read(currentUserProvider) != null) {
      if (mounted) setState(() => _verifyingLink = false);
      return;
    }

    final uri = Uri.base;
    final hasRecoveryParams = AuthCallbackService.recoveryTokenHash(uri) !=
            null ||
        AuthCallbackService.isPasswordRecoveryCallback(uri) ||
        AuthCallbackService.isAuthCallback(uri);

    if (!hasRecoveryParams) {
      if (mounted) {
        setState(() {
          _verifyingLink = false;
          _verifyError = 'missing_params';
        });
      }
      return;
    }

    try {
      final ok = await ref
          .read(authRepositoryProvider)
          .completePasswordRecoveryFromUrl(uri);
      if (!ok && mounted) {
        setState(() => _verifyError = 'invalid');
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _verifyError = e.message);
    } catch (_) {
      if (mounted) setState(() => _verifyError = 'invalid');
    } finally {
      if (mounted) setState(() => _verifyingLink = false);
    }
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await ref.read(authRepositoryProvider).updatePassword(
            _passwordController.text,
          );

      ref.invalidate(currentUserProvider);
      ref.invalidate(currentProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contraseña actualizada correctamente.'),
          ),
        );

        final redirect = widget.redirectTo;
        context.go(
          redirect != null && redirect.isNotEmpty
              ? redirect
              : AppRoutes.profile,
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = !DeviceFormFactor.isDesktopWeb(context);
    final cardWidth = isCompact ? MediaQuery.sizeOf(context).width : 480.0;
    final hasSession = ref.watch(currentUserProvider) != null;

    if (_verifyingLink) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppTheme.primary),
              const SizedBox(height: 20),
              Text(
                'Verificando enlace…',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    if (!hasSession) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.go(AppRoutes.login),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: cardWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.link_off_rounded,
                      size: 56, color: AppTheme.textSecondary),
                  const SizedBox(height: 20),
                  Text(
                    'Enlace no válido o caducado',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _verifyError != null && _verifyError != 'missing_params'
                        ? _verifyError!
                        : 'El enlace ha expirado, ya se usó o se abrió en '
                            'otro navegador. Solicita uno nuevo y ábrelo en '
                            'Safari o Chrome (no en el visor del email).',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                          height: 1.45,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  PremiumButton(
                    label: 'Solicitar nuevo enlace',
                    onPressed: () => context.go(AppRoutes.forgotPassword),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go(AppRoutes.login),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 24 : 32,
            vertical: 24,
          ),
          child: SizedBox(
            width: cardWidth,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.password_rounded,
                      size: 56, color: AppTheme.primary),
                  const SizedBox(height: 20),
                  Text(
                    'Nueva contraseña',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Elige una contraseña segura de al menos 6 caracteres.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nueva contraseña',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) =>
                        v == null || v.length < 6 ? 'Mínimo 6 caracteres' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar contraseña',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) {
                      if (v == null || v.length < 6) {
                        return 'Mínimo 6 caracteres';
                      }
                      if (v != _passwordController.text) {
                        return 'Las contraseñas no coinciden';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) {
                      if (!_isLoading) _updatePassword();
                    },
                  ),
                  const SizedBox(height: 28),
                  PremiumButton(
                    label: 'Guardar contraseña',
                    isLoading: _isLoading,
                    onPressed: _isLoading ? null : _updatePassword,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
