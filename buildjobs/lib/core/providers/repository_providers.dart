import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/profile_repository.dart';
import '../../features/companies/data/repositories/professional_repository.dart';
import '../../features/reviews/data/review_repository.dart';
import '../../shared/models/professional.dart';
import '../../shared/models/review.dart';
import '../../shared/models/user_profile.dart';

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(client: ref.watch(supabaseClientProvider)),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(client: ref.watch(supabaseClientProvider)),
);

final professionalRepositoryProvider = Provider<ProfessionalRepository>(
  (ref) => ProfessionalRepository(client: ref.watch(supabaseClientProvider)),
);

final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => ReviewRepository(client: ref.watch(supabaseClientProvider)),
);

final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges,
);

final currentUserProvider = Provider<User?>(
  (ref) {
    ref.watch(authStateProvider);
    return ref.watch(authRepositoryProvider).currentUser;
  },
);

final currentProfileProvider = FutureProvider<UserProfile?>(
  (ref) async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return null;
    return ref.watch(profileRepositoryProvider).getProfile(user.id);
  },
);

final currentProfessionalProfileProvider = FutureProvider<Professional?>(
  (ref) async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return null;
    return ref
        .read(professionalRepositoryProvider)
        .getProfessionalForUser(user.id);
  },
);

/// Indica si el usuario logueado es profesional y qué id usar en la vista pública.
final currentUserProfessionalViewProvider =
    FutureProvider<
        ({bool isProfessional, bool hasListing, String professionalId})>(
  (ref) async {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return (
        isProfessional: false,
        hasListing: false,
        professionalId: '',
      );
    }

    final profile = await ref.read(currentProfileProvider.future);
    final listing =
        await ref.read(professionalRepositoryProvider).getProfessionalForUser(
              user.id,
            );

    final metaRole = user.userMetadata?['role']?.toString();
    final isProfessional = listing != null ||
        profile?.role == 'professional' ||
        metaRole == 'professional';

    return (
      isProfessional: isProfessional,
      hasListing: listing != null,
      professionalId: listing?.id ?? user.id,
    );
  },
);

class ProfessionalSearchParams {
  const ProfessionalSearchParams({
    this.query,
    this.profession,
    this.categoryId,
    this.city,
    this.expandedProfessions = const [],
    this.limit = 20,
  });

  final String? query;
  final String? profession;
  /// ID de categoría del catálogo (ej. 'reformas'). Filtra por service_categories.
  final String? categoryId;
  /// Ciudad para filtrar resultados.
  final String? city;
  /// Nombres de profesión extra derivados del texto libre (búsqueda semántica).
  final List<String> expandedProfessions;
  final int limit;

  /// Alias de compatibilidad
  String? get category => profession;

  @override
  bool operator ==(Object other) =>
      other is ProfessionalSearchParams &&
      other.query == query &&
      other.profession == profession &&
      other.categoryId == categoryId &&
      other.city == city &&
      _listEquals(other.expandedProfessions, expandedProfessions) &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(
        query,
        profession,
        categoryId,
        city,
        Object.hashAll(expandedProfessions),
        limit,
      );

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

final professionalsProvider =
    FutureProvider.family<List<Professional>, ProfessionalSearchParams>(
  (ref, params) {
    return ref.watch(professionalRepositoryProvider).getProfessionals(
          profession: params.profession,
          categoryId: params.categoryId,
          city: params.city,
          query: params.query,
          expandedProfessions: params.expandedProfessions,
          limit: params.limit,
        );
  },
);

final featuredProfessionalsProvider = FutureProvider<List<Professional>>(
  (ref) {
    // Mantener en caché mientras la app esté en memoria: evita re-fetch al
    // navegar de vuelta a Home.
    ref.keepAlive();
    return ref.watch(professionalRepositoryProvider).getProfessionals(limit: 6);
  },
);

final professionalDetailProvider =
    FutureProvider.family<Professional?, String>(
  (ref, id) {
    ref.keepAlive();
    return ref.watch(professionalRepositoryProvider).getProfessionalById(id);
  },
);

final professionalReviewsProvider =
    FutureProvider.family<List<Review>, String>(
  (ref, professionalId) => ref
      .watch(reviewRepositoryProvider)
      .getReviewsByProfessional(professionalId),
);
