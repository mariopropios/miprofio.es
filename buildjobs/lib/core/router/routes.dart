class AppRoutes {
  AppRoutes._();

  static const home = '/';
  static const search = '/search';
  static const companyDetail = '/companies/:id';
  static const writeReview = '/companies/:id/review';
  static const profile = '/profile';
  static const savedProfessionals = '/profile/saved';
  static const editProfile = '/profile/edit';
  static const conversations = '/messages';
  static const chat = '/messages/:professionalId';
  static const login = '/login';

  static String chatPath(String professionalId) =>
      '/messages/$professionalId';
  static const register = '/register';
  static const clientRegister = '/register/client';
  static const professionalRegister = '/register/professional';
  static const professionalRegisterSuccess = '/register/professional/success';

  /// Buscar con filtros opcionales: /search?profession=Albañil&q=Madrid&cat=reformas&city=Madrid
  static String searchWith({
    String? profession,
    String? q,
    String? categoryId,
    String? city,
  }) {
    final params = <String, String>{};
    if (profession != null && profession.isNotEmpty) {
      params['profession'] = profession;
    }
    if (q != null && q.isNotEmpty) params['q'] = q;
    if (categoryId != null && categoryId.isNotEmpty) {
      params['cat'] = categoryId;
    }
    if (city != null && city.isNotEmpty) params['city'] = city;
    if (params.isEmpty) return search;
    return Uri(path: search, queryParameters: params).toString();
  }

  static String companyDetailPath(String id) => '/companies/$id';

  static String writeReviewPath(String id) => '/companies/$id/review';

  static String loginWithRedirect(String redirectTo) {
    return Uri(
      path: login,
      queryParameters: {'redirect': redirectTo},
    ).toString();
  }
}
