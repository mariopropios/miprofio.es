import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/professional.dart';

class SavedProfessionalRepository {
  SavedProfessionalRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  Future<void> save(String professionalId) async {
    final userId = _userId;
    if (userId == null) throw Exception('Usuario no autenticado');

    try {
      await _client.from('saved_professionals').insert({
        'user_id': userId,
        'professional_id': professionalId,
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') return;
      rethrow;
    }
  }

  Future<void> unsave(String professionalId) async {
    final userId = _userId;
    if (userId == null) throw Exception('Usuario no autenticado');

    await _client
        .from('saved_professionals')
        .delete()
        .eq('user_id', userId)
        .eq('professional_id', professionalId);
  }

  Future<bool> isSaved(String professionalId) async {
    final userId = _userId;
    if (userId == null) return false;

    final row = await _client
        .from('saved_professionals')
        .select('id')
        .eq('user_id', userId)
        .eq('professional_id', professionalId)
        .maybeSingle();

    return row != null;
  }

  Future<Set<String>> getSavedIds() async {
    final userId = _userId;
    if (userId == null) return {};

    try {
      final rows = await _client
          .from('saved_professionals')
          .select('professional_id')
          .eq('user_id', userId);

      return {
        for (final row in rows as List)
          row['professional_id'].toString(),
      };
    } on PostgrestException catch (e) {
      if (e.code == '42P01' || e.code == 'PGRST205') return {};
      rethrow;
    }
  }

  Future<List<Professional>> getSavedProfessionals() async {
    final userId = _userId;
    if (userId == null) return [];

    try {
      final rows = await _client
          .from('saved_professionals')
          .select('professional_id, professionals(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final professionals = <Professional>[];
      for (final row in rows as List) {
        final nested = row['professionals'];
        if (nested is Map<String, dynamic>) {
          professionals.add(Professional.fromJson(nested));
        }
      }
      return professionals;
    } on PostgrestException catch (e) {
      if (e.code == '42P01' || e.code == 'PGRST205') return [];
      rethrow;
    }
  }
}
