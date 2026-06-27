import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/services/geo_service.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/services/profile_photo_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/premium_button.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../home/presentation/widgets/profession_multi_select_section.dart';
import '../../../../shared/widgets/city_autocomplete_field.dart';
import '../widgets/international_phone_field.dart';
import '../widgets/profile_avatar_picker.dart';
import '../widgets/register_form_field.dart';
import '../widgets/register_profile_preview.dart';
import '../widgets/register_step_indicator.dart';
import '../widgets/work_gallery_upload.dart';

class ProfessionalRegisterScreen extends ConsumerStatefulWidget {
  const ProfessionalRegisterScreen({super.key, this.redirectTo});

  final String? redirectTo;

  @override
  ConsumerState<ProfessionalRegisterScreen> createState() =>
      _ProfessionalRegisterScreenState();
}

class _ProfessionalRegisterScreenState
    extends ConsumerState<ProfessionalRegisterScreen> {
  static const _allStepLabels = [
    'Nombre comercial',
    'Ciudad',
    'Teléfono',
    'Especialidades',
    'Descripción',
    'Fotos',
    'Cuenta',
  ];

  static const _loggedInStepLabels = [
    'Nombre comercial',
    'Ciudad',
    'Teléfono',
    'Especialidades',
    'Descripción',
    'Fotos',
  ];

  int get _lastStep => _isLoggedIn ? 5 : 6;

  List<String> get _stepLabels =>
      _isLoggedIn ? _loggedInStepLabels : _allStepLabels;

  bool get _isLoggedIn => ref.watch(currentUserProvider) != null;

  int _step = 0;
  bool _isSubmitting = false;
  int _serviceRadius = 25; // km
  AutovalidateMode _nameValidateMode = AutovalidateMode.disabled;
  AutovalidateMode _cityValidateMode = AutovalidateMode.disabled;
  AutovalidateMode _phoneValidateMode = AutovalidateMode.disabled;
  AutovalidateMode _bioValidateMode = AutovalidateMode.disabled;
  AutovalidateMode _accountValidateMode = AutovalidateMode.disabled;

  final _nameFormKey = GlobalKey<FormState>();
  final _cityFormKey = GlobalKey<FormState>();
  final _bioFormKey = GlobalKey<FormState>();
  final _accountFormKey = GlobalKey<FormState>();
  final _stepScrollController = ScrollController();

  final _businessNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _bioController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  Set<String> _selectedProfessions = {};
  Set<String> _selectedCategories = {};
  List<XFile> _galleryImages = [];
  XFile? _profileAvatar;
  bool _isPhoneValid = false;
  String _phoneE164 = '';
  String _phoneDisplay = '';
  double? _latitude;
  double? _longitude;
  bool _skipGeoClear = false;

  void _onAddressOrCityChanged() {
    if (_skipGeoClear) return;
    _latitude = null;
    _longitude = null;
  }

  void _applyGeoLocation(GeoLocationResult location) {
    _skipGeoClear = true;
    _cityController.text = location.city;
    _addressController.text = location.address;
    _latitude = location.latitude;
    _longitude = location.longitude;
    _skipGeoClear = false;
    _refresh();
  }

  @override
  void initState() {
    super.initState();
    for (final c in [
      _businessNameController,
      _cityController,
      _addressController,
      _bioController,
      _emailController,
      _passwordController,
    ]) {
      c.addListener(_refresh);
    }
    _cityController.addListener(_onAddressOrCityChanged);
    _addressController.addListener(_onAddressOrCityChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillIfLoggedIn());
  }

  void _prefillIfLoggedIn() {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    if (_emailController.text.isEmpty && user.email != null) {
      _emailController.text = user.email!;
    }

    ref.read(currentProfileProvider.future).then((profile) {
      if (!mounted || profile == null) return;
      if (_businessNameController.text.isEmpty && profile.fullName != null) {
        _businessNameController.text = profile.fullName!;
      }
      if (_cityController.text.isEmpty && profile.city != null) {
        _cityController.text = profile.city!;
      }
    });
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _stepScrollController.dispose();
    _businessNameController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _isNameValid => _businessNameController.text.trim().length >= 2;

  bool get _isCityValid =>
      _cityController.text.trim().length >= 2 &&
      _addressController.text.trim().length >= 5;

  bool get _isBioValid => _bioController.text.trim().length >= 20;

  bool get _isAccountValid {
    if (_isLoggedIn) return true;
    final email = _emailController.text.trim();
    return email.contains('@') && _passwordController.text.length >= 6;
  }

  int get _previewActiveSection {
    if (_step <= 2) return 0;
    if (_step == 3) return 1;
    if (_step == 4) return 2;
    if (_step == 5) return 3;
    return 4;
  }

  int get _completedSections {
    var n = 0;
    if (_isNameValid && _isCityValid && _isPhoneValid) n++;
    if (_selectedProfessions.isNotEmpty) n++;
    if (_isBioValid) n++;
    if (_galleryImages.isNotEmpty) n++;
    return n;
  }

  bool get _canContinue {
    switch (_step) {
      case 0:
        return _isNameValid;
      case 1:
        return _isCityValid;
      case 2:
        return _isPhoneValid;
      case 3:
        return _selectedProfessions.isNotEmpty;
      case 4:
        return _isBioValid;
      case 5:
        return true;
      case 6:
        return _isAccountValid;
      default:
        return false;
    }
  }

  String? get _validationHint {
    switch (_step) {
      case 0:
        if (_isNameValid) return null;
        return 'Indica tu nombre comercial o el tuyo (mín. 2 caracteres).';
      case 1:
        if (_isCityValid) return null;
        return 'Indica la ciudad o localidad donde trabajas.';
      case 2:
        if (_isPhoneValid) return null;
        return 'Introduce un teléfono válido para tu país.';
      case 3:
        if (_selectedProfessions.isNotEmpty) return null;
        return 'Selecciona al menos un oficio para continuar.';
      case 4:
        final bioLen = _bioController.text.trim().length;
        if (_isBioValid) return null;
        return 'Describe tus servicios (${20 - bioLen} caracteres más).';
      case 5:
        return null;
      case 6:
        final missing = <String>[];
        if (!_emailController.text.contains('@')) missing.add('email válido');
        if (_passwordController.text.length < 6) {
          missing.add('contraseña (mín. 6 caracteres)');
        }
        if (missing.isEmpty) return null;
        return 'Para publicar, completa: ${missing.join(', ')}.';
      default:
        return null;
    }
  }

  String get _continueLabel {
    if (_step == _lastStep) return 'Publicar perfil';
    if (_step == 0 && _profileAvatar == null) return 'Continuar sin logo';
    if (_step == 5 && _galleryImages.isEmpty) return 'Continuar sin fotos';
    return 'Continuar';
  }

  void _goBack() {
    if (_step > 0) {
      setState(() => _step--);
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  void _handleContinue() {
    if (_isSubmitting) return;

    switch (_step) {
      case 0:
        setState(() => _nameValidateMode = AutovalidateMode.always);
        if (!_nameFormKey.currentState!.validate()) {
          _showFeedback(_validationHint);
          return;
        }
        setState(() {
          _step++;
          _nameValidateMode = AutovalidateMode.disabled;
        });
        _scrollToTop();
        return;
      case 1:
        setState(() => _cityValidateMode = AutovalidateMode.always);
        if (!_cityFormKey.currentState!.validate()) {
          _showFeedback(_validationHint);
          return;
        }
        setState(() {
          _step++;
          _cityValidateMode = AutovalidateMode.disabled;
        });
        _scrollToTop();
        return;
      case 2:
        setState(() => _phoneValidateMode = AutovalidateMode.always);
        if (!_isPhoneValid) {
          _showFeedback(_validationHint);
          return;
        }
        setState(() {
          _step++;
          _phoneValidateMode = AutovalidateMode.disabled;
        });
        _scrollToTop();
        return;
      case 3:
        if (_selectedProfessions.isEmpty) {
          _showFeedback(_validationHint);
          return;
        }
        setState(() => _step++);
        _scrollToTop();
        return;
      case 4:
        setState(() => _bioValidateMode = AutovalidateMode.always);
        if (!_bioFormKey.currentState!.validate()) {
          _showFeedback(_validationHint);
          return;
        }
        setState(() {
          _step++;
          _bioValidateMode = AutovalidateMode.disabled;
        });
        _scrollToTop();
        return;
      case 5:
        if (_isLoggedIn) {
          _submit();
        } else {
          setState(() => _step++);
          _scrollToTop();
        }
        return;
      case 6:
        setState(() => _accountValidateMode = AutovalidateMode.always);
        if (!_accountFormKey.currentState!.validate()) {
          _showFeedback(_validationHint);
          return;
        }
        _submit();
    }
  }

  void _scrollToTop() {
    if (_stepScrollController.hasClients) {
      _stepScrollController.animateTo(
        0,
        duration: AppTheme.hoverDuration,
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _showPreviewSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.scaffoldBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.62,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            RegisterProfilePreview(
              businessName: _businessNameController.text,
              city: _cityController.text,
              phone: _phoneDisplay,
              professions: _selectedProfessions,
              serviceCategories: _selectedCategories,
              bio: _bioController.text,
              galleryImages: _galleryImages,
              profileAvatar: _profileAvatar,
              activeSection: _previewActiveSection,
              accountReady: _isAccountValid,
              expanded: true,
            ),
          ],
        ),
      ),
    );
  }

  void _showFeedback(String? message) {
    if (message == null) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.surfaceElevated,
        ),
      );
  }

  static const _networkTimeout = Duration(seconds: 30);

  Future<List<String>> _uploadGalleryImages(String userId) async {
    final client = ref.read(supabaseClientProvider);
    return ProfilePhotoStorage(client)
        .uploadGalleryImages(_galleryImages, userId)
        .timeout(ProfilePhotoStorage.uploadTimeout);
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final fullName = _businessNameController.text.trim();
      final city = _cityController.text.trim();
      final addressInput = _addressController.text.trim();
      final loggedInUser = ref.read(currentUserProvider);

      double latitude;
      double longitude;
      String address = addressInput;

      if (_latitude != null && _longitude != null) {
        latitude = _latitude!;
        longitude = _longitude!;
      } else {
        final geocoded = await GeoService.geocodeAddress(
          address: addressInput,
          city: city,
        );
        latitude = geocoded.latitude;
        longitude = geocoded.longitude;
        if (geocoded.formattedAddress != null &&
            geocoded.formattedAddress!.isNotEmpty) {
          address = geocoded.formattedAddress!;
        }
      }

      late final String userId;

      if (loggedInUser != null) {
        userId = loggedInUser.id;
      } else {
        final authResult = await ref
            .read(authRepositoryProvider)
            .registerOrSignIn(
              email: email,
              password: password,
              fullName: fullName,
              role: 'professional',
            )
            .timeout(_networkTimeout);

        userId = authResult.userId;

        if (authResult.needsEmailConfirmation) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Revisa tu email para confirmar la cuenta. Luego inicia sesión y completa tu perfil.',
                ),
              ),
            );
            context.go(AppRoutes.login);
          }
          return;
        }
      }

      final accountEmail = loggedInUser?.email ?? email;

      String? profilePhotoUrl;
      if (_profileAvatar != null) {
        try {
          final client = ref.read(supabaseClientProvider);
          profilePhotoUrl = await ProfilePhotoStorage(client)
              .uploadImage(_profileAvatar!, userId)
              .timeout(ProfilePhotoStorage.uploadTimeout);
        } on TimeoutException {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'La subida del logo tardó demasiado. Comprueba tu conexión.',
                ),
              ),
            );
          }
          rethrow;
        } on StorageException catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'No se pudo guardar tu logo: ${e.message}',
                ),
              ),
            );
          }
          rethrow;
        }
      }

      List<String> galleryPhotoUrls = [];
      if (_galleryImages.isNotEmpty) {
        try {
          galleryPhotoUrls = await _uploadGalleryImages(userId);
        } on TimeoutException {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'La subida de fotos tardó demasiado. Comprueba tu conexión.',
                ),
              ),
            );
          }
          rethrow;
        } on StorageException catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'No se pudieron guardar las fotos: ${e.message}. '
                  'Ejecuta la migración 006 en Supabase (bucket profile-photos).',
                ),
              ),
            );
          }
          rethrow;
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('No se pudieron subir las fotos: $e'),
              ),
            );
          }
          rethrow;
        }
      }

      if (profilePhotoUrl == null && galleryPhotoUrls.isNotEmpty) {
        profilePhotoUrl = galleryPhotoUrls.first;
      }

      final bio = _bioController.text.trim();
      final description = bio;

      await ref
          .read(profileRepositoryProvider)
          .markAsProfessional(
            userId: userId,
            email: accountEmail,
            fullName: fullName,
            city: city,
            avatarUrl: profilePhotoUrl,
          )
          .timeout(_networkTimeout);

      await ref
          .read(professionalRepositoryProvider)
          .createProfessional(
            name: fullName,
            professions: _selectedProfessions.toList(),
            description: description,
            city: city,
            address: address,
            latitude: latitude,
            longitude: longitude,
            phone: _phoneE164,
            email: accountEmail,
            profilePhotoUrl: profilePhotoUrl,
            galleryPhotoUrls: galleryPhotoUrls,
            userId: userId,
            serviceRadiusKm: _serviceRadius,
            serviceCategories: _selectedCategories.toList(),
          )
          .timeout(_networkTimeout);

      ref.invalidate(currentUserProvider);
      ref.invalidate(featuredProfessionalsProvider);
      ref.invalidate(currentProfileProvider);
      ref.invalidate(currentProfessionalProfileProvider);
      ref.invalidate(currentUserProfessionalViewProvider);
      ref.invalidate(professionalDetailProvider(userId));

      if (mounted) {
        TextInput.finishAutofillContext(shouldSave: true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Perfil publicado correctamente!'),
          ),
        );
        context.go(AppRoutes.profile);
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        final message = e.code == '23505'
            ? 'Ya tienes un perfil publicado con esta cuenta.'
            : 'Error al guardar el perfil: ${e.message}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'La operación tardó demasiado. Comprueba tu conexión e inténtalo de nuevo.',
            ),
          ),
        );
      }
    } on GeoServiceException catch (e) {
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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildPreview() {
    return RegisterProfilePreview(
      businessName: _businessNameController.text,
      city: _cityController.text,
      phone: _phoneDisplay,
      professions: _selectedProfessions,
      serviceCategories: _selectedCategories,
      bio: _bioController.text,
      galleryImages: _galleryImages,
      profileAvatar: _profileAvatar,
      activeSection: _previewActiveSection,
      accountReady: _isAccountValid,
      expanded: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = !ResponsiveLayout.isMobile(context);
    final hint = _canContinue ? null : _validationHint;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro profesional'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
        actions: [
          if (!isWide)
            IconButton(
              tooltip: 'Vista previa del perfil',
              onPressed: _showPreviewSheet,
              icon: Badge(
                isLabelVisible: _completedSections > 0,
                backgroundColor: AppTheme.primary,
                label: Text('$_completedSections'),
                child: const Icon(Icons.visibility_outlined),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: RegisterStepIndicator(
              currentStep: _step,
              totalSteps: _stepLabels.length,
              labels: _stepLabels,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: isWide ? _buildWideBody() : _buildMobileBody(),
          ),
          _WizardFooter(
            hint: hint,
            continueLabel: _continueLabel,
            canContinue: _canContinue,
            isLoading: _isSubmitting,
            onBack: _goBack,
            onContinue: _handleContinue,
          ),
        ],
      ),
    );
  }

  Widget _buildWideBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: SingleChildScrollView(
                  controller: _stepScrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: _buildStepPanel(showStepIndicator: false),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _buildPreview(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileBody() {
    return AnimatedSwitcher(
      duration: AppTheme.hoverDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0.04, 0),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(_step),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              controller: _stepScrollController,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: _buildStepPanel(compact: true, showStepIndicator: false),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStepPanel({
    required bool showStepIndicator,
    bool compact = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showStepIndicator) ...[
          RegisterStepIndicator(
            currentStep: _step,
            totalSteps: _stepLabels.length,
            labels: _stepLabels,
          ),
          SizedBox(height: compact ? 20 : 28),
        ],
        _buildStepContent(compact: compact),
      ],
    );
  }

  Widget _buildStepContent({bool compact = false}) {
    switch (_step) {
      case 0:
        return _NameStep(
          compact: compact,
          formKey: _nameFormKey,
          autovalidateMode: _nameValidateMode,
          controller: _businessNameController,
          profileAvatar: _profileAvatar,
          onProfileAvatarChanged: (image) =>
              setState(() => _profileAvatar = image),
        );
      case 1:
        return _CityStep(
          compact: compact,
          formKey: _cityFormKey,
          autovalidateMode: _cityValidateMode,
          controller: _cityController,
          addressController: _addressController,
          onLocationDetected: _applyGeoLocation,
          serviceRadius: _serviceRadius,
          onRadiusChanged: (v) => setState(() => _serviceRadius = v),
        );
      case 2:
        return _PhoneStep(
          compact: compact,
          autovalidateMode: _phoneValidateMode,
          onValidationChanged: ({
            required isValid,
            required e164,
            required display,
          }) {
            setState(() {
              _isPhoneValid = isValid;
              _phoneE164 = e164;
              _phoneDisplay = display;
            });
          },
        );
      case 3:
        return ProfessionMultiSelectSection(
          compact: compact,
          selectedProfessions: _selectedProfessions,
          onSelectionChanged: (next) =>
              setState(() => _selectedProfessions = next),
          selectedCategories: _selectedCategories,
          onCategoriesChanged: (next) =>
              setState(() => _selectedCategories = next),
        );
      case 4:
        return _BioStep(
          compact: compact,
          formKey: _bioFormKey,
          autovalidateMode: _bioValidateMode,
          controller: _bioController,
        );
      case 5:
        return _GalleryStep(
          compact: compact,
          galleryImages: _galleryImages,
          onGalleryChanged: (images) =>
              setState(() => _galleryImages = images),
        );
      case 6:
        return _AccountStep(
          compact: compact,
          formKey: _accountFormKey,
          autovalidateMode: _accountValidateMode,
          emailController: _emailController,
          passwordController: _passwordController,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: compact ? 13 : 14,
          ),
        ),
        SizedBox(height: compact ? 24 : 32),
      ],
    );
  }
}

