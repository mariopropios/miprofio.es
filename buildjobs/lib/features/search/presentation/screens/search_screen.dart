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

  String? _nullableRouteParam(String? value) =>
      (value != null && value.isNotEmpty) ? value : null;

  void _navigateSearch({
    String? profession,
    String? categoryId,
    String? query,
    String? city,
  }) {
    final normalizedQuery = _nullableRouteParam(query);
    final normalizedCity = _nullableRouteParam(city);
    final normalizedProfession = _nullableRouteParam(profession);

    if (normalizedProfession == null &&
        normalizedQuery == null &&
        normalizedCity == null) {
      context.go(AppRoutes.home);
      return;
    }

    context.go(
      AppRoutes.searchWith(
        profession: normalizedProfession,
        categoryId: normalizedProfession != null ? categoryId : null,
        q: normalizedQuery,
        city: normalizedCity,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _syncFromRouteParams();
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialProfession != widget.initialProfession ||
        oldWidget.initialCategoryId != widget.initialCategoryId ||
        oldWidget.initialCity != widget.initialCity ||
        oldWidget.initialQuery != widget.initialQuery) {
      _syncFromRouteParams();
    }
  }

  void _syncFromRouteParams() {
    final profession = _nullableRouteParam(widget.initialProfession);
    final categoryId = widget.initialCategoryId;
    final city = _nullableRouteParam(widget.initialCity);
    final query = _nullableRouteParam(widget.initialQuery) ?? '';

    if (_selectedProfession == profession &&
        _selectedCategoryId == (profession != null ? categoryId : null) &&
        _selectedCity == city &&
        _query == query) {
      return;
    }

    setState(() {
      _selectedProfession = profession;
      _selectedCategoryId = profession != null ? categoryId : null;
      _selectedCity = city;

      if (query.isNotEmpty) {
        _query = query;
        _expandedProfessions =
            ProfessionCatalog.relatedProfessionNames(query);
      } else {
        _query = '';
        _expandedProfessions = const [];
      }
    });

    _controller.text = _query;
    _cityController.text = _selectedCity ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _applySuggestion(SearchSuggestion suggestion) {
    if (suggestion.isProfession) {
      _navigateSearch(
        profession: suggestion.label,
        categoryId: suggestion.categoryId,
        city: _selectedCity,
      );
      return;
    }

    final name = suggestion.label.trim();
    _navigateSearch(
      query: name,
      city: _selectedCity,
    );
  }

  void _search() {
    _navigateSearch(
      profession: _selectedProfession,
      categoryId: _selectedCategoryId,
      query: _controller.text.trim(),
      city: _selectedCity,
    );
  }

  void _selectProfession(String profession, [String? categoryId]) {
    final togglingOff = _selectedProfession == profession;
    _navigateSearch(
      profession: togglingOff ? null : profession,
      categoryId: togglingOff ? null : categoryId,
      query: _query.isEmpty ? null : _query,
      city: _selectedCity,
    );
  }

  void _applyCityFilter(String? city) {
    final normalized = city?.trim();
    _navigateSearch(
      profession: _selectedProfession,
      categoryId: _selectedCategoryId,
      query: _query.isEmpty ? null : _query,
      city: (normalized == null || normalized.isEmpty) ? null : normalized,
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
    return _buildFiltersForm();
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
          preservedCity: _selectedCity,
          preservedQuery: _query.isEmpty ? null : _query,
        ),
        if (_hasActiveFilters) ...[
          const SizedBox(height: 12),
          _buildActiveFilterChips(),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildActiveFilterChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (_selectedProfession != null)
          _filterChip(
            icon: Icons.work_outline_rounded,
            label: _selectedProfession!,
            iconColor: AppTheme.textSecondary,
            labelColor: AppTheme.textPrimary,
            borderColor: AppTheme.divider,
            backgroundColor: AppTheme.surfaceElevated,
            onDeleted: () {
              final profession = _selectedProfession;
              if (profession != null) {
                _selectProfession(profession, _selectedCategoryId);
              }
            },
          ),
        if (_query.isNotEmpty)
          _filterChip(
            icon: Icons.search_rounded,
            label: '"$_query"',
            iconColor: AppTheme.textSecondary,
            labelColor: AppTheme.textPrimary,
            borderColor: AppTheme.divider,
            backgroundColor: AppTheme.surfaceElevated,
            onDeleted: () {
              _controller.clear();
              _navigateSearch(
                profession: _selectedProfession,
                categoryId: _selectedCategoryId,
                city: _selectedCity,
              );
            },
          ),
        if (_selectedCity != null)
          _filterChip(
            icon: Icons.location_on_outlined,
            label: _selectedCity!,
            iconColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            borderColor: AppTheme.primary,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
            onDeleted: () {
              _cityController.clear();
              _navigateSearch(
                profession: _selectedProfession,
                categoryId: _selectedCategoryId,
                query: _query.isEmpty ? null : _query,
              );
            },
          ),
      ],
    );
  }

  Widget _filterChip({
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color labelColor,
    required Color borderColor,
    required Color backgroundColor,
    required VoidCallback onDeleted,
  }) {
    return Chip(
      avatar: Icon(icon, size: 16, color: iconColor),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: labelColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      deleteIconColor: AppTheme.textSecondary,
      side: BorderSide(color: borderColor),
      backgroundColor: backgroundColor,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onDeleted: onDeleted,
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
        final deckHeight = GalleryPhotoConstants.deckContentHeightForViewport(
          viewportH,
          pinnedHeaderHeight: 0,
        );

        return CustomScrollView(
          physics: GalleryPhotoConstants.mobileOuterScrollPhysics,
          slivers: [
            SliverToBoxAdapter(child: _buildFiltersForm()),
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
          const SizedBox(height: 24),
          _buildResultsPanel(context, resultsAsync, compact: false),
        ],
      ),
    );
  }

  String get query => _query;
}
