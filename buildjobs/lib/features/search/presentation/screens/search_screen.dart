import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/gallery_photo_constants.dart';
import '../../../../core/constants/profession_catalog.dart';
import '../../../../core/models/search_suggestion.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/company.dart';
import '../../../../shared/widgets/async_value_widget.dart';
import '../../../../shared/widgets/savable_company_card.dart';
import '../../../../shared/widgets/city_autocomplete_field.dart';
import '../../../../shared/widgets/company_card_deck.dart';
import '../../../../shared/widgets/pinned_header_delegate.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../../shared/widgets/search_autocomplete_field.dart';
import '../../../home/presentation/widgets/profession_filter_section.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({
    super.key,
    this.initialProfession,
    this.initialQuery,
    this.initialCategoryId,
    this.initialCity,
  });

  final String? initialProfession;
  final String? initialQuery;
  final String? initialCategoryId;
  final String? initialCity;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _cityController = TextEditingController();
  String? _selectedProfession;
  String? _selectedCategoryId;
  String? _selectedCity;
  String _query = '';
  List<String> _expandedProfessions = const [];

  bool get _hasActiveFilters =>
      _selectedProfession != null ||
      _query.isNotEmpty ||
      _selectedCity != null;

  @override
  void initState() {
    super.initState();
    _selectedProfession = widget.initialProfession;
    _selectedCategoryId = widget.initialCategoryId;
    _selectedCity = widget.initialCity;
    if (widget.initialCity != null) {
      _cityController.text = widget.initialCity!;
    }
    if (widget.initialQuery != null) {
      _controller.text = widget.initialQuery!;
      _query = widget.initialQuery!;
      _expandedProfessions =
          ProfessionCatalog.relatedProfessionNames(widget.initialQuery!);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _applySuggestion(SearchSuggestion suggestion) {
    if (suggestion.isProfession) {
      setState(() {
        _query = '';
        _expandedProfessions = const [];
      });
      _selectProfession(suggestion.label, suggestion.categoryId);
      return;
    }

    final name = suggestion.label.trim();
    setState(() {
      _query = name;
      _expandedProfessions = ProfessionCatalog.relatedProfessionNames(name);
      _selectedProfession = null;
      _selectedCategoryId = null;
    });
    context.go(
      AppRoutes.searchWith(
        q: name,
        city: _selectedCity,
      ),
    );
  }

  void _search() {
    final query = _controller.text.trim();
    final expanded = query.isNotEmpty
        ? ProfessionCatalog.relatedProfessionNames(query)
        : <String>[];
    setState(() {
      _query = query;
      _expandedProfessions = expanded;
    });
    context.go(
      AppRoutes.searchWith(
        profession: _selectedProfession,
        q: query.isEmpty ? null : query,
        categoryId: _selectedCategoryId,
        city: _selectedCity,
      ),
    );
  }

  void _selectProfession(String? profession, [String? categoryId]) {
    final next = _selectedProfession == profession ? null : profession;
    setState(() {
      _selectedProfession = next;
      _selectedCategoryId = next != null ? categoryId : null;
    });

    // Si no queda ningún filtro activo, volver al inicio con los destacados
    if (next == null && _query.isEmpty) {
      context.go(AppRoutes.home);
      return;
    }

    context.go(
      AppRoutes.searchWith(
        profession: next,
        q: _query.isEmpty ? null : _query,
        categoryId: next != null ? categoryId : null,
        city: _selectedCity,
      ),
    );
  }

  void _applyCityFilter(String? city) {
    final normalized = city?.trim();
    final next = (normalized == null || normalized.isEmpty) ? null : normalized;
    setState(() => _selectedCity = next);
    context.go(
      AppRoutes.searchWith(
        profession: _selectedProfession,
        q: _query.isEmpty ? null : _query,
        categoryId: _selectedCategoryId,
        city: next,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final params = ProfessionalSearchParams(
      query: _query.isEmpty ? null : _query,
      profession: _selectedProfession,
      categoryId: _selectedProfession != null ? _selectedCategoryId : null,
      city: _selectedCity,
      expandedProfessions: _selectedProfession == null ? _expandedProfessions : const [],
    );
    final resultsAsync = ref.watch(professionalsProvider(params));
    final useCollapsibleHeader = ResponsiveLayout.isMobile(context);

    return Scaffold(
      primary: false,
      appBar: AppBar(title: const Text('Buscar')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(professionalsProvider(params));
          await ref.read(professionalsProvider(params).future);
        },
        child: ResponsiveContent(
          child: useCollapsibleHeader
              ? _buildCompactLayout(context, resultsAsync)
              : _buildDesktopLayout(context, resultsAsync),
        ),
      ),
    );
  }

  Widget _buildFiltersPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFiltersForm(),
        if (_hasActiveFilters) ...[
          const SizedBox(height: 12),
          _buildActiveFilterChips(),
        ],
      ],
    );
  }

  Widget _buildFiltersForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        SearchAutocompleteField(
          controller: _controller,
          onSubmitted: _search,
          onSuggestionSelected: _applySuggestion,
        ),
        const SizedBox(height: 10),
        CityAutocompleteField(
          controller: _cityController,
          label: 'Ciudad o localidad',
          hint: 'Ej. Madrid, Sevilla, Valencia...',
          textInputAction: TextInputAction.search,
          onCitySelected: _applyCityFilter,
          onSubmitted: () {
            _applyCityFilter(_cityController.text);
          },
        ),
        const SizedBox(height: 16),
        ProfessionFilterSection(
          selectedProfession: _selectedProfession,
          onProfessionTap: (name, catId) => _selectProfession(name, catId),
        ),
      ],
    );
  }

  Widget _buildActiveFilterChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        if (_selectedProfession != null)
          Chip(
            avatar: const Icon(Icons.work_outline_rounded,
                size: 16, color: AppTheme.textSecondary),
            label: Text(
              _selectedProfession!,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            deleteIconColor: AppTheme.textSecondary,
            side: const BorderSide(color: AppTheme.divider),
            backgroundColor: AppTheme.surfaceElevated,
            onDeleted: () => _selectProfession(_selectedProfession),
          ),
        if (_query.isNotEmpty)
          Chip(
            avatar: const Icon(Icons.search_rounded,
                size: 16, color: AppTheme.textSecondary),
            label: Text(
              '"$_query"',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            deleteIconColor: AppTheme.textSecondary,
            side: const BorderSide(color: AppTheme.divider),
            backgroundColor: AppTheme.surfaceElevated,
            onDeleted: () {
              _controller.clear();
              setState(() {
                _query = '';
                _expandedProfessions = const [];
              });
              if (_selectedProfession == null && _selectedCity == null) {
                context.go(AppRoutes.home);
              } else {
                context.go(AppRoutes.searchWith(
                  profession: _selectedProfession,
                  city: _selectedCity,
                ));
              }
            },
          ),
        if (_selectedCity != null)
          Chip(
            avatar: const Icon(Icons.location_on_outlined,
                size: 16, color: AppTheme.primary),
            label: Text(
              _selectedCity!,
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            deleteIconColor: AppTheme.textSecondary,
            side: const BorderSide(color: AppTheme.primary),
            backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
            onDeleted: () {
              _cityController.clear();
              setState(() => _selectedCity = null);
              if (_selectedProfession == null && _query.isEmpty) {
                context.go(AppRoutes.home);
              }
            },
          ),
      ],
    );
  }

  Widget _buildResultsPanel(
    BuildContext context,
    AsyncValue<List<Company>> resultsAsync, {
    required bool compact,
    double? deckHeight,
  }) {
    return AsyncValueWidget<List<Company>>(
      value: resultsAsync,
      loadingMessage: 'Buscando profesionales...',
      empty: Center(
        child: Text(
          'No se encontraron resultados',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
      ),
      data: (results) {
        if (compact) {
          final height = deckHeight ?? 400;
          if (height <= 0) return const SizedBox.shrink();
          return CompanyCardDeck(
            companies: results,
            height: height,
            highlightProfession: _selectedProfession,
          );
        }
        final crossAxisCount = ResponsiveLayout.isDesktop(context) ? 3 : 2;

        return LayoutBuilder(
          builder: (context, constraints) {
            final aspectRatio = GalleryPhotoConstants.gridChildAspectRatioFor(
              gridWidth: constraints.maxWidth,
              crossAxisCount: crossAxisCount,
            );

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: aspectRatio,
              ),
              itemCount: results.length,
              itemBuilder: (context, index) {
                final company = results[index];
                return RepaintBoundary(
                  child: SavableCompanyCard(
                    company: company,
                    highlightProfession: _selectedProfession,
                    onTap: () => context.push(
                      AppRoutes.companyDetailPath(company.id),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Móvil / iPad: mismos criterios que Inicio — filtros arriba al scroll, deck grande.
  Widget _buildCompactLayout(
    BuildContext context,
    AsyncValue<List<Company>> resultsAsync,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportH = constraints.maxHeight;
        final pinnedHeaderHeight = _hasActiveFilters
            ? GalleryPhotoConstants.deckSearchPinnedChipsHeight
            : 0.0;
        final deckHeight = GalleryPhotoConstants.deckContentHeightForViewport(
          viewportH,
          pinnedHeaderHeight: pinnedHeaderHeight,
        );

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(child: _buildFiltersForm()),
            if (_hasActiveFilters)
              SliverPersistentHeader(
                pinned: true,
                delegate: PinnedHeaderDelegate(
                  extent: GalleryPhotoConstants.deckSearchPinnedChipsHeight,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildActiveFilterChips(),
                    ),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  SizedBox(
                    height: deckHeight,
                    child: _buildResultsPanel(
                      context,
                      resultsAsync,
                      compact: true,
                      deckHeight: deckHeight,
                    ),
                  ),
                  SizedBox(
                    height: GalleryPhotoConstants.deckScrollTailHeight,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    AsyncValue<List<Company>> resultsAsync,
  ) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFiltersPanel(),
          _buildResultsPanel(context, resultsAsync, compact: false),
        ],
      ),
    );
  }

  String get query => _query;
}
