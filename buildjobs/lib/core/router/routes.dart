class AppRoutes {
  AppRoutes._();

  static const home = '/';
  static const search = '/search';
  static const companyDetail = '/companies/:id';
  static const writeReview = '/companies/:id/review';
  static const profile = '/profile';
  static const savedProfessionals = '/profile/saved';
  static const editProfile = '/profile/edit';
  static const userProfile = '/users/:userId';
  static const conversations = '/messages';
  static const chat = '/messages/:professionalId';
  static const login = '/login';
  static const forgotPassword = '/login/forgot-password';
  static const resetPassword = '/login/reset-password';

  static String chatPath(String professionalId) =>
      '/messages/$professionalId';

  static String chatPathWith({
    required String professionalId,
    String? conversationId,
    String? name,
    String? photo,
    String? peerUserId,
    bool viewingAsProfessional = false,
  }) {
    final params = <String, String>{};
    if (conversationId != null && conversationId.isNotEmpty) {
      params['conversationId'] = conversationId;
    }
    if (name != null && name.isNotEmpty) params['name'] = name;
    if (photo != null && photo.isNotEmpty) params['photo'] = photo;
    if (peerUserId != null && peerUserId.isNotEmpty) {
      params['peerUserId'] = peerUserId;
    }
    if (viewingAsProfessional) params['asProf'] = '1';
    if (params.isEmpty) return chatPath(professionalId);
    return Uri(path: chatPath(professionalId), queryParameters: params)
        .toString();
  }

  /// `/messages/:id` — chat abierto encima de la lista.
  static bool isChatDetailLocation(String location) {
    final segments = Uri.parse(location).pathSegments;
    return segments.length == 2 && segments.first == 'messages';
  }

  static const register = '/register';
  static const clientRegister = '/register/client';
  static const professionalRegister = '/register/professional';
  static const professionalRegisterSuccess = '/register/professional/success';
  static const emailVerification = '/email-verification';
  static const emailVerifiedQueryKey = 'verified';
  static const emailVerifiedQueryValue = 'email';

  static String profileAfterEmailVerification() {
    return Uri(
      path: profile,
      queryParameters: {emailVerifiedQueryKey: emailVerifiedQueryValue},
    ).toString();
  }

  static bool isProfileEmailVerified(Uri uri) =>
      uri.queryParameters[emailVerifiedQueryKey] == emailVerifiedQueryValue;

  static String emailVerificationPath(String email) =>
      Uri(path: emailVerification, queryParameters: {'email': email})
          .toString();

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

  static String userProfilePath(String userId) => '/users/$userId';

  static String writeReviewPath(String id) => '/companies/$id/review';

  static String loginWithRedirect(String redirectTo) {
    return Uri(
      path: login,
      queryParameters: {'redirect': redirectTo},
    ).toString();
  }

  /// Abre login con el email rellenado (p. ej. cuenta ya existente).
  static String loginWithEmail(
    String email, {
    String? redirect,
    bool existingAccount = false,
  }) {
    return Uri(
      path: login,
      queryParameters: {
        'email': email,
        if (redirect != null && redirect.isNotEmpty) 'redirect': redirect,
        if (existingAccount) 'existing': '1',
      },
    ).toString();
  }

  static String forgotPasswordPath({String? email, String? redirect}) {
    return Uri(
      path: forgotPassword,
      queryParameters: {
        if (email != null && email.isNotEmpty) 'email': email,
        if (redirect != null && redirect.isNotEmpty) 'redirect': redirect,
      },
    ).toString();
  }
}
