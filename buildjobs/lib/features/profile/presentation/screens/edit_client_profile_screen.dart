import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../../../core/services/gallery_image_picker.dart';
import '../../../../core/services/profile_photo_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/x_file_bytes_reader.dart';
import '../../../../core/utils/x_file_preview_image.dart';
import '../../../../shared/models/user_profile.dart';
import '../../../../shared/widgets/delete_account_section.dart';
import '../../../../shared/widgets/premium_button.dart';
import '../../../auth/presentation/widgets/register_form_field.dart';

class EditClientProfileScreen extends ConsumerStatefulWidget {
  const EditClientProfileScreen({super.key});

  @override
  ConsumerState<EditClientProfileScreen> createState() =>
      _EditClientProfileScreenState();
}

class _EditClientProfileScreenState
    extends ConsumerState<EditClientProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  XFile? _newAvatar;
  String? _currentAvatarUrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    final profile = ref.read(currentProfileProvider).valueOrNull;
    if (profile != null) _applyProfile(profile);
  }

  void _applyProfile(UserProfile profile) {
    _nameCtrl.text = profile.fullName ?? '';
    _cityCtrl.text = profile.city ?? '';
    _currentAvatarUrl = profile.avatarUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picked = await GalleryImagePicker.pickImages(
      context: context,
      maxCount: 1,
    );
    if (picked.isNotEmpty) setState(() => _newAvatar = picked.first);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final user = ref.read(currentUserProvider);
    if (user == null) {
      setState(() => _saving = false);
      return;
    }

    final pendingAvatar = _newAvatar;
    final hasPendingPhoto = pendingAvatar != null;
    final storage = ProfilePhotoStorage(ref.read(supabaseClientProvider));
    final profiles = ref.read(profileRepositoryProvider);

    try {
      await profiles.updateProfile(
        userId: user.id,
        fullName: _nameCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
      );
      ref.invalidate(currentProfileProvider);
      ref.invalidate(currentUserProfessionalViewProvider);

      if (!hasPendingPhoto) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado')),
        );
        Navigator.of(context).pop();
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil guardado. Comprimiendo y subiendo foto…'),
          duration: Duration(seconds: 8),
        ),
      );

      final bytes = await readXFileBytes(pendingAvatar);
      final avatarUrl = await storage.uploadBytes(
        rawBytes: bytes,
        userId: user.id,
        originalName: pendingAvatar.name,
      );
      await profiles.updateProfile(
        userId: user.id,
        avatarUrl: avatarUrl,
      );

      if (!mounted) return;
      ref.invalidate(currentProfileProvider);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil y foto actualizados ✓')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ProfilePhotoStorage.friendlyErrorMessage(e)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentProfileProvider, (_, next) {
      next.whenData((p) {
        if (p != null && _nameCtrl.text.isEmpty) _applyProfile(p);
      });
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Foto ─────────────────────────────────────────────
                  _EditCard(
                    icon: Icons.person_outline,
                    title: 'Foto de perfil',
                    children: [
                      Center(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _saving ? null : _pickAvatar,
                              child: Stack(
                                children: [
                                  Container(
                                    width: 96,
                                    height: 96,
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceElevated,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppTheme.primary.withValues(alpha: 0.5),
                                        width: 2,
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: _newAvatar != null
                                        ? XFilePreviewImage(
                                            file: _newAvatar!,
                                            width: 96,
                                            height: 96,
                                            borderRadius: 48,
                                          )
                                        : _currentAvatarUrl != null
                                            ? Image.network(
                                                _currentAvatarUrl!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    _avatarPlaceholder,
                                              )
                                            : _avatarPlaceholder,
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppTheme.surface,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                          Icons.camera_alt_outlined,
                                          size: 14,
                                          color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: _saving ? null : _pickAvatar,
                              child: const Text('Cambiar foto'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Datos personales ──────────────────────────────────
                  _EditCard(
                    icon: Icons.badge_outlined,
                    title: 'Datos personales',
                    children: [
                      RegisterFormField(
                        label: 'Nombre completo',
                        controller: _nameCtrl,
                        hint: 'Tu nombre',
                        icon: Icons.person_outline,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Campo obligatorio'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      RegisterFormField(
                        label: 'Ciudad (opcional)',
                        controller: _cityCtrl,
                        hint: 'Tu ciudad',
                        icon: Icons.location_city_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    child: PremiumButton(
                      label: _saving ? 'Guardando...' : 'Guardar cambios',
                      onPressed: _saving ? null : _save,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const DeleteAccountSection(isProfessional: false),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget get _avatarPlaceholder => const Center(
        child: Icon(Icons.person_outline,
            size: 40, color: AppTheme.textSecondary),
      );
}

class _EditCard extends StatelessWidget {
  const _EditCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppTheme.primary, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: AppTheme.divider, height: 1),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}
