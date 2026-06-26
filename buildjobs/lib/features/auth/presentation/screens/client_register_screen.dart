import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/services/profile_photo_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/premium_button.dart';
import '../widgets/profile_avatar_picker.dart';
import '../widgets/register_form_field.dart';

class ClientRegisterScreen extends ConsumerStatefulWidget {
  const ClientRegisterScreen({super.key, this.redirectTo});

  final String? redirectTo;

  @override
  ConsumerState<ClientRegisterScreen> createState() =>
      _ClientRegisterScreenState();
}

class _ClientRegisterScreenState extends ConsumerState<ClientRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  XFile? _profileAvatar;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _navigateAfterAuth() {
    ref.invalidate(currentUserProvider);
    ref.invalidate(currentProfileProvider);
    ref.invalidate(currentProfessionalProfileProvider);
    ref.invalidate(currentUserProfessionalViewProvider);

    final redirect = widget.redirectTo;
    if (redirect != null && redirect.isNotEmpty) {
      context.go(redirect);
    } else {
      context.go(AppRoutes.profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear cuenta'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Únete a la comunidad',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Regístrate para buscar profesionales y dejar reseñas.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 32),
                  RegisterFormField(
                    controller: _nameController,
                    label: 'Nombre completo',
                    hint: 'Tu nombre',
                    icon: Icons.person_outline,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Nombre obligatorio' : null,
                  ),
                  const SizedBox(height: 24),
                  ProfileAvatarPicker(
                    kind: ProfileAvatarKind.client,
                    image: _profileAvatar,
                    onImageChanged: (image) =>
                        setState(() => _profileAvatar = image),
                  ),
                  const SizedBox(height: 24),
                  RegisterFormField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'tu@email.com',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                        v == null || !v.contains('@') ? 'Email inválido' : null,
                  ),
                  const SizedBox(height: 16),
                  RegisterFormField(
                    controller: _passwordController,
                    label: 'Contraseña',
                    hint: 'Mínimo 6 caracteres',
                    icon: Icons.lock_outline,
                    obscureText: true,
                    validator: (v) =>
                        v == null || v.length < 6 ? 'Mínimo 6 caracteres' : null,
                  ),
                  const SizedBox(height: 24),
                  PremiumButton(
                    label: 'Crear cuenta',
                    isLoading: _isLoading,
                    onPressed: _isLoading ? null : _register,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final response = await ref.read(authRepositoryProvider).signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            fullName: _nameController.text.trim(),
          );

      if (response.user != null &&
          response.session != null &&
          _profileAvatar != null) {
        try {
          final client = ref.read(supabaseClientProvider);
          final avatarUrl = await ProfilePhotoStorage(client)
              .uploadImage(_profileAvatar!, response.user!.id)
              .timeout(ProfilePhotoStorage.uploadTimeout);

          await ref.read(profileRepositoryProvider).updateAvatarUrl(
                userId: response.user!.id,
                avatarUrl: avatarUrl,
              );
        } on StorageException catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Cuenta creada, pero no se pudo guardar la foto: ${e.message}',
                ),
              ),
            );
          }
        } on TimeoutException {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Cuenta creada, pero la subida de la foto tardó demasiado.',
                ),
              ),
            );
          }
        }
      }

      ref.invalidate(currentProfileProvider);

      if (mounted) {
        final needsConfirmation =
            response.user != null && response.session == null;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              needsConfirmation
                  ? 'Revisa tu email para confirmar la cuenta'
                  : 'Cuenta creada correctamente',
            ),
          ),
        );

        if (!needsConfirmation) {
          _navigateAfterAuth();
        } else if (context.canPop()) {
          context.pop();
        } else {
          context.go(AppRoutes.home);
        }
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
}
