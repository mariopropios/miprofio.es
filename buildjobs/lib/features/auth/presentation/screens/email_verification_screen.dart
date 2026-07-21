import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/services/email_confirm_sync.dart';
import '../../../../core/services/post_email_confirm_redirect.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/email_typo_helper.dart';
import '../../data/signup_finalize.dart';
import '../../providers/pending_email_verification_provider.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen>
    with WidgetsBindingObserver {
  static const _resendCooldown = 60;
  static const _maxFailedAttempts = 3;
  /// Supabase puede estar en 6 u 8 según config remota; aceptamos ambos.
  static const _otpMinLength = 6;
  static const _otpMaxLength = 8;

  late final TextEditingController _emailController;
  late final TextEditingController _codeController;
  late final FocusNode _emailFocusNode;
  late final FocusNode _codeFocusNode;

  int _secondsLeft = _resendCooldown;
  int _failedAttempts = 0;
  bool _sending = false;
  bool _verifying = false;
  bool _navigatingAway = false;
  bool _showChangeEmail = false;
  String? _sendError;
  String? _verifyError;
  String? _typoSuggestion;
  String _statusLabel = 'Revisa tu bandeja de entrada';
  Timer? _timer;
  Timer? _pollTimer;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _emailController = TextEditingController(text: widget.email);
    _codeController = TextEditingController();
    _emailFocusNode = FocusNode();
    _codeFocusNode = FocusNode();
    _emailController.addListener(_onEmailChanged);
    _codeController.addListener(() {
      if (_verifyError != null && mounted) {
        setState(() => _verifyError = null);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = ref.read(pendingEmailVerificationProvider);
      if (pending != null && pending.email.isNotEmpty) {
        _emailController.text = pending.email;
        _onEmailChanged();
      }
      _codeFocusNode.requestFocus();
      _checkIfAlreadyConfirmed();
    });
    _startCountdown();
    _listenForVerification();
    _listenCrossTab();
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _pollTimer?.cancel();
    _authSub?.cancel();
    EmailConfirmSync.stopListening();
    _emailController.removeListener(_onEmailChanged);
    _emailController.dispose();
    _codeController.dispose();
    _emailFocusNode.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkIfAlreadyConfirmed();
    }
  }

  String get _currentEmail {
    final pending = ref.read(pendingEmailVerificationProvider);
    final fromField = _emailController.text.trim();
    if (fromField.isNotEmpty) return fromField;
    return pending?.email ?? widget.email;
  }

  bool get _lockedByFailedAttempts => _failedAttempts >= _maxFailedAttempts;

  bool get _canVerify {
    if (_navigatingAway || _verifying || _sending || _lockedByFailedAttempts) {
      return false;
    }
    return _codeController.text.trim().length >= _otpMinLength;
  }

  bool get _canResend {
    if (_navigatingAway || _sending || _verifying) return false;
    if (_lockedByFailedAttempts) return true;
    return _secondsLeft <= 0 || _sendError != null;
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

  void _startPolling() {
    _pollTimer?.cancel();
    // Fallback si el usuario usa el enlace de respaldo en otra pestaña.
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _checkIfAlreadyConfirmed();
    });
  }

  void _listenCrossTab() {
    EmailConfirmSync.listen((signal) {
      if (!mounted || _navigatingAway) return;
      _completeAfterConfirm(preferredDest: signal.dest);
    });
  }

  void _listenForVerification() {
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (!mounted || _navigatingAway) return;
      switch (state.event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
        case AuthChangeEvent.userUpdated:
        case AuthChangeEvent.initialSession:
          if (state.session != null) {
            _completeAfterConfirm();
          }
        default:
          break;
      }
    });
  }

  Future<void> _checkIfAlreadyConfirmed() async {
    if (!mounted || _navigatingAway) return;

    final latest = EmailConfirmSync.readLatest();
    if (latest != null &&
        DateTime.now().millisecondsSinceEpoch - latest.atMs < 15 * 60 * 1000) {
      await _completeAfterConfirm(preferredDest: latest.dest);
      return;
    }

    try {
      await Supabase.instance.client.auth.refreshSession();
    } catch (_) {}

    try {
      final res = await Supabase.instance.client.auth.getUser();
      final user = res.user;
      if (user == null) return;
      final confirmedAt = user.emailConfirmedAt;
      final confirmed =
          confirmedAt != null && confirmedAt.toString().trim().isNotEmpty;
      if (confirmed || Supabase.instance.client.auth.currentSession != null) {
        await _completeAfterConfirm();
      }
    } catch (e) {
      debugPrint('checkIfAlreadyConfirmed: $e');
    }
  }

  Future<void> _completeAfterConfirm({String? preferredDest}) async {
    if (!mounted || _navigatingAway) return;
    _navigatingAway = true;
    _pollTimer?.cancel();
    _timer?.cancel();

    if (mounted) {
      setState(() => _statusLabel = '¡Email confirmado! Publicando tu perfil…');
    }

    ref.read(pendingEmailVerificationProvider.notifier).clear();
    ref.invalidate(currentUserProvider);
    ref.invalidate(currentProfileProvider);
    ref.invalidate(currentProfessionalProfileProvider);
    ref.invalidate(currentUserProfessionalViewProvider);

    final sessionUser = Supabase.instance.client.auth.currentUser;
    final userId = sessionUser?.id;
    if (userId != null) {
      try {
        await finalizePendingSignupDraft(
          ref: ref,
          userId: userId,
          accountEmail: sessionUser?.email ?? '',
        );
      } catch (e) {
        debugPrint('finalize on wait screen: $e');
      }
    }

    ref.invalidate(currentProfileProvider);
    ref.invalidate(currentProfessionalProfileProvider);
    ref.invalidate(currentUserProfessionalViewProvider);

    var dest = preferredDest;
    if (dest == null || dest.isEmpty) {
      dest = await PostEmailConfirmRedirect.resolve();
    }
    if (dest.contains(AppRoutes.professionalRegister) ||
        dest == AppRoutes.home ||
        Uri.parse(dest).path == AppRoutes.profile) {
      dest = AppRoutes.profileAfterEmailVerification();
    }

    EmailConfirmSync.clear();

    if (!mounted) return;
    context.go(dest);
  }

  Future<void> _verifyCode() async {
    if (!_canVerify) return;

    final code = _codeController.text.trim();
    final email = _currentEmail;

    setState(() {
      _verifying = true;
      _verifyError = null;
      _sendError = null;
      _statusLabel = 'Comprobando código…';
    });

    try {
      await ref.read(authRepositoryProvider).verifyEmailOtp(
            email: email,
            code: code,
          );
      if (!mounted) return;
      await _completeAfterConfirm();
    } on AuthException catch (e) {
      if (!mounted) return;
      final nextFails = _failedAttempts + 1;
      setState(() {
        _verifying = false;
        _failedAttempts = nextFails;
        _statusLabel = 'Revisa tu bandeja de entrada';
        if (nextFails >= _maxFailedAttempts) {
          _verifyError =
              'Has fallado $_maxFailedAttempts veces. Pide un código nuevo '
              'e introduce ese número.';
          _codeController.clear();
        } else {
          _verifyError =
              '${e.message} (intento $nextFails/$_maxFailedAttempts)';
        }
      });
      _codeFocusNode.requestFocus();
    } catch (_) {
      if (!mounted) return;
      final nextFails = _failedAttempts + 1;
      setState(() {
        _verifying = false;
        _failedAttempts = nextFails;
        _statusLabel = 'Revisa tu bandeja de entrada';
        _verifyError = nextFails >= _maxFailedAttempts
            ? 'Has fallado $_maxFailedAttempts veces. Pide un código nuevo.'
            : 'Código incorrecto. Intento $nextFails/$_maxFailedAttempts.';
      });
      _codeFocusNode.requestFocus();
    }
  }

  Future<void> _resendCode({bool forcedAfterLock = false}) async {
    if (!_canResend && !forcedAfterLock) return;
    if (_sending) return;

    final newEmail = _emailController.text.trim();
    if (!EmailTypoHelper.isValidFormat(newEmail)) {
      setState(() {
        _sendError = 'Escribe un email válido.';
        _showChangeEmail = true;
      });
      _emailFocusNode.requestFocus();
      return;
    }

    final pending = ref.read(pendingEmailVerificationProvider);
    final previousEmail = pending?.email ?? widget.email;

    setState(() {
      _sending = true;
      _sendError = null;
      _verifyError = null;
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

      await authRepo.resendEmailOtp(newEmail);

      if (mounted) {
        _codeController.clear();
        setState(() {
          _failedAttempts = 0;
          _showChangeEmail = false;
          _statusLabel = 'Te hemos enviado un código nuevo';
        });
        _startCountdown();
        _codeFocusNode.requestFocus();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newEmail.toLowerCase() == previousEmail.toLowerCase()
                  ? 'Código reenviado a $newEmail.'
                  : 'Email actualizado. Código enviado a $newEmail.',
            ),
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _sendError = e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _sendError =
              'No se pudo enviar el código. Revisa el email e inténtalo de nuevo.',
        );
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

  void _goChangeEmail() {
    final pending = ref.read(pendingEmailVerificationProvider);
    final role = pending?.role;
    ref.read(pendingEmailVerificationProvider.notifier).clear();
    if (role == 'professional') {
      context.go(AppRoutes.professionalRegister);
    } else if (role == 'client') {
      context.go(AppRoutes.clientRegister);
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showCooldown =
        _secondsLeft > 0 && !_sending && !_navigatingAway && !_lockedByFailedAttempts;
    final emailLabel = _currentEmail;

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
                    child: Icon(
                      _navigatingAway
                          ? Icons.verified_rounded
                          : Icons.pin_outlined,
                      size: 40,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    _navigatingAway
                        ? '¡Email confirmado!'
                        : 'Introduce el código',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _navigatingAway
                        ? 'Tu cuenta ya está activa. Te llevamos a tu perfil…'
                        : 'Te hemos enviado un código a $emailLabel. '
                            'Introdúcelo aquí (mismo navegador).',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                          height: 1.45,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  if (!_navigatingAway) ...[
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _codeController,
                      focusNode: _codeFocusNode,
                      enabled: !_lockedByFailedAttempts && !_verifying,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(_otpMaxLength),
                      ],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 28,
                        letterSpacing: 8,
                      ),
                      decoration: InputDecoration(
                        hintText: '••••••',
                        hintStyle: TextStyle(
                          color: AppTheme.textSecondary.withValues(alpha: 0.45),
                          letterSpacing: 8,
                          fontSize: 28,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1E252B),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _lockedByFailedAttempts
                                ? Colors.redAccent.withValues(alpha: 0.5)
                                : AppTheme.divider,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppTheme.primary,
                            width: 1.5,
                          ),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.redAccent.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                      onFieldSubmitted: (_) => _verifyCode(),
                    ),
                    if (_verifyError != null) ...[
                      const SizedBox(height: 12),
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
                          _verifyError!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13.5,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (!_lockedByFailedAttempts)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _canVerify ? _verifyCode : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _verifying
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Verificar'),
                        ),
                      ),
                    if (_lockedByFailedAttempts) ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _sending
                              ? null
                              : () => _resendCode(forcedAfterLock: true),
                          icon: _sending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded, size: 18),
                          label: Text(
                            _sending ? 'Enviando…' : 'Pedir un código nuevo',
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
                    ],
                    const SizedBox(height: 16),
                    if (!_lockedByFailedAttempts)
                      TextButton(
                        onPressed: _canResend ? () => _resendCode() : null,
                        child: Text(
                          showCooldown
                              ? 'Reenviar código en ${_secondsLeft}s'
                              : _sending
                                  ? 'Enviando…'
                                  : 'Reenviar código',
                          style: TextStyle(
                            color: _canResend
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    if (_sendError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _sendError!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        setState(() => _showChangeEmail = !_showChangeEmail);
                      },
                      child: Text(
                        _showChangeEmail
                            ? 'Ocultar cambio de email'
                            : '¿Email incorrecto?',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                    if (_showChangeEmail) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        focusNode: _emailFocusNode,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        enableSuggestions: false,
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
                            borderSide:
                                const BorderSide(color: AppTheme.divider),
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
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _sending ? null : () => _resendCode(),
                          child: const Text('Enviar código a este email'),
                        ),
                      ),
                      TextButton(
                        onPressed: _goChangeEmail,
                        child: const Text(
                          'Volver al registro',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      _statusLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        ref
                            .read(pendingEmailVerificationProvider.notifier)
                            .clear();
                        context.go(AppRoutes.login);
                      },
                      child: const Text(
                        'Ir a inicio de sesión',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  ] else ...[
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
                      _statusLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                      textAlign: TextAlign.center,
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
