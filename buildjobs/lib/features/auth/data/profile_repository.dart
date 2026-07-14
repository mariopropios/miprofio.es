import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/user_profile.dart';

class ProfileRepository {
  ProfileRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<UserProfile?> getProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (data == null) return null;
    return UserProfile.fromJson(data);
  }

  Future<void> markAsProfessional({
    required String userId,
    required String email,
    required String fullName,
    required String city,
    String? avatarUrl,
  }) async {
    await _client.from('profiles').update({
      'full_name': fullName,
      'role': 'professional',
      'city': city,
      'email': email,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    }).eq('id', userId);
  }

  Future<void> updateAvatarUrl({
    required String userId,
    required String avatarUrl,
  }) async {
    await _client.from('profiles').update({
      'avatar_url': avatarUrl,
    }).eq('id', userId);
  }

  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? city,
    String? avatarUrl,
  }) async {
    final payload = <String, dynamic>{};
    if (fullName != null) payload['full_name'] = fullName;
    if (city != null) payload['city'] = city;
    if (avatarUrl != null) payload['avatar_url'] = avatarUrl;
    if (payload.isEmpty) return;
    await _client.from('profiles').update(payload).eq('id', userId);
  }

  Future<void> updateMessageEmailNotifications({
    required String userId,
    required bool enabled,
  }) async {
    await _client.from('profiles').update({
      'message_email_notifications': enabled,
    }).eq('id', userId);
  }
}
