import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/device_form_factor.dart';
import '../../../../core/utils/email_typo_helper.dart';
import '../../../../shared/widgets/premium_button.dart';

/// Solicita un enlace seguro de recuperación de contraseña por email.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.initialEmail,
    this.redirectTo,
  });

  final String? initialEmail;
  final String? redirectTo;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void initState() {
    super.initState();
    final email = widget.initialEmail?.trim();
    if (email != null && email.isNotEmpty) {
      _emailController.text = email;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(
            _emailController.text.trim(),
          );
      if (mounted) setState(() => _emailSent = true);
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppRoutes.login),
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
            child: _emailSent ? _buildSuccess(context) : _buildForm(context),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.lock_reset_rounded, size: 56, color: AppTheme.primary),
          const SizedBox(height: 20),
          Text(
            'Recuperar contraseña',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Te enviaremos un enlace seguro a tu email. Solo funciona '
            'durante un tiempo limitado y desde el dispositivo donde lo abras.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.45,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),
          TextFormField(
            controller: _emailController,
            style: const TextStyle(fontSize: 16),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Email de tu cuenta',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (!EmailTypoHelper.isValidFormat(value)) return 'Email inválido';
              final suggestion = EmailTypoHelper.suggestFix(value);
              if (suggestion != null &&
                  suggestion.toLowerCase() != value.toLowerCase()) {
                return '¿Quisiste decir $suggestion?';
              }
              return null;
            },
            onFieldSubmitted: (_) {
              if (!_isLoading) _sendResetLink();
            },
          ),
          const SizedBox(height: 28),
          PremiumButton(
            label: 'Enviar enlace',
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _sendResetLink,
          ),
          const SizedBox(height: 18),
          PremiumTextButton(
            onPressed: () => context.go(AppRoutes.login),
            label: 'Volver a iniciar sesión',
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(BuildContext context) {
    final email = _emailController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.mark_email_read_outlined,
            size: 56, color: AppTheme.primary),
        const SizedBox(height: 20),
        Text(
          'Revisa tu email',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
          ),
          child: Text(
            'Si existe una cuenta con $email, recibirás un enlace para '
            'elegir una nueva contraseña. Comprueba también la carpeta de spam.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  height: 1.45,
                ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Importante en móvil: abre el enlace con «Abrir en Safari» o '
          '«Abrir en Chrome» (no dentro del visor del email). '
          'Usa solo el email más reciente; los anteriores quedan inactivos.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Por seguridad, el enlace caduca en poco tiempo y solo puede '
          'usarse una vez.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        PremiumButton(
          label: 'Volver a iniciar sesión',
          onPressed: () {
            final redirect = widget.redirectTo;
            context.go(
              redirect != null && redirect.isNotEmpty
                  ? AppRoutes.loginWithRedirect(redirect)
                  : AppRoutes.login,
            );
          },
        ),
        const SizedBox(height: 12),
        PremiumTextButton(
          onPressed: _isLoading ? null : _sendResetLink,
          label: 'Reenviar enlace',
        ),
      ],
    );
  }
}