class _NameStep extends StatelessWidget {
  const _NameStep({
    required this.compact,
    required this.formKey,
    required this.autovalidateMode,
    required this.controller,
    required this.profileAvatar,
    required this.onProfileAvatarChanged,
  });

  final bool compact;
  final GlobalKey<FormState> formKey;
  final AutovalidateMode autovalidateMode;
  final TextEditingController controller;
  final XFile? profileAvatar;
  final ValueChanged<XFile?> onProfileAvatarChanged;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      autovalidateMode: autovalidateMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(
            compact: compact,
            title: '¿Cómo te llaman tus clientes?',
            subtitle: 'Tu nombre comercial o el tuyo si trabajas solo.',
          ),
          RegisterFormField(
            controller: controller,
            label: 'Nombre comercial o persona',
            hint: 'Ej. Reformas García o Carlos Mendoza',
            icon: Icons.storefront_outlined,
            textInputAction: TextInputAction.done,
            autofocus: true,
            validator: (v) =>
                v == null || v.trim().length < 2 ? 'Nombre obligatorio' : null,
          ),
          SizedBox(height: compact ? 24 : 32),
          ProfileAvatarPicker(
            kind: ProfileAvatarKind.professional,
            compact: compact,
            image: profileAvatar,
            onImageChanged: onProfileAvatarChanged,
          ),
        ],
      ),
    );
  }
}

