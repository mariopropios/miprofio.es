enum SearchSuggestionKind { profession, company }

class SearchSuggestion {
  const SearchSuggestion({
    required this.label,
    required this.kind,
    this.subtitle,
    this.categoryId,
  });

  final String label;
  final SearchSuggestionKind kind;
  final String? subtitle;
  /// Categoría del catálogo cuando [kind] es [SearchSuggestionKind.profession].
  final String? categoryId;

  bool get isProfession => kind == SearchSuggestionKind.profession;
}
