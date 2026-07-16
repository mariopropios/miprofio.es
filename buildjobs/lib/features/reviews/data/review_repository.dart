import 'package:flutter/foundation.dart';
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

    Future<Map<String, dynamic>> tryInsert(Map<String, dynamic> payload) async {
      try {
        return await _client
            .from('reviews')
            .insert(payload)
            .select('id')
            .single();
      } on PostgrestException catch (e) {
        if (e.code == '23505') {
          return await _client
              .from('reviews')
              .upsert(
                payload,
                onConflict: 'professional_id,user_id',
              )
              .select('id')
              .single();
        } else if (e.message.toLowerCase().contains('photo_urls')) {
          return await _client
              .from('reviews')
              .insert(payload..remove('photo_urls'))
              .select('id')
              .single();
        } else {
          rethrow;
        }
      }
    }

    final inserted = await tryInsert({
      ...basePayload,
      if (photoUrls.isNotEmpty) 'photo_urls': photoUrls,
    });

    final reviewId = inserted['id'] as String?;
    if (reviewId != null) {
      _notifyReviewCreated(
        reviewId: reviewId,
        professionalId: professionalId,
        reviewerId: userId,
        rating: rating,
        title: title,
        body: body,
      );
    }
  }

  /// El profesional responde a una reseña sobre su perfil.
  Future<void> replyToReview({
    required String reviewId,
    required String reply,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    final updated = await _client
        .from('reviews')
        .update({
          'owner_reply': reply.trim(),
          'owner_reply_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', reviewId)
        .select('id, professional_id, user_id, rating, title')
        .maybeSingle();

    if (updated != null) {
      _notifyReviewReply(
        reviewId: reviewId,
        professionalId: updated['professional_id'] as String,
        reviewerId: updated['user_id'] as String,
        reply: reply.trim(),
        rating: updated['rating'] as int? ?? 0,
        title: updated['title'] as String? ?? '',
      );
    }
  }

  /// Elimina la respuesta del profesional a una reseña.
  Future<void> deleteReply(String reviewId) async {
    await _client.from('reviews').update({
      'owner_reply': null,
      'owner_reply_at': null,
    }).eq('id', reviewId);
  }

  Future<void> _notifyReviewCreated({
    required String reviewId,
    required String professionalId,
    required String reviewerId,
    required int rating,
    required String title,
    required String body,
  }) async {
    try {
      final reviewer = await _client
          .from('profiles')
          .select('full_name')
          .eq('id', reviewerId)
          .maybeSingle();
      final prof = await _client
          .from('professionals')
          .select('name')
          .eq('id', professionalId)
          .maybeSingle();

      await _client.functions.invoke(
        'send-push-notification',
        body: {
          'type': 'review',
          'review_id': reviewId,
          'professional_id': professionalId,
          'reviewer_id': reviewerId,
          'reviewer_name': reviewer?['full_name'] ?? 'Un cliente',
          'professional_name': prof?['name'] ?? 'tu perfil',
          'rating': rating,
          'title': title,
          'body': body,
        },
      );
    } catch (e) {
      debugPrint('[Email] Error notificando reseña: $e');
    }
  }

  Future<void> _notifyReviewReply({
    required String reviewId,
    required String professionalId,
    required String reviewerId,
    required String reply,
    required int rating,
    required String title,
  }) async {
    try {
      final prof = await _client
          .from('professionals')
          .select('name')
          .eq('id', professionalId)
          .maybeSingle();

      await _client.functions.invoke(
        'send-push-notification',
        body: {
          'type': 'review_reply',
          'review_id': reviewId,
          'professional_id': professionalId,
          'reviewer_id': reviewerId,
          'professional_name': prof?['name'] ?? 'Un profesional',
          'reply': reply,
          'rating': rating,
          'title': title,
        },
      );
    } catch (e) {
      debugPrint('[Email] Error notificando respuesta: $e');
    }
  }

  Future<List<Review>> getReviewsByProfessional(String professionalId) async {
    final data = await _client
        .from('reviews')
        .select('*, profiles(full_name, avatar_url)')
        .eq('professional_id', professionalId)
        .order('created_at', ascending: false);

    final rows = data as List;

    final userIds =
        rows.map((e) => e['user_id'] as String).toSet().toList();

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
