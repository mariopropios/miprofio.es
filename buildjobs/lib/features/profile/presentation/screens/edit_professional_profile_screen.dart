import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/services/geo_service.dart';
import '../../../../core/services/gallery_image_picker.dart';
import '../../../../core/services/profile_photo_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/x_file_preview_image.dart';
import '../../../../shared/models/professional.dart';
import '../../../../shared/widgets/city_autocomplete_field.dart';
import '../../../../shared/widgets/premium_button.dart';
import '../../../../shared/widgets/spring_pressable.dart';
import '../../../auth/presentation/widgets/register_form_field.dart';
import '../../../home/presentation/widgets/profession_multi_select_section.dart';

class EditProfessionalProfileScreen extends ConsumerStatefulWidget {
  const EditProfessionalProfileScreen({super.key});

  @override
  ConsumerState<EditProfessionalProfileScreen> createState() =>
      _EditProfessionalProfileScreenState();
}

class _EditProfessionalProfileScreenState
    extends ConsumerState<EditProfessionalProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  Set<String> _selectedProfessions = {};
  String? _currentProfilePhotoUrl;
  XFile? _newProfilePhoto;
  List<String> _existingGallery = [];
  List<XFile> _newGallery = [];
  int _serviceRadius = 25;
  Set<String> _serviceCategories = {};
  bool _saving = false;
  bool _detectingCity = false;
  String? _geoError;
  String? _professionalId;
  bool _loaded = false;
  final _cityFieldKey = GlobalKey<CityAutocompleteFieldState>();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final prof = await ref
        .read(professionalRepositoryProvider)
        .getProfessionalForUser(user.id);
    if (!mounted || prof == null) return;
    _applyProfessional(prof);
  }

  void _applyProfessional(Professional p) {
    setState(() {
      _professionalId = p.id;
      _nameCtrl.text = p.name;
      _cityCtrl.text = p.city;
      _phoneCtrl.text = p.phone ?? '';
      _websiteCtrl.text = p.website ?? '';
      _addressCtrl.text = p.address ?? '';
      _bioCtrl.text = p.description ?? '';
      // Parse comma-separated professions into a Set
      _selectedProfessions = p.professions.toSet();
      _currentProfilePhotoUrl = p.profilePhoto;
      _existingGallery = List<String>.from(p.galleryPhotos);
      _serviceRadius = p.serviceRadiusKm;
      _serviceCategories = p.serviceCategories.toSet();
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _phoneCtrl.dispose();
    _websiteCtrl.dispose();
    _addressCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _detectCity() async {
    setState(() {
      _detectingCity = true;
      _geoError = null;
    });
    try {
      final city = await GeoService.detectCity();
      if (mounted) {
        _cityFieldKey.currentState?.applyCity(city);
      }
    } on GeoServiceException catch (e) {
      if (mounted) setState(() => _geoError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _geoError = 'No se pudo obtener la ubicación.');
      }
    } finally {
      if (mounted) setState(() => _detectingCity = false);
    }
  }

  Future<void> _pickProfilePhoto() async {
    final picked =
        await GalleryImagePicker.pickImages(context: context, maxCount: 1);
    if (picked.isNotEmpty) setState(() => _newProfilePhoto = picked.first);
  }

  Future<void> _pickGalleryPhotos() async {
    final remaining = (AppConstants.maxGalleryPhotos -
            _existingGallery.length -
            _newGallery.length)
        .clamp(0, AppConstants.maxGalleryPhotos);
    if (remaining <= 0) return;
    final picked = await GalleryImagePicker.pickImages(
        context: context, maxCount: remaining);
    if (picked.isNotEmpty) {
      setState(() => _newGallery = [..._newGallery, ...picked]);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final user = ref.read(currentUserProvider);
    if (user == null || _professionalId == null) return;
    setState(() => _saving = true);
    try {
      final storage = ProfilePhotoStorage(ref.read(supabaseClientProvider));

      String? newProfilePhotoUrl;
      if (_newProfilePhoto != null) {
        newProfilePhotoUrl =
            await storage.uploadImage(_newProfilePhoto!, user.id);
      }

      List<String> uploadedGallery = [];
      if (_newGallery.isNotEmpty) {
        uploadedGallery =
            await storage.uploadGalleryImages(_newGallery, user.id);
      }
      final finalGallery = [..._existingGallery, ...uploadedGallery];

      await ref.read(professionalRepositoryProvider).updateProfessional(
            professionalId: _professionalId!,
            name: _nameCtrl.text.trim(),
            profession: _selectedProfessions.join(', '),
            city: _cityCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            website: _websiteCtrl.text.trim(),
            address: _addressCtrl.text.trim(),
            description: _bioCtrl.text.trim(),
            profilePhotoUrl: newProfilePhotoUrl,
            galleryPhotoUrls: finalGallery,
            serviceRadiusKm: _serviceRadius,
            serviceCategories: _serviceCategories.toList(),
          );

      // Invalidar todos los providers que cachean datos del profesional
      ref.invalidate(currentProfessionalProfileProvider);
      ref.invalidate(currentUserProfessionalViewProvider);
      ref.invalidate(professionalDetailProvider(_professionalId!));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado ✓')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Editar ficha profesional')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar ficha profesional'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(
              _saving ? 'Guardando...' : 'Guardar',
              style: const TextStyle(
                  color: AppTheme.primary, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Foto de perfil ──────────────────────────────────
                  _EditCard(
                    icon: Icons.storefront_outlined,
                    title: 'Foto de perfil / Logo',
                    children: [
                      _ProfilePhotoPicker(
                        currentUrl: _currentProfilePhotoUrl,
                        newFile: _newProfilePhoto,
                        onPick: _saving ? null : _pickProfilePhoto,
                        onRemove: _saving
                            ? null
                            : () => setState(() {
                                  _newProfilePhoto = null;
                                  _currentProfilePhotoUrl = null;
                                }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Especialidades + Categorías ─────────────────────
                  _EditCard(
                    icon: Icons.build_outlined,
                    title: 'Especialidades',
                    children: [
                      ProfessionMultiSelectSection(
                        compact: true,
                        selectedProfessions: _selectedProfessions,
                        onSelectionChanged: (next) =>
                            setState(() => _selectedProfessions = next),
                        selectedCategories: _serviceCategories,
                        onCategoriesChanged: (next) =>
                            setState(() => _serviceCategories = next),
                      ),
                      if (_selectedProfessions.isEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Selecciona al menos un oficio',
                          style: TextStyle(
                              color: Colors.redAccent, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Información básica ──────────────────────────────
                  _EditCard(
                    icon: Icons.info_outline_rounded,
                    title: 'Información básica',
                    children: [
                      RegisterFormField(
                        label: 'Nombre comercial',
                        controller: _nameCtrl,
                        hint: 'Nombre de tu negocio o tu nombre',
                        icon: Icons.storefront_outlined,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Campo obligatorio'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      CityAutocompleteField(
                        key: _cityFieldKey,
                        controller: _cityCtrl,
                        label: 'Ciudad',
                        hint: 'Ciudad donde trabajas',
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Campo obligatorio'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: (_detectingCity || _saving)
                                ? null
                                : _detectCity,
                            icon: _detectingCity
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.my_location_rounded,
                                    size: 16),
                            label: Text(
                              _detectingCity
                                  ? 'Detectando…'
                                  : 'Usar mi ubicación actual',
                              style: const TextStyle(fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primary,
                              side: BorderSide(
                                color: AppTheme.primary.withValues(alpha: 0.5),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        if (_geoError != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _geoError!,
                            style: const TextStyle(
                                color: Colors.redAccent, fontSize: 12),
                          ),
                        ],
                      ],
                      const SizedBox(height: 6),
                      RegisterFormField(
                        label: 'Teléfono (opcional)',
                        controller: _phoneCtrl,
                        hint: 'Ej: +34 600 000 000',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 14),
                      RegisterFormField(
                        label: 'Dirección (opcional)',
                        controller: _addressCtrl,
                        hint: 'Calle, número...',
                        icon: Icons.place_outlined,
                      ),
                      const SizedBox(height: 14),
                      RegisterFormField(
                        label: 'Sitio web (opcional)',
                        controller: _websiteCtrl,
                        hint: 'https://...',
                        icon: Icons.language_outlined,
                        keyboardType: TextInputType.url,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Descripción ─────────────────────────────────────
                  _EditCard(
                    icon: Icons.description_outlined,
                    title: 'Descripción',
                    children: [
                      TextFormField(
                        controller: _bioCtrl,
                        maxLines: 5,
                        maxLength: 800,
                        style:
                            const TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText:
                              'Describe tus servicios, experiencia, zona de trabajo...',
                          hintStyle: const TextStyle(
                              color: AppTheme.textSecondary),
                          filled: true,
                          fillColor: const Color(0xFF1E252B),
                          contentPadding: const EdgeInsets.all(14),
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
                                color: AppTheme.primary, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Radio de servicio ───────────────────────────────
                  _EditCard(
                    icon: Icons.social_distance_outlined,
                    title: 'Radio de desplazamiento',
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.directions_car_outlined,
                              color: AppTheme.textSecondary, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: AppTheme.primary,
                                thumbColor: AppTheme.primary,
                                inactiveTrackColor: AppTheme.primary
                                    .withValues(alpha: 0.25),
                              ),
                              child: Slider(
                                value: _serviceRadius.toDouble(),
                                min: 5,
                                max: 150,
                                onChanged: (v) => setState(
                                    () => _serviceRadius = v.round()),
                                onChangeEnd: (v) {
                                  final snapped =
                                      ((v / 5).round() * 5).clamp(5, 150);
                                  setState(
                                      () => _serviceRadius = snapped);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 58,
                            child: Text(
                              '$_serviceRadius km',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Galería ─────────────────────────────────────────
                  _EditCard(
                    icon: Icons.photo_library_outlined,
                    title: 'Fotos de tus trabajos',
                    children: [
                      _GalleryEditor(
                        existingUrls: _existingGallery,
                        newFiles: _newGallery,
                        onRemoveExisting: (idx) =>
                            setState(() => _existingGallery.removeAt(idx)),
                        onRemoveNew: (idx) =>
                            setState(() => _newGallery.removeAt(idx)),
                        onAddPhotos:
                            _saving ? null : _pickGalleryPhotos,
                        totalMax: AppConstants.maxGalleryPhotos,
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
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Card contenedor de sección ────────────────────────────────────────────────

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

// ── Selector de foto de perfil ─────────────────────────────────────────────────

class _ProfilePhotoPicker extends StatelessWidget {
  const _ProfilePhotoPicker({
    required this.currentUrl,
    required this.newFile,
    required this.onPick,
    required this.onRemove,
  });

  final String? currentUrl;
  final XFile? newFile;
  final VoidCallback? onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final hasPhoto =
        newFile != null || (currentUrl != null && currentUrl!.isNotEmpty);

    return Row(
      children: [
        GestureDetector(
          onTap: onPick,
          child: Stack(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: hasPhoto
                        ? AppTheme.primary.withValues(alpha: 0.5)
                        : AppTheme.divider,
                    width: hasPhoto ? 2 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: newFile != null
                    ? XFilePreviewImage(
                        file: newFile!,
                        width: 88,
                        height: 88,
                        borderRadius: 14,
                      )
                    : currentUrl != null && currentUrl!.isNotEmpty
                        ? Image.network(currentUrl!, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder)
                        : _placeholder,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(8),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: const Icon(Icons.camera_alt_outlined,
                      size: 13, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.add_photo_alternate_outlined,
                  size: 16),
              label: const Text('Cambiar foto'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
            if (hasPhoto) ...[
              const SizedBox(height: 6),
              TextButton(
                onPressed: onRemove,
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: const Text('Quitar foto',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget get _placeholder => const Center(
        child: Icon(Icons.storefront_outlined,
            size: 32, color: AppTheme.textSecondary),
      );
}

// ── Editor de galería ──────────────────────────────────────────────────────────

class _GalleryEditor extends StatelessWidget {
  const _GalleryEditor({
    required this.existingUrls,
    required this.newFiles,
    required this.onRemoveExisting,
    required this.onRemoveNew,
    required this.onAddPhotos,
    required this.totalMax,
  });

  final List<String> existingUrls;
  final List<XFile> newFiles;
  final void Function(int idx) onRemoveExisting;
  final void Function(int idx) onRemoveNew;
  final VoidCallback? onAddPhotos;
  final int totalMax;

  int get _total => existingUrls.length + newFiles.length;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_total > 0) ...[
          SizedBox(
            height: 90,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < existingUrls.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _Thumb.url(
                        url: existingUrls[i],
                        onRemove: () => onRemoveExisting(i)),
                  ),
                for (var i = 0; i < newFiles.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _Thumb.file(
                        file: newFiles[i],
                        onRemove: () => onRemoveNew(i)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_total < totalMax)
          SpringPressable(
            onTap: onAddPhotos,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: AppTheme.scaffoldBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 28,
                      color: AppTheme.primary.withValues(alpha: 0.8)),
                  const SizedBox(height: 6),
                  Text(
                    'Añadir fotos · $_total/$totalMax',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          )
        else
          Text(
            'Límite alcanzado · $_total/$totalMax',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 13),
          ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb.url({required String url, required this.onRemove})
      : _url = url,
        _file = null;

  const _Thumb.file({required XFile file, required this.onRemove})
      : _file = file,
        _url = null;

  final String? _url;
  final XFile? _file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: _file != null
              ? XFilePreviewImage(file: _file, width: 88, height: 88)
              : Image.network(_url ?? '',
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                        width: 88,
                        height: 88,
                        color: AppTheme.surfaceElevated,
                        child: const Icon(Icons.broken_image_outlined,
                            color: AppTheme.textSecondary),
                      )),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: SpringPressable(
            onTap: onRemove,
            pressedScale: 0.9,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                  color: Color(0xFF262E36), shape: BoxShape.circle),
              child:
                  const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
