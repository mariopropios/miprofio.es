import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/email_typo_helper.dart';
import '../../providers/pending_email_verification_provider.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  static const _resendCooldown = 60;

  late final TextEditingController _emailController;
  late final FocusNode _emailFocusNode;

  int _secondsLeft = _resendCooldown;
  bool _sending = false;
  String? _sendError;
  String? _typoSuggestion;
  Timer? _timer;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email);
    _emailFocusNode = FocusNode();
    _emailController.addListener(_onEmailChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = ref.read(pendingEmailVerificationProvider);
      if (pending != null && pending.email.isNotEmpty) {
        _emailController.text = pending.email;
        _onEmailChanged();
      }
    });
    _startCountdown();
    _listenForVerification();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _authSub?.cancel();
    _emailController.removeListener(_onEmailChanged);
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  void _onEmailChanged() {
    final suggestion = EmailTypoHelper.suggestFix(_emailController.text);
    if (suggestion != _typoSuggestion) {
      setState(() => _typoSuggestion = suggestion);
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendCooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) t.cancel();
      });
    });
  }

  void _listenForVerification() {
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (!mounted) return;
      if (state.event == AuthChangeEvent.signedIn &&
          state.session != null) {
        ref.read(pendingEmailVerificationProvider.notifier).clear();
        ref.invalidate(currentUserProvider);
        if (mounted) context.go(AppRoutes.profileAfterEmailVerification());
      }
    });
  }

  Future<void> _sendVerification() async {
    if (_sending) return;

    final newEmail = _emailController.text.trim();
    if (!EmailTypoHelper.isValidFormat(newEmail)) {
      setState(() => _sendError = 'Escribe un email válido.');
      _emailFocusNode.requestFocus();
      return;
    }

    final pending = ref.read(pendingEmailVerificationProvider);
    final previousEmail = pending?.email ?? widget.email;

    setState(() {
      _sending = true;
      _sendError = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);

      if (pending != null &&
          newEmail.toLowerCase() != previousEmail.toLowerCase()) {
        await authRepo.correctUnconfirmedEmail(
          userId: pending.userId,
          oldEmail: previousEmail,
          newEmail: newEmail,
        );
        ref.read(pendingEmailVerificationProvider.notifier).updateEmail(newEmail);
        if (mounted) {
          context.go(AppRoutes.emailVerificationPath(newEmail));
        }
      }

      await authRepo.resendVerificationEmail(newEmail);

      if (mounted) {
        _startCountdown();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newEmail.toLowerCase() == previousEmail.toLowerCase()
                  ? 'Email de verificación reenviado.'
                  : 'Email actualizado y enlace reenviado a $newEmail.',
            ),
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _sendError = e.message);
        _emailFocusNode.requestFocus();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _sendError =
              'No se pudo enviar el email. Revisa la dirección e inténtalo de nuevo.',
        );
        _emailFocusNode.requestFocus();
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _applyTypoSuggestion() {
    final suggestion = _typoSuggestion;
    if (suggestion == null) return;
    _emailController.text = suggestion;
    _emailController.selection = TextSelection.collapsed(
      offset: suggestion.length,
    );
    setState(() => _typoSuggestion = null);
  }

  @override
  Widget build(BuildContext context) {
    final canSendNow = !_sending && (_secondsLeft <= 0 || _sendError != null);
    final showCooldown = _secondsLeft > 0 && _sendError == null && !_sending;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBackground,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(pendingEmailVerificationProvider.notifier).clear();
            context.go(AppRoutes.login);
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mark_email_unread_outlined,
                      size: 40,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Verifica tu email',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Te hemos enviado un enlace de verificación. Si no te llega, '
                    'revisa que el email esté bien escrito y corrígelo aquí:',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                          height: 1.45,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _emailController,
                    focusNode: _emailFocusNode,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Tu email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      filled: true,
                      fillColor: const Color(0xFF1E252B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppTheme.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  if (_typoSuggestion != null) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _applyTypoSuggestion,
                        icon: const Icon(Icons.auto_fix_high, size: 18),
                        label: Text('¿Quisiste decir $_typoSuggestion?'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Haz clic en el enlace del email para activar tu cuenta. '
                    'Te llevaremos a tu perfil con la sesión iniciada.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Esperando verificación…',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 32),
                  if (_sendError != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        _sendError!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13.5,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: canSendNow ? _sendVerification : null,
                      icon: _sending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        showCooldown
                            ? 'Enviar enlace en ${_secondsLeft}s'
                            : _sending
                                ? 'Enviando…'
                                : 'Enviar enlace a este email',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      ref.read(pendingEmailVerificationProvider.notifier).clear();
                      context.go(AppRoutes.login);
                    },
                    child: const Text(
                      'Ir a inicio de sesión',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
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
