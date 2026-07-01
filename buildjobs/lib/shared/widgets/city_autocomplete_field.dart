import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/services/geo_permission_helper.dart';
import '../../core/services/geo_service.dart';
import '../../core/theme/app_theme.dart';

/// Campo de texto con autocompletado de ciudades usando la API de Nominatim.
/// Muestra "Ciudad, Provincia" en las sugerencias pero guarda solo la ciudad.
/// Sincroniza con el [controller] externo.
class CityAutocompleteField extends StatefulWidget {
  const CityAutocompleteField({
    super.key,
    required this.controller,
    this.label = 'Localidad / Ciudad',
    this.hint = 'Ej. Madrid, Sevilla, Valencia...',
    this.validator,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.autofocus = false,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    this.onCitySelected,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final FormFieldValidator<String>? validator;
  final AutovalidateMode autovalidateMode;
  final bool autofocus;
  final TextInputAction textInputAction;
  final VoidCallback? onSubmitted;
  /// Llamado cuando el usuario selecciona una sugerencia del desplegable.
  final ValueChanged<String>? onCitySelected;

  @override
  State<CityAutocompleteField> createState() => CityAutocompleteFieldState();
}

class CityAutocompleteFieldState extends State<CityAutocompleteField> {
  // Usamos un controller interno para no interferir con las sugerencias
  late final TextEditingController _innerCtrl;
  late final FocusNode _focusNode;
  List<CitySuggestion> _suggestions = [];
  Timer? _debounce;
  bool _loading = false;
  bool _detectingLocation = false;
  bool _showSuggestions = false;
  // Evita disparar búsquedas al seleccionar una sugerencia
  bool _selecting = false;
  // El puntero está sobre el desplegable (evita cerrarlo antes del click).
  bool _pointerOnSuggestions = false;

  @override
  void initState() {
    super.initState();
    _innerCtrl = TextEditingController(text: widget.controller.text);
    _focusNode = FocusNode();

    // Cuando el campo pierde foco, ocultar sugerencias con pequeño delay
    // para que el tap en una sugerencia se registre antes
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

    // Sincronizar si el controller externo cambia desde fuera (e.g. auto-detect)
    widget.controller.addListener(_syncFromExternal);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _innerCtrl.removeListener(_onTextChanged);
    widget.controller.removeListener(_syncFromExternal);
    _innerCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Cuando el exterior actualiza el controller (detección automática)
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

    // Sincronizar hacia el controller externo
    if (widget.controller.text != _innerCtrl.text) {
      widget.controller.text = _innerCtrl.text;
    }

    final query = _innerCtrl.text.trim();
    _debounce?.cancel();

    if (query.length < 2) {
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
      final results = await GeoService.searchCities(query);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _showSuggestions = results.isNotEmpty && _focusNode.hasFocus;
        _loading = false;
      });
    });
  }

  /// Aplica una localidad detectada o elegida (sincroniza campo interno y externo).
  void applyCity(String city) {
    if (!mounted) return;

    final trimmed = city.trim();
    if (trimmed.isEmpty) return;

    _selecting = true;
    _debounce?.cancel();

    _innerCtrl.value = TextEditingValue(
      text: trimmed,
      selection: TextSelection.collapsed(offset: trimmed.length),
    );
    if (widget.controller.text != trimmed) {
      widget.controller.text = trimmed;
    }

    setState(() {
      _suggestions = [];
      _showSuggestions = false;
      _loading = false;
      _detectingLocation = false;
    });

    widget.onCitySelected?.call(trimmed);

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _selecting = false;
    });
  }

  void _selectSuggestion(CitySuggestion s) {
    // Guardamos "Ciudad, Provincia" completo para mostrar la provincia al usuario
    applyCity(s.displayName);
    _focusNode.unfocus();
  }

  Future<void> _detectLocation() async {
    if (_detectingLocation) return;

    setState(() {
      _detectingLocation = true;
      _showSuggestions = false;
    });
    _focusNode.unfocus();

    try {
      final city = await GeoService.detectCity();
      if (!mounted) return;
      applyCity(city);
      _focusNode.unfocus();
    } on GeoServiceException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
        await GeoPermissionHelper.handleException(context, e);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo obtener la ubicación.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _detectingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Campo de texto ───────────────────────────────────────────────────
        TextFormField(
          controller: _innerCtrl,
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          textInputAction: widget.textInputAction,
          autovalidateMode: widget.autovalidateMode,
          style: const TextStyle(color: AppTheme.textPrimary),
          onFieldSubmitted: (_) => widget.onSubmitted?.call(),
          validator: widget.validator,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            hintStyle:
                const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            labelStyle: const TextStyle(color: AppTheme.textSecondary),
            prefixIcon: IconButton(
              onPressed: _detectingLocation ? null : _detectLocation,
              tooltip: 'Detectar mi ubicación',
              icon: Icon(
                _detectingLocation
                    ? Icons.gps_fixed_rounded
                    : Icons.location_on_outlined,
                color: _detectingLocation
                    ? AppTheme.primary
                    : AppTheme.textSecondary,
                size: 20,
              ),
            ),
            suffixIcon: (_loading || _detectingLocation)
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
            fillColor: AppTheme.surfaceElevated,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide:
                  const BorderSide(color: AppTheme.divider, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide:
                  const BorderSide(color: AppTheme.primary, width: 1.8),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: const BorderSide(color: Colors.red, width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: const BorderSide(color: Colors.red, width: 1.8),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),

        // ── Desplegable de sugerencias ───────────────────────────────────────
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
                  return _SuggestionTile(
                    suggestion: s,
                    isLast: i == _suggestions.length - 1,
                    onSelect: () => _selectSuggestion(s),
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

class _SuggestionTile extends StatefulWidget {
  const _SuggestionTile({
    required this.suggestion,
    required this.onSelect,
    required this.isLast,
  });

  final CitySuggestion suggestion;
  final VoidCallback onSelect;
  final bool isLast;

  @override
  State<_SuggestionTile> createState() => _SuggestionTileState();
}

class _SuggestionTileState extends State<_SuggestionTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    // Separar ciudad y provincia para mostrarlos con estilos distintos
    final city = widget.suggestion.shortName;
    final province = widget.suggestion.province;

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
                      Icons.location_city_outlined,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: city,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (province != null) ...[
                              const TextSpan(
                                text: ', ',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              TextSpan(
                                text: province,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
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
