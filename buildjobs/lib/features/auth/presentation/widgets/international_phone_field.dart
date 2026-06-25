import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_field/countries.dart';
import 'package:intl_phone_field/phone_number.dart';

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
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: _FlagEmoji(
                          key: ValueKey(_selectedCountry.code),
                          flag: _selectedCountry.flag,
                        ),
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
      leading: _FlagEmoji(flag: country.flag, size: 24),
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

// Bandera con fade-in para evitar el parpadeo de emojis en web ────────────────

class _FlagEmoji extends StatefulWidget {
  const _FlagEmoji({super.key, required this.flag, this.size = 22});

  final String flag;
  final double size;

  @override
  State<_FlagEmoji> createState() => _FlagEmojiState();
}

class _FlagEmojiState extends State<_FlagEmoji>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Text(widget.flag, style: TextStyle(fontSize: widget.size)),
    );
  }
}
