import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/profession_catalog.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/company.dart';
import '../../../../shared/widgets/async_value_widget.dart';
import '../../../../shared/widgets/company_card.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../home/presentation/widgets/profession_filter_section.dart';
import '../widgets/location_filter_sheet.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({
    super.key,
    this.initialProfession,
    this.initialQuery,
    this.initialCategoryId,
  });

  final String? initialProfession;
  final String? initialQuery;
  final String? initialCategoryId;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String? _selectedProfession;
  String? _selectedCategoryId;
  String? _selectedCity;
  String _query = '';
  List<String> _expandedProfessions = const [];

  @override
  void initState() {
    super.initState();
    _selectedProfession = widget.initialProfession;
    _selectedCategoryId = widget.initialCategoryId;
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
    super.dispose();
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
      AppRoutes.searchWith(profession: _selectedProfession, q: query),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Buscar')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(professionalsProvider(params));
          await ref.read(professionalsProvider(params).future);
        },
        child: ResponsiveContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Nombre, oficio...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: GestureDetector(
                          onTap: _search,
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
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botón de ubicación
                  Tooltip(
                    message: 'Filtrar por ciudad',
                    child: GestureDetector(
                      onTap: () async {
                        final city = await LocationFilterSheet.show(
                          context,
                          current: _selectedCity,
                        );
                        if (city != null) {
                          setState(() =>
                              _selectedCity = city.isEmpty ? null : city);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 52,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: _selectedCity != null
                              ? AppTheme.primary.withValues(alpha: 0.15)
                              : AppTheme.surfaceElevated,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(
                            color: _selectedCity != null
                                ? AppTheme.primary
                                : AppTheme.divider,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 18,
                              color: _selectedCity != null
                                  ? AppTheme.primary
                                  : AppTheme.textSecondary,
                            ),
                            if (_selectedCity != null) ...[
                              const SizedBox(width: 4),
                              Text(
                                _selectedCity!,
                                style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ProfessionFilterSection(
                selectedProfession: _selectedProfession,
                onProfessionTap: (name, catId) =>
                    _selectProfession(name, catId),
              ),
              if (_selectedProfession != null ||
                  _query.isNotEmpty ||
                  _selectedCity != null) ...[
                const SizedBox(height: 12),
                Wrap(
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
                          '"$query"',
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
                          if (_selectedProfession == null &&
                              _selectedCity == null) {
                            context.go(AppRoutes.home);
                          } else {
                            context.go(AppRoutes.searchWith(
                              profession: _selectedProfession,
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
                        backgroundColor:
                            AppTheme.primary.withValues(alpha: 0.1),
                        onDeleted: () {
                          setState(() => _selectedCity = null);
                          if (_selectedProfession == null && _query.isEmpty) {
                            context.go(AppRoutes.home);
                          }
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Expanded(
                child: AsyncValueWidget<List<Company>>(
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
                    if (ResponsiveLayout.isMobile(context)) {
                      return ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: results.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final company = results[index];
                          return CompanyCard(
                            company: company,
                            onTap: () => context.push(
                              AppRoutes.companyDetailPath(company.id),
                            ),
                          );
                        },
                      );
                    }
                    return GridView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:
                            ResponsiveLayout.isDesktop(context) ? 3 : 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio:
                            ResponsiveLayout.isDesktop(context) ? 0.78 : 0.82,
                      ),
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final company = results[index];
                        return CompanyCard(
                          company: company,
                          onTap: () => context.push(
                            AppRoutes.companyDetailPath(company.id),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get query => _query;
}
