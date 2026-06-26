import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../shared/widgets/premium_button.dart';
import '../../../../core/theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.redirectTo});

  final String? redirectTo;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _navigateAfterAuth() {
    final redirect = widget.redirectTo;
    if (redirect != null && redirect.isNotEmpty) {
      context.go(redirect);
    } else {
      // Siempre usar go() para forzar una reconstrucción limpia del destino.
      // pop() devuelve a la pantalla anterior con caché desactualizado.
      context.go(AppRoutes.profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    // < 1024 px (móvil y tablet): ocupa todo el ancho. Desktop: limitado a 480.
    final isCompact = screenW < AppConstants.tabletBreakpoint;
    final cardWidth = isCompact ? screenW : 480.0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.home),
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
                  const Icon(Icons.construction, size: 56, color: AppTheme.primary),
                  const SizedBox(height: 20),
                  Text(
                    'Bienvenido a ${AppConstants.appName}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Inicia sesión con email y contraseña',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),
                  TextFormField(
                    controller: _emailController,
                    style: const TextStyle(fontSize: 16),
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                        v == null || !v.contains('@') ? 'Email inválido' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    style: const TextStyle(fontSize: 16),
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    validator: (v) =>
                        v == null || v.length < 6 ? 'Mínimo 6 caracteres' : null,
                  ),
                  const SizedBox(height: 28),
                  PremiumButton(
                    label: 'Iniciar sesión',
                    isLoading: _isLoading,
                    onPressed: _isLoading ? null : _login,
                  ),
                  const SizedBox(height: 18),
                  PremiumTextButton(
                    onPressed: () {
                      final redirect = widget.redirectTo;
                      context.push(
                        redirect != null
                            ? '${AppRoutes.register}?redirect=${Uri.encodeComponent(redirect)}'
                            : AppRoutes.register,
                      );
                    },
                    label: '¿No tienes cuenta? Regístrate',
                  ),
                  const SizedBox(height: 32),
                  // ── Banner "explorar sin cuenta" ─────────────────────────
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.home),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primary.withValues(alpha: 0.13),
                            AppTheme.primary.withValues(alpha: 0.06),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.search_rounded,
                              color: AppTheme.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '¿Solo buscas un profesional?',
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Explora perfiles sin necesidad de cuenta.',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13.5,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: AppTheme.primary,
                          ),
                        ],
                      ),
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

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await ref.read(authRepositoryProvider).signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      // Invalidar explícitamente para que el siguiente read sea fresco
      // (no esperamos al stream de Supabase para redirigir).
      ref.invalidate(currentUserProvider);
      ref.invalidate(currentProfileProvider);
      ref.invalidate(currentProfessionalProfileProvider);
      ref.invalidate(currentUserProfessionalViewProvider);

      if (mounted) _navigateAfterAuth();
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
}
