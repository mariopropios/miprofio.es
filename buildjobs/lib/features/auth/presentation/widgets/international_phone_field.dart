import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_field/countries.dart';
import 'package:intl_phone_field/phone_number.dart';

import '../../../../core/constants/phone_countries.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/phone_validation_utils.dart';
import '../../../../shared/widgets/responsive_layout.dart';

/// Campo internacional con banderas emoji (compatible web) y validación estricta.
class InternationalPhoneField extends StatefulWidget {
  const InternationalPhoneField({
    super.key,
    required this.onValidationChanged,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.textInputAction,
  });

  final void Function({
    required bool isValid,
    required String e164,
    required String display,
    required PhoneNumber phone,
  }) onValidationChanged;
  final AutovalidateMode autovalidateMode;
  final TextInputAction? textInputAction;

  @override
  State<InternationalPhoneField> createState() =>
      _InternationalPhoneFieldState();
}

class _InternationalPhoneFieldState extends State<InternationalPhoneField> {
  final _controller = TextEditingController();
  late PhoneAsYouTypeFormatter _asYouTypeFormatter;
  late final List<TextInputFormatter> _inputFormatters;
  late Country _selectedCountry;
  String? _errorText;

  static const _fieldDecoration = InputDecoration(
    filled: true,
    fillColor: Color(0xFF1E252B),
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: AppTheme.divider),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: Color(0xFFFF453A)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: Color(0xFFFF453A), width: 1.5),
    ),
    errorStyle: TextStyle(
      color: Color(0xFFFF453A),
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
  );

  @override
  void initState() {
    super.initState();
    _selectedCountry = countries.firstWhere((c) => c.code == 'ES');
    _asYouTypeFormatter = PhoneAsYouTypeFormatter(
      _selectedCountry.code,
      maxDigits: _selectedCountry.maxLength,
    );
    _inputFormatters = [_asYouTypeFormatter];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _precacheFlag(_selectedCountry.code);
    });
  }

  void _precacheFlag(String countryCode) {
    if (!kIsWeb) return;
    precacheImage(
      NetworkImage(_CountryFlag.imageUrl(countryCode)),
      context,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  PhoneNumber _buildPhone() {
    final digits = PhoneValidationUtils.digitsOnly(_controller.text);
    return PhoneNumber(
      countryISOCode: _selectedCountry.code,
      countryCode: _selectedCountry.fullCountryCode,
      number: digits,
    );
  }

  void _emitValidation(PhoneNumber phone) {
    final error = PhoneValidationUtils.validate(phone);
    final isValid = error == null;
    widget.onValidationChanged(
      isValid: isValid,
      e164: isValid ? PhoneValidationUtils.toE164(phone) : '',
      display: PhoneValidationUtils.toDisplaySimple(phone),
      phone: phone,
    );
  }

  void _handlePhoneChanged() {
    final phone = _buildPhone();
    _emitValidation(phone);
    if (widget.autovalidateMode != AutovalidateMode.disabled) {
      setState(() {
        _errorText = PhoneValidationUtils.validate(phone);
      });
    }
  }

  void _onCountrySelected(Country country) {
    _precacheFlag(country.code);
    setState(() {
      _selectedCountry = country;
      _asYouTypeFormatter.updateCountry(
        country.code,
        maxDigits: country.maxLength,
      );
      var digits = PhoneValidationUtils.digitsOnly(_controller.text);
      if (digits.length > country.maxLength) {
        digits = digits.substring(0, country.maxLength);
      }
      final formatted =
          PhoneValidationUtils.formatAsYouType(country.code, digits);
      _controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    });
  }

  Future<void> _openCountryPicker() async {
    final picked = await showModalBottomSheet<Country>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CountryPickerSheet(
        selectedCode: _selectedCountry.code,
        isMobile: ResponsiveLayout.isMobile(context),
      ),
    );
    if (picked != null) _onCountrySelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    final prefix = '+${_selectedCountry.fullCountryCode}';
    final phoneHint = PhoneValidationUtils.hintForCountry(
      _selectedCountry.code,
      _selectedCountry.maxLength,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Teléfono de contacto directo',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              color: const Color(0xFF1E252B),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _openCountryPicker,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _CountryFlag(
                        countryCode: _selectedCountry.code,
                        size: 22,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        prefix,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.textSecondary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _controller,
                keyboardType: TextInputType.phone,
                textInputAction: widget.textInputAction,
                autovalidateMode: widget.autovalidateMode,
                inputFormatters: _inputFormatters,
                style: const TextStyle(
                  color: Color(0xFFF5F5F7),
                  fontSize: 15,
                ),
                decoration: _fieldDecoration.copyWith(
                  hintText: phoneHint,
                  hintStyle: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 15,
                  ),
                  errorText: _errorText,
                ),
                validator: (_) =>
                    PhoneValidationUtils.validate(_buildPhone()),
                onChanged: (_) => _handlePhoneChanged(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({
    required this.selectedCode,
    required this.isMobile,
  });

  final String selectedCode;
  final bool isMobile;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  static const _popularCodes = [
    'ES',
    'PT',
    'FR',
    'DE',
    'IT',
    'GB',
    'US',
    'MX',
    'AR',
    'CO',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Country> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return countries;

    return countries.where((c) {
      final name = c.localizedName('es').toLowerCase();
      final dial = c.dialCode;
      final code = c.code.toLowerCase();
      return name.contains(q) ||
          dial.contains(q.replaceAll('+', '')) ||
          code.contains(q);
    }).toList();
  }

  List<Country> get _popular {
    return _popularCodes
        .map((code) {
          try {
            return countries.firstWhere((c) => c.code == code);
          } catch (_) {
            return null;
          }
        })
        .whereType<Country>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final showPopular = _query.isEmpty;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        maxWidth: widget.isMobile ? double.infinity : 420,
      ),
      margin: widget.isMobile
          ? null
          : EdgeInsets.symmetric(
              horizontal: (MediaQuery.sizeOf(context).width - 420) / 2,
              vertical: 48,
            ),
      decoration: const BoxDecoration(
        color: AppTheme.scaffoldBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              cursorColor: AppTheme.primary,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Buscar país o prefijo...',
                hintStyle: const TextStyle(color: AppTheme.textSecondary),
                prefixIcon:
                    const Icon(Icons.search, color: AppTheme.textSecondary),
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
                  borderSide:
                      const BorderSide(color: AppTheme.primary, width: 1.5),
                ),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                if (showPopular) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'Frecuentes',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  ..._popular.map(_buildTile),
                  Divider(
                    color: AppTheme.divider.withValues(alpha: 0.6),
                    height: 24,
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Text(
                      'Todos los países',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
                ...filtered.map(_buildTile),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(Country country) {
    final selected = country.code == widget.selectedCode;
    return ListTile(
      leading: _CountryFlag(countryCode: country.code, size: 24),
      title: Text(
        country.localizedName('es'),
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          fontSize: 15,
        ),
      ),
      trailing: Text(
        '+${country.fullCountryCode}',
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: selected,
      selectedTileColor: AppTheme.primary.withValues(alpha: 0.08),
      onTap: () => Navigator.pop(context, country),
    );
  }
}

// Bandera estable: imagen en web (sin parpadeo de emoji) y emoji en móvil.
class _CountryFlag extends StatelessWidget {
  const _CountryFlag({required this.countryCode, this.size = 22});

  final String countryCode;
  final double size;

  static String imageUrl(String countryCode) =>
      'https://flagcdn.com/w40/${countryCode.toLowerCase()}.png';

  @override
  Widget build(BuildContext context) {
    final width = size * 1.45;
    final height = size * 0.95;

    if (kIsWeb) {
      return SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Image.network(
            imageUrl(countryCode),
            width: width,
            height: height,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) =>
                _EmojiFlag(countryCode: countryCode, size: size),
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return ColoredBox(
                color: AppTheme.divider.withValues(alpha: 0.35),
                child: const SizedBox.expand(),
              );
            },
          ),
        ),
      );
    }

    return _EmojiFlag(countryCode: countryCode, size: size);
  }
}

class _EmojiFlag extends StatelessWidget {
  const _EmojiFlag({required this.countryCode, this.size = 22});

  final String countryCode;
  final double size;

  static const _emojiFontFallback = [
    'Segoe UI Emoji',
    'Apple Color Emoji',
    'Noto Color Emoji',
  ];

  @override
  Widget build(BuildContext context) {
    final emoji = PhoneCountries.flagEmoji(countryCode);
    return SizedBox(
      width: size * 1.45,
      height: size * 0.95,
      child: Center(
        child: Text(
          emoji,
          style: TextStyle(
            fontSize: size,
            height: 1,
            fontFamilyFallback: _emojiFontFallback,
          ),
        ),
      ),
    );
  }
}
