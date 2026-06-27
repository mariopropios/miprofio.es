import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/search_suggestion.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_theme.dart';

/// Campo de búsqueda con autocompletado de oficios y empresas publicadas.
class SearchAutocompleteField extends ConsumerStatefulWidget {
  const SearchAutocompleteField({
    super.key,
    required this.controller,
    required this.onSubmitted,
    required this.onSuggestionSelected,
    this.hintText = 'Nombre, oficio...',
  });

  final TextEditingController controller;
  final VoidCallback onSubmitted;
  final ValueChanged<SearchSuggestion> onSuggestionSelected;
  final String hintText;

  @override
  ConsumerState<SearchAutocompleteField> createState() =>
      SearchAutocompleteFieldState();
}

class SearchAutocompleteFieldState
    extends ConsumerState<SearchAutocompleteField> {
  late final TextEditingController _innerCtrl;
  late final FocusNode _focusNode;
  List<SearchSuggestion> _suggestions = [];
  Timer? _debounce;
  bool _loading = false;
  bool _showSuggestions = false;
  bool _selecting = false;
  bool _pointerOnSuggestions = false;
  int _requestId = 0;

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

    if (query.length < 2) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);

    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final requestId = ++_requestId;
      final results = await ref
          .read(professionalRepositoryProvider)
          .searchSuggestions(query);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _suggestions = results;
        _showSuggestions = results.isNotEmpty && _focusNode.hasFocus;
        _loading = false;
      });
    });
  }

  void applyQuery(String text) {
    if (!mounted) return;
    final trimmed = text.trim();
    _selecting = true;
    _debounce?.cancel();
    _innerCtrl.value = TextEditingValue(
      text: trimmed,
      selection: TextSelection.collapsed(offset: trimmed.length),
    );
    widget.controller.text = trimmed;
    setState(() {
      _suggestions = [];
      _showSuggestions = false;
      _loading = false;
    });
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _selecting = false;
    });
  }

  void _selectSuggestion(SearchSuggestion suggestion) {
    _selecting = true;
    _debounce?.cancel();
    applyQuery(suggestion.label);
    _focusNode.unfocus();
    widget.onSuggestionSelected(suggestion);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _selecting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _innerCtrl,
          focusNode: _focusNode,
          textInputAction: TextInputAction.search,
          style: const TextStyle(color: AppTheme.textPrimary),
          onSubmitted: (_) => widget.onSubmitted(),
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: const Icon(Icons.search),
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
                : GestureDetector(
                    onTap: widget.onSubmitted,
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
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

  final SearchSuggestion suggestion;
  final VoidCallback onSelect;
  final bool isLast;

  @override
  State<_SuggestionTile> createState() => _SuggestionTileState();
}

class _SuggestionTileState extends State<_SuggestionTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.suggestion;
    final icon = s.isProfession ? Icons.work_outline_rounded : Icons.storefront_outlined;
    final typeLabel = s.isProfession ? 'Oficio' : 'Empresa';

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
                    Icon(icon, size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.label,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (s.subtitle != null &&
                              s.subtitle!.isNotEmpty &&
                              !s.isProfession) ...[
                            const SizedBox(height: 2),
                            Text(
                              s.subtitle!,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        typeLabel,
                        style: TextStyle(
                          color: AppTheme.primary.withValues(alpha: 0.95),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
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
