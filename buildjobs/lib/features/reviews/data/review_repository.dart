import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/profile_photo_storage.dart';
import '../../../shared/models/review.dart';

class ReviewRepository {
  ReviewRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Crea una reseña, opcionalmente subiendo fotos al bucket profile-photos.
  Future<void> createReview({
    required String professionalId,
    required int rating,
    required String title,
    required String body,
    List<XFile> photos = const [],
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    // Subir fotos si las hay (ruta: profile-photos/{userId}/{timestamp}.ext)
    final photoUrls = <String>[];
    if (photos.isNotEmpty) {
      final storage = ProfilePhotoStorage(_client);
      final urls = await storage.uploadGalleryImages(photos, userId);
      photoUrls.addAll(urls);
    }

    final basePayload = <String, dynamic>{
      'professional_id': professionalId,
      'user_id': userId,
      'rating': rating,
      'title': title,
      'body': body,
    };

    Future<void> tryInsert(Map<String, dynamic> payload) async {
      try {
        await _client.from('reviews').insert(payload);
      } on PostgrestException catch (e) {
        // Restricción única pendiente de eliminar → usar upsert como fallback
        if (e.code == '23505') {
          await _client.from('reviews').upsert(
            payload,
            onConflict: 'professional_id,user_id',
          );
        }
        // Columna photo_urls pendiente de migración → reintentar sin fotos
        else if (e.message.toLowerCase().contains('photo_urls')) {
          await _client.from('reviews').insert(
            payload..remove('photo_urls'),
          );
        } else {
          rethrow;
        }
      }
    }

    await tryInsert({
      ...basePayload,
      if (photoUrls.isNotEmpty) 'photo_urls': photoUrls,
    });
  }

  /// El profesional responde a una reseña sobre su perfil.
  Future<void> replyToReview({
    required String reviewId,
    required String reply,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    await _client.from('reviews').update({
      'owner_reply': reply.trim(),
      'owner_reply_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', reviewId);
  }

  /// Elimina la respuesta del profesional a una reseña.
  Future<void> deleteReply(String reviewId) async {
    await _client.from('reviews').update({
      'owner_reply': null,
      'owner_reply_at': null,
    }).eq('id', reviewId);
  }

  Future<List<Review>> getReviewsByProfessional(String professionalId) async {
    final data = await _client
        .from('reviews')
        .select('*, profiles(full_name, avatar_url)')
        .eq('professional_id', professionalId)
        .order('created_at', ascending: false);

    final rows = data as List;

    // Obtener los IDs únicos de los reviewers para buscar sus perfiles profesionales
    final userIds = rows
        .map((e) => e['user_id'] as String)
        .toSet()
        .toList();

    // Mapa userId → {id, profile_photo} para reviewers que son profesionales
    final Map<String, Map<String, dynamic>> profMap = {};
    if (userIds.isNotEmpty) {
      final profData = await _client
          .from('professionals')
          .select('owner_id, id, profile_photo')
          .inFilter('owner_id', userIds);
      for (final prof in (profData as List)) {
        profMap[prof['owner_id'] as String] = prof;
      }
    }

    return rows.map((e) {
      final profile = e['profiles'] as Map<String, dynamic>?;
      final prof = profMap[e['user_id'] as String];
      return Review.fromJson({
        ...e,
        'user_name': profile?['full_name'] ?? 'Usuario',
        // Si el reviewer es profesional, preferimos su foto de perfil profesional
        'user_avatar_url': prof?['profile_photo'] ?? profile?['avatar_url'],
        'reviewer_professional_id': prof?['id'],
      });
    }).toList();
  }

  Future<List<Review>> getUserReviews() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final data = await _client
        .from('reviews')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (data as List)
        .map((e) => Review.fromJson({...e, 'user_name': 'Tú'}))
        .toList();
  }
}
