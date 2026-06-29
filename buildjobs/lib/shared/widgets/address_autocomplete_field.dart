import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/services/geo_service.dart';
import '../../core/theme/app_theme.dart';

/// Campo de dirección con autocompletado de calles (Nominatim), acotado a [city].
class AddressAutocompleteField extends StatefulWidget {
  const AddressAutocompleteField({
    super.key,
    required this.controller,
    required this.cityController,
    this.label = 'Dirección',
    this.hint = 'Ej. Calle Mayor (número opcional)',
    this.validator,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.textInputAction = TextInputAction.done,
    this.onAddressSelected,
  });

  final TextEditingController controller;
  final TextEditingController cityController;
  final String label;
  final String hint;
  final FormFieldValidator<String>? validator;
  final AutovalidateMode autovalidateMode;
  final TextInputAction textInputAction;
  final ValueChanged<AddressSuggestion>? onAddressSelected;

  @override
  State<AddressAutocompleteField> createState() =>
      _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  late final TextEditingController _innerCtrl;
  late final FocusNode _focusNode;
  List<AddressSuggestion> _suggestions = [];
  Timer? _debounce;
  bool _loading = false;
  bool _showSuggestions = false;
  bool _selecting = false;
  bool _pointerOnSuggestions = false;

  String get _city => widget.cityController.text.trim();

  bool get _hasCity => _city.length >= 2;

  @override
  void initState() {
    super.initState();
    _innerCtrl = TextEditingController(text: widget.controller.text);
    _focusNode = FocusNode();

    _focusNode.addListener(() {
      if (!_focusNode.hasFocus &&
          !_pointerOnSuggestions &&
          !_selecting) {
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted && !_pointerOnSuggestions && !_selecting) {
            setState(() => _showSuggestions = false);
          }
        });
      }
    });

    _innerCtrl.addListener(_onTextChanged);
    widget.controller.addListener(_syncFromExternal);
    widget.cityController.addListener(_onCityChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _innerCtrl.removeListener(_onTextChanged);
    widget.controller.removeListener(_syncFromExternal);
    widget.cityController.removeListener(_onCityChanged);
    _innerCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onCityChanged() {
    if (_selecting) return;
    setState(() {
      _suggestions = [];
      _showSuggestions = false;
      _loading = false;
    });
  }

  void _syncFromExternal() {
    if (_selecting) return;
    final external = widget.controller.text;
    if (_innerCtrl.text != external) {
      _innerCtrl.value = TextEditingValue(
        text: external,
        selection: TextSelection.collapsed(offset: external.length),
      );
      setState(() {
        _showSuggestions = false;
        _loading = false;
      });
    }
  }

  void _onTextChanged() {
    if (_selecting) return;

    if (widget.controller.text != _innerCtrl.text) {
      widget.controller.text = _innerCtrl.text;
    }

    final query = _innerCtrl.text.trim();
    _debounce?.cancel();

    if (!_hasCity || query.length < 2) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);

    _debounce = Timer(const Duration(milliseconds: 420), () async {
      if (!mounted) return;
      final results = await GeoService.searchAddresses(
        city: _city,
        query: query,
      );
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _showSuggestions = results.isNotEmpty && _focusNode.hasFocus;
        _loading = false;
      });
    });
  }

  void _applySuggestion(AddressSuggestion s) {
    if (!mounted) return;

    _selecting = true;
    _debounce?.cancel();

    final value = s.streetAddress;
    _innerCtrl.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    if (widget.controller.text != value) {
      widget.controller.text = value;
    }

    setState(() {
      _suggestions = [];
      _showSuggestions = false;
      _loading = false;
    });

    widget.onAddressSelected?.call(s);

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _selecting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hint = !_hasCity
        ? 'Primero indica la ciudad'
        : widget.hint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _innerCtrl,
          focusNode: _focusNode,
          enabled: _hasCity,
          textInputAction: widget.textInputAction,
          autovalidateMode: widget.autovalidateMode,
          autocorrect: false,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 15,
          ),
          validator: widget.validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
            prefixIcon: const Icon(
              Icons.place_outlined,
              color: AppTheme.textSecondary,
              size: 20,
            ),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        color: AppTheme.primary,
                      ),
                    ),
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFF1E252B),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
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
              borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF453A)),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.divider.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
        if (_showSuggestions && _suggestions.isNotEmpty)
          MouseRegion(
            onEnter: (_) => _pointerOnSuggestions = true,
            onExit: (_) => _pointerOnSuggestions = false,
            child: Container(
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.divider),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _suggestions.asMap().entries.map((entry) {
                    final i = entry.key;
                    final s = entry.value;
                    return _AddressSuggestionTile(
                      suggestion: s,
                      isLast: i == _suggestions.length - 1,
                      onSelect: () {
                        _applySuggestion(s);
                        _focusNode.unfocus();
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AddressSuggestionTile extends StatefulWidget {
  const _AddressSuggestionTile({
    required this.suggestion,
    required this.onSelect,
    required this.isLast,
  });

  final AddressSuggestion suggestion;
  final VoidCallback onSelect;
  final bool isLast;

  @override
  State<_AddressSuggestionTile> createState() =>
      _AddressSuggestionTileState();
}

class _AddressSuggestionTileState extends State<_AddressSuggestionTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => widget.onSelect(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: _hovered
              ? AppTheme.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.signpost_outlined,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.suggestion.displayName,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!widget.isLast)
                const Divider(
                  height: 1,
                  color: AppTheme.divider,
                  indent: 40,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