class _CityStep extends StatefulWidget {
  const _CityStep({
    required this.compact,
    required this.formKey,
    required this.autovalidateMode,
    required this.controller,
    required this.addressController,
    required this.onLocationDetected,
    required this.serviceRadius,
    required this.onRadiusChanged,
  });

  final bool compact;
  final GlobalKey<FormState> formKey;
  final AutovalidateMode autovalidateMode;
  final TextEditingController controller;
  final TextEditingController addressController;
  final ValueChanged<GeoLocationResult> onLocationDetected;
  final int serviceRadius;
  final ValueChanged<int> onRadiusChanged;

  @override
  State<_CityStep> createState() => _CityStepState();
}

class _CityStepState extends State<_CityStep> {
  bool _isDetecting = false;
  String? _geoError;
  final _cityFieldKey = GlobalKey<CityAutocompleteFieldState>();

  Future<void> _detectLocation() async {
    setState(() {
      _isDetecting = true;
      _geoError = null;
    });
    try {
      final location = await GeoService.detectLocation();
      if (mounted) {
        widget.onLocationDetected(location);
        _cityFieldKey.currentState?.applyCity(location.city);
        widget.formKey.currentState?.validate();
      }
    } on GeoServiceException catch (e) {
      if (mounted) setState(() => _geoError = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _geoError = 'No se pudo obtener la ubicación.',
        );
      }
    } finally {
      if (mounted) setState(() => _isDetecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      autovalidateMode: widget.autovalidateMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(
            compact: widget.compact,
            title: '¿Dónde trabajas?',
            subtitle:
                'Ciudad y dirección donde te encuentras. Necesaria para filtrar por cercanía.',
          ),

          // ── Campo ciudad con autocompletado ─────────────────────────────
          CityAutocompleteField(
            key: _cityFieldKey,
            controller: widget.controller,
            autofocus: true,
            autovalidateMode: widget.autovalidateMode,
            validator: (v) =>
                v == null || v.trim().length < 2 ? 'Ciudad obligatoria' : null,
            onCitySelected: (_) => widget.formKey.currentState?.validate(),
          ),
          const SizedBox(height: 14),
          RegisterFormField(
            label: 'Dirección',
            controller: widget.addressController,
            hint: 'Calle, número, piso…',
            icon: Icons.place_outlined,
            validator: (v) {
              final text = v?.trim() ?? '';
              if (text.length < 5) {
                return 'Indica una dirección completa (calle y número)';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // ── Botón detectar automáticamente ──────────────────────────────
          SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isDetecting ? null : _detectLocation,
                icon: _isDetecting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_rounded, size: 18),
                label: Text(
                  _isDetecting
                      ? 'Detectando ubicación…'
                      : 'Usar mi ubicación actual',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: BorderSide(
                    color: AppTheme.primary.withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
              ),
            ),

          if (_geoError != null) ...[
            const SizedBox(height: 6),
            Text(
              _geoError!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ],

          const SizedBox(height: 28),

          // ── Slider radio de trabajo ────────────────────────────────────
          Row(
            children: [
              const Icon(
                Icons.social_distance_rounded,
                color: AppTheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '¿Cuánto te desplazas?',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(
                  widget.serviceRadius >= 150
                      ? '≥ 150 km'
                      : '${widget.serviceRadius} km',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Radio máximo desde tu ciudad para ir a trabajar.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.primary,
              inactiveTrackColor: AppTheme.divider,
              thumbColor: AppTheme.primary,
              overlayColor: AppTheme.primary.withValues(alpha: 0.15),
              trackHeight: 3,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: widget.serviceRadius.toDouble(),
              min: 5,
              max: 150,
              // Sin divisions → movimiento continuo y fluido.
              // Se redondea al múltiplo de 5 más cercano solo al soltar.
              onChanged: (v) => widget.onRadiusChanged(v.round()),
              onChangeEnd: (v) {
                final snapped = ((v / 5).round() * 5).clamp(5, 150);
                widget.onRadiusChanged(snapped);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('5 km',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTheme.textSecondary)),
                Text('≥ 150 km',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneStep extends StatelessWidget {
  const _PhoneStep({
    required this.compact,
    required this.autovalidateMode,
    required this.onValidationChanged,
  });

  final bool compact;
  final AutovalidateMode autovalidateMode;
  final void Function({
    required bool isValid,
    required String e164,
    required String display,
  }) onValidationChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeader(
          compact: compact,
          title: 'Teléfono de contacto',
          subtitle: 'Los clientes podrán llamarte directamente desde tu perfil.',
        ),
        InternationalPhoneField(
          autovalidateMode: autovalidateMode,
          textInputAction: TextInputAction.done,
          onValidationChanged: ({
            required isValid,
            required e164,
            required display,
            required phone,
          }) {
            onValidationChanged(
              isValid: isValid,
              e164: e164,
              display: display,
            );
          },
        ),
      ],
    );
  }
}

class _BioStep extends StatelessWidget {
  const _BioStep({
    required this.compact,
    required this.formKey,
    required this.autovalidateMode,
    required this.controller,
  });

  final bool compact;
  final GlobalKey<FormState> formKey;
  final AutovalidateMode autovalidateMode;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final bioLen = controller.text.trim().length;

    return Form(
      key: formKey,
      autovalidateMode: autovalidateMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(
            compact: compact,
            title: 'Cuéntanos qué haces',
            subtitle: 'Una breve descripción de tu experiencia y servicios.',
          ),
          RegisterFormField(
            controller: controller,
            label: 'Descripción de tus servicios',
            hint: 'Ej. Albañil con 10 años de experiencia en reformas integrales...',
            maxLines: compact ? 4 : 5,
            autofocus: true,
            validator: (v) {
              final len = v?.trim().length ?? 0;
              if (len < 20) return 'Mínimo 20 caracteres';
              return null;
            },
          ),
          const SizedBox(height: 6),
          Text(
            bioLen >= 20
                ? '✓ Descripción lista'
                : '${20 - bioLen.clamp(0, 20)} caracteres más',
            style: TextStyle(
              color: bioLen >= 20 ? AppTheme.primary : AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryStep extends StatelessWidget {
  const _GalleryStep({
    required this.compact,
    required this.galleryImages,
    required this.onGalleryChanged,
  });

  final bool compact;
  final List<XFile> galleryImages;
  final ValueChanged<List<XFile>> onGalleryChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeader(
          compact: compact,
          title: 'Fotos de tus trabajos',
          subtitle: 'Opcional. Muestra la calidad de tu trabajo con fotos reales.',
        ),
        WorkGalleryUpload(
          images: galleryImages,
          onImagesChanged: onGalleryChanged,
          compact: compact,
        ),
      ],
    );
  }
}

class _AccountStep extends StatelessWidget {
  const _AccountStep({
    required this.compact,
    required this.formKey,
    required this.autovalidateMode,
    required this.emailController,
    required this.passwordController,
  });

  final bool compact;
  final GlobalKey<FormState> formKey;
  final AutovalidateMode autovalidateMode;
  final TextEditingController emailController;
  final TextEditingController passwordController;

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: Form(
        key: formKey,
        autovalidateMode: autovalidateMode,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StepHeader(
              compact: compact,
              title: 'Crea tu cuenta',
              subtitle:
                  'Email y contraseña para acceder a ${AppConstants.appName}.',
            ),
            RegisterFormField(
              controller: emailController,
              label: 'Email',
              hint: 'tu@email.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofocus: true,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
              ],
              validator: (v) =>
                  v == null || !v.contains('@') ? 'Email inválido' : null,
            ),
            const SizedBox(height: 16),
            RegisterFormField(
              controller: passwordController,
              label: 'Contraseña',
              hint: 'Mínimo 6 caracteres',
              icon: Icons.lock_outline,
              obscureText: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              validator: (v) =>
                  v == null || v.length < 6 ? 'Mínimo 6 caracteres' : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _WizardFooter extends StatelessWidget {
  const _WizardFooter({
    required this.hint,
    required this.continueLabel,
    required this.canContinue,
    required this.isLoading,
    required this.onBack,
    required this.onContinue,
  });

  final String? hint;
  final String continueLabel;
  final bool canContinue;
  final bool isLoading;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.scaffoldBackground,
        border: Border(top: BorderSide(color: AppTheme.divider)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hint != null) ...[
                RegisterValidationHint(message: hint!),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: PremiumOutlinedButton(
                      label: 'Atrás',
                      onPressed: isLoading ? null : onBack,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: PremiumButton(
                      label: continueLabel,
                      isLoading: isLoading,
                      onPressed: isLoading ? null : onContinue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
