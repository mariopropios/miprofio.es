import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/services/auth_callback_service.dart';
import '../../../../core/services/email_confirm_sync.dart';
import '../../../../core/services/post_email_confirm_redirect.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/signup_finalize.dart';
import '../../providers/pending_email_verification_provider.dart';

/// Destino del enlace de confirmación de email (`token_hash` + `type`).
class AuthConfirmScreen extends ConsumerStatefulWidget {
  const AuthConfirmScreen({super.key});

  @override
  ConsumerState<AuthConfirmScreen> createState() => _AuthConfirmScreenState();
}

class _AuthConfirmScreenState extends ConsumerState<AuthConfirmScreen> {
  bool _busy = true;
  String? _error;
  String _statusMessage = 'Confirmando tu email…';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _confirm());
  }

  Future<void> _goAfterConfirm() async {
    // Esperar a que Riverpod vea la sesión tras verifyOTP.
    await Future<void>.delayed(const Duration(milliseconds: 80));
    ref.invalidate(currentUserProvider);

    // Refrescar user para tener user_metadata / email_confirmed.
    try {
      await Supabase.instance.client.auth.getUser();
    } catch (_) {}

    final sessionUser = Supabase.instance.client.auth.currentUser;
    final userId = sessionUser?.id ?? ref.read(currentUserProvider)?.id;
    final accountEmail =
        sessionUser?.email ?? ref.read(currentUserProvider)?.email ?? '';

    final metaRole = sessionUser?.userMetadata?['role']?.toString();
    final expectsProfessional = metaRole == 'professional' ||
        sessionUser?.userMetadata?['pending_professional'] != null;

    var publishedDraft = false;

    if (userId != null) {
      if (mounted) {
        setState(() {
          _statusMessage = expectsProfessional
              ? 'Publicando tu perfil profesional…'
              : 'Preparando tu cuenta…';
        });
      }
      try {
        publishedDraft = await finalizePendingSignupDraft(
          ref: ref,
          userId: userId,
          accountEmail: accountEmail,
        );
      } catch (e) {
        debugPrint('finalizePendingSignupDraft: $e');
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error =
              'Email confirmado, pero no pudimos publicar tu ficha. '
              'Pulsa reintentar o entra con tu cuenta. ($e)';
        });
        return;
      }
    }

    ref.invalidate(currentProfileProvider);
    ref.invalidate(currentProfessionalProfileProvider);
    ref.invalidate(currentUserProfessionalViewProvider);

    // Profesional: no mandar a perfil vacío si no hay ficha.
    if (userId != null && expectsProfessional) {
      final listing = await ref
          .read(professionalRepositoryProvider)
          .getProfessionalForUser(userId);
      if (listing == null && !publishedDraft) {
        // Reintento único por si el draft llegó un momento después.
        try {
          publishedDraft = await finalizePendingSignupDraft(
            ref: ref,
            userId: userId,
            accountEmail: accountEmail,
          );
        } catch (_) {}
        final listing2 = await ref
            .read(professionalRepositoryProvider)
            .getProfessionalForUser(userId);
        if (listing2 == null) {
          if (!mounted) return;
          setState(() {
            _busy = false;
            _error =
                'Email confirmado, pero tu ficha profesional no se publicó. '
                'Pulsa «Reintentar publicación» o completa el registro una vez.';
          });
          return;
        }
        publishedDraft = true;
      }
    }

    ref.invalidate(currentProfileProvider);
    ref.invalidate(currentProfessionalProfileProvider);
    ref.invalidate(currentUserProfessionalViewProvider);

    final next = AuthCallbackService.allParameters(Uri.base)['next'];
    var dest = await PostEmailConfirmRedirect.resolve(nextFromUrl: next);

    if (publishedDraft ||
        expectsProfessional ||
        dest.contains(AppRoutes.professionalRegister) ||
        Uri.parse(dest).path == AppRoutes.profile ||
        dest == AppRoutes.home) {
      dest = AppRoutes.profileAfterEmailVerification();
    }

    EmailConfirmSync.notifyConfirmed(
      userId: userId,
      dest: dest,
    );

    if (!mounted) return;
    context.go(dest);
  }

  Future<void> _confirm() async {
    final uri = Uri.base;
    final hasCallback = AuthCallbackService.isAuthCallback(uri) ||
        AuthCallbackService.recoveryTokenHash(uri) != null;

    if (!hasCallback) {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null && mounted) {
        await _goAfterConfirm();
        return;
      }
      if (mounted) {
        setState(() {
          _busy = false;
          _error =
              'Este enlace no es válido o ya se usó. Pide un nuevo email de confirmación.';
        });
      }
      return;
    }

    try {
      final ok = await ref
          .read(authRepositoryProvider)
          .completeAuthCallbackFromUrl(uri);
      if (!mounted) return;

      if (ok && Supabase.instance.client.auth.currentSession != null) {
        ref.read(pendingEmailVerificationProvider.notifier).clear();
        ref.invalidate(currentUserProvider);
        ref.invalidate(currentProfileProvider);
        await _goAfterConfirm();
        return;
      }

      setState(() {
        _busy = false;
        _error =
            'No se pudo confirmar el email. El enlace puede haber caducado.';
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error =
            'No se pudo confirmar el email. Prueba de nuevo o solicita otro enlace.';
      });
    }
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
              padding: const EdgeInsets.all(24),
              child: _busy
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: AppTheme.primary),
                        const SizedBox(height: 20),
                        Text(
                          _statusMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No cierres esta pantalla.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 48,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _error ?? 'No se pudo confirmar el email.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: () {
                            setState(() {
                              _busy = true;
                              _error = null;
                              _statusMessage = 'Reintentando…';
                            });
                            _goAfterConfirm();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                          ),
                          child: const Text('Reintentar publicación'),
                        ),
                        TextButton(
                          onPressed: () =>
                              context.go(AppRoutes.professionalRegister),
                          child: const Text('Completar registro manualmente'),
                        ),
                        TextButton(
                          onPressed: () => context.go(AppRoutes.login),
                          child: const Text('Ir a iniciar sesión'),
                        ),
                        TextButton(
                          onPressed: () => context.go(AppRoutes.home),
                          child: const Text('Volver al inicio'),
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
