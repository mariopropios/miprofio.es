import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/services/profile_photo_storage.dart';
import 'pending_client_draft.dart';
import 'pending_professional_draft.dart';

/// Guarda el borrador en Supabase (sobrevive Gmail → Safari / otro navegador).
Future<void> saveSignupDraftToServer({
  required String userId,
  required String kind,
  required Map<String, dynamic> payload,
  Uint8List? avatarBytes,
  String avatarMime = 'image/jpeg',
  List<Uint8List> galleryBytes = const [],
  List<String> galleryMimes = const [],
}) async {
  final client = Supabase.instance.client;
  final body = <String, dynamic>{
    'userId': userId,
    'kind': kind,
    'payload': payload,
  };
  if (galleryBytes.isNotEmpty) {
    // Pocas fotos y más pequeñas para no tumbar la Edge Function.
    final maxGallery = galleryBytes.length.clamp(0, 3);
    final encoded = <String>[];
    final mimes = <String>[];
    for (var i = 0; i < maxGallery; i++) {
      final b64 = base64Encode(galleryBytes[i]);
      if (b64.length > 1500000) continue;
      encoded.add(b64);
      mimes.add(i < galleryMimes.length ? galleryMimes[i] : 'image/jpeg');
    }
    if (encoded.isNotEmpty) {
      body['galleryBase64'] = encoded;
      body['galleryMimes'] = mimes;
    }
  }

  if (avatarBytes != null && avatarBytes.isNotEmpty) {
    final b64 = base64Encode(avatarBytes);
    if (b64.length <= 1500000) {
      body['avatarBase64'] = b64;
      body['avatarMime'] = avatarMime;
    }
  }

  final response = await client.functions.invoke(
    'save-signup-draft',
    body: body,
  );
  if (response.status != 200) {
    final data = response.data;
    final message = data is Map && data['error'] is String
        ? data['error'] as String
        : 'No se pudo guardar el borrador del registro.';
    debugPrint('save-signup-draft failed: $message');
    throw AuthException(message);
  }
}

Future<Map<String, dynamic>?> loadSignupDraftFromServer(String userId) async {
  try {
    final row = await Supabase.instance.client
        .from('signup_drafts')
        .select('kind, payload')
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    final payload = row['payload'];
    if (payload is Map<String, dynamic>) {
      return {
        'kind': row['kind'],
        'payload': payload,
      };
    }
    if (payload is Map) {
      return {
        'kind': row['kind'],
        'payload': Map<String, dynamic>.from(payload),
      };
    }
    return null;
  } catch (e) {
    debugPrint('loadSignupDraftFromServer: $e');
    return null;
  }
}

Future<void> clearSignupDraftFromServer(String userId) async {
  try {
    await Supabase.instance.client
        .from('signup_drafts')
        .delete()
        .eq('user_id', userId);
  } catch (e) {
    debugPrint('clearSignupDraftFromServer: $e');
  }
}

/// Publica la ficha profesional tras confirmar email (sin UI).
Future<void> publishProfessionalRegistration({
  required WidgetRef ref,
  required String userId,
  required String accountEmail,
  required String fullName,
  required String city,
  required String address,
  required double latitude,
  required double longitude,
  required String phoneE164,
  required String bio,
  required List<String> professions,
  required List<String> categories,
  required int serviceRadiusKm,
  Uint8List? avatarBytes,
  String avatarMime = 'image/jpeg',
  List<Uint8List> galleryBytes = const [],
  List<String> galleryMimes = const [],
  String? profilePhotoUrl,
  List<String> galleryPhotoUrls = const [],
}) async {
  const networkTimeout = Duration(seconds: 30);

  var resolvedProfileUrl = profilePhotoUrl;
  var resolvedGalleryUrls = List<String>.from(galleryPhotoUrls);

  final storageClient = ref.read(supabaseClientProvider);
  final storage = ProfilePhotoStorage(storageClient);

  if (resolvedProfileUrl == null && avatarBytes != null) {
    final profileAvatar = XFile.fromData(
      avatarBytes,
      mimeType: avatarMime,
      name: 'avatar.${_extFromMime(avatarMime)}',
    );
    resolvedProfileUrl = await storage
        .uploadImage(profileAvatar, userId)
        .timeout(ProfilePhotoStorage.uploadTimeout);
  }

  if (resolvedGalleryUrls.isEmpty && galleryBytes.isNotEmpty) {
    final galleryImages = <XFile>[];
    for (var i = 0; i < galleryBytes.length; i++) {
      final mime = i < galleryMimes.length ? galleryMimes[i] : 'image/jpeg';
      galleryImages.add(
        XFile.fromData(
          galleryBytes[i],
          mimeType: mime,
          name: 'gallery_$i.${_extFromMime(mime)}',
        ),
      );
    }
    resolvedGalleryUrls = await storage
        .uploadGalleryImages(galleryImages, userId)
        .timeout(ProfilePhotoStorage.uploadTimeout);
  }

  if (resolvedProfileUrl == null && resolvedGalleryUrls.isNotEmpty) {
    resolvedProfileUrl = resolvedGalleryUrls.first;
  }

  await ref
      .read(profileRepositoryProvider)
      .markAsProfessional(
        userId: userId,
        email: accountEmail,
        fullName: fullName,
        city: city,
        avatarUrl: resolvedProfileUrl,
      )
      .timeout(networkTimeout);

  await ref
      .read(professionalRepositoryProvider)
      .createProfessional(
        name: fullName,
        professions: professions,
        description: bio,
        city: city,
        address: address,
        latitude: latitude,
        longitude: longitude,
        phone: phoneE164,
        email: accountEmail,
        profilePhotoUrl: resolvedProfileUrl,
        galleryPhotoUrls: resolvedGalleryUrls,
        userId: userId,
        serviceRadiusKm: serviceRadiusKm,
        serviceCategories: categories,
      )
      .timeout(networkTimeout);

  ref.invalidate(currentUserProvider);
  ref.invalidate(featuredProfessionalsProvider);
  ref.invalidate(currentProfileProvider);
  ref.invalidate(currentProfessionalProfileProvider);
  ref.invalidate(currentUserProfessionalViewProvider);
  ref.invalidate(professionalDetailProvider(userId));
}

Future<void> finalizeClientRegistration({
  required WidgetRef ref,
  required String userId,
  required String fullName,
  Uint8List? avatarBytes,
  String avatarMime = 'image/jpeg',
  String? avatarUrl,
}) async {
  if (avatarUrl != null && avatarUrl.isNotEmpty) {
    await ref.read(profileRepositoryProvider).updateProfile(
          userId: userId,
          fullName: fullName,
          avatarUrl: avatarUrl,
        );
  } else if (avatarBytes != null) {
    final storage = ProfilePhotoStorage(ref.read(supabaseClientProvider));
    final uploaded = await storage
        .uploadBytes(
          rawBytes: avatarBytes,
          userId: userId,
          originalName: 'avatar.${_extFromMime(avatarMime)}',
        )
        .timeout(ProfilePhotoStorage.uploadTimeout);
    await ref.read(profileRepositoryProvider).updateProfile(
          userId: userId,
          fullName: fullName,
          avatarUrl: uploaded,
        );
  } else if (fullName.isNotEmpty) {
    await ref.read(profileRepositoryProvider).updateProfile(
          userId: userId,
          fullName: fullName,
        );
  }

  ref.invalidate(currentProfileProvider);
  ref.invalidate(currentUserProvider);
}

String _extFromMime(String mime) {
  if (mime.contains('png')) return 'png';
  if (mime.contains('webp')) return 'webp';
  if (mime.contains('gif')) return 'gif';
  return 'jpg';
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
}

/// True si hay borrador local pendiente.
bool hasPendingSignupDraft(String userId) {
  final pro = PendingProfessionalDraft.load();
  if (pro != null && pro.userId == userId) return true;
  final client = PendingClientDraft.load();
  if (client != null && client.userId == userId) return true;
  return false;
}

/// Publica en el servidor (service role) — clave cuando Gmail abre otro navegador.
Future<bool> publishPendingSignupViaEdge() async {
  try {
    final response = await Supabase.instance.client.functions.invoke(
      'publish-pending-signup',
      body: <String, dynamic>{},
    );
    final data = response.data;
    if (response.status != 200) {
      final message = data is Map && data['error'] is String
          ? data['error'] as String
          : 'No se pudo publicar el registro.';
      debugPrint('publish-pending-signup failed: $message');
      return false;
    }
    if (data is Map) {
      if (data['alreadyPublished'] == true || data['ok'] == true) {
        if (data['skipped'] == 'no_draft') return false;
        return true;
      }
    }
    return false;
  } catch (e) {
    debugPrint('publishPendingSignupViaEdge: $e');
    return false;
  }
}

/// Publica borrador local y/o servidor tras confirmar email.
Future<bool> finalizePendingSignupDraft({
  required WidgetRef ref,
  required String userId,
  required String accountEmail,
}) async {
  // 1) Local profesional (mismo navegador: fotos en localStorage)
  final proDraft = PendingProfessionalDraft.load();
  if (proDraft != null &&
      proDraft.userId == userId &&
      ((proDraft.avatarBytes != null && proDraft.avatarBytes!.isNotEmpty) ||
          proDraft.galleryBytes.isNotEmpty)) {
    await publishProfessionalRegistration(
      ref: ref,
      userId: userId,
      accountEmail: accountEmail,
      fullName: proDraft.businessName,
      city: proDraft.city,
      address: proDraft.address,
      latitude: proDraft.latitude,
      longitude: proDraft.longitude,
      phoneE164: proDraft.phoneE164,
      bio: proDraft.bio,
      professions: proDraft.professions,
      categories: proDraft.categories,
      serviceRadiusKm: proDraft.serviceRadiusKm,
      avatarBytes: proDraft.avatarBytes,
      avatarMime: proDraft.avatarMime,
      galleryBytes: proDraft.galleryBytes,
      galleryMimes: proDraft.galleryMimes,
    );
    await PendingProfessionalDraft.clear();
    await clearSignupDraftFromServer(userId);
    await _clearPendingMetadata();
    return true;
  }

  // 2) Local cliente con foto
  final clientDraft = PendingClientDraft.load();
  if (clientDraft != null &&
      clientDraft.userId == userId &&
      clientDraft.avatarBytes != null &&
      clientDraft.avatarBytes!.isNotEmpty) {
    await finalizeClientRegistration(
      ref: ref,
      userId: userId,
      fullName: clientDraft.fullName,
      avatarBytes: clientDraft.avatarBytes,
      avatarMime: clientDraft.avatarMime,
    );
    await PendingClientDraft.clear();
    await clearSignupDraftFromServer(userId);
    await _clearPendingMetadata();
    return true;
  }

  // 3) Edge Function (Gmail → otro navegador): lee signup_drafts / metadata
  //    con service role — no depende de RLS del cliente.
  if (await publishPendingSignupViaEdge()) {
    await PendingProfessionalDraft.clear();
    await PendingClientDraft.clear();
    return true;
  }

  // 4) Fallback local texto (mismo navegador, sin fotos / Edge caída)
  if (proDraft != null && proDraft.userId == userId) {
    await publishProfessionalRegistration(
      ref: ref,
      userId: userId,
      accountEmail: accountEmail,
      fullName: proDraft.businessName,
      city: proDraft.city,
      address: proDraft.address,
      latitude: proDraft.latitude,
      longitude: proDraft.longitude,
      phoneE164: proDraft.phoneE164,
      bio: proDraft.bio,
      professions: proDraft.professions,
      categories: proDraft.categories,
      serviceRadiusKm: proDraft.serviceRadiusKm,
      avatarBytes: proDraft.avatarBytes,
      avatarMime: proDraft.avatarMime,
      galleryBytes: proDraft.galleryBytes,
      galleryMimes: proDraft.galleryMimes,
    );
    await PendingProfessionalDraft.clear();
    await clearSignupDraftFromServer(userId);
    await _clearPendingMetadata();
    return true;
  }

  if (clientDraft != null && clientDraft.userId == userId) {
    await finalizeClientRegistration(
      ref: ref,
      userId: userId,
      fullName: clientDraft.fullName,
      avatarBytes: clientDraft.avatarBytes,
      avatarMime: clientDraft.avatarMime,
    );
    await PendingClientDraft.clear();
    await clearSignupDraftFromServer(userId);
    await _clearPendingMetadata();
    return true;
  }

  // 5) Servidor vía cliente (Gmail → otro navegador / sin localStorage)
  final server = await loadSignupDraftFromServer(userId);
  if (server != null) {
    final kind = server['kind']?.toString();
    final payload = server['payload'];
    if (payload is Map<String, dynamic>) {
      if (kind == 'professional') {
        await publishProfessionalRegistration(
          ref: ref,
          userId: userId,
          accountEmail: accountEmail.isNotEmpty
              ? accountEmail
              : (payload['email']?.toString() ?? ''),
          fullName: payload['businessName']?.toString() ??
              payload['fullName']?.toString() ??
              '',
          city: payload['city']?.toString() ?? '',
          address: payload['address']?.toString() ?? '',
          latitude: (payload['latitude'] as num?)?.toDouble() ?? 0,
          longitude: (payload['longitude'] as num?)?.toDouble() ?? 0,
          phoneE164: payload['phoneE164']?.toString() ?? '',
          bio: payload['bio']?.toString() ?? '',
          professions: _stringList(payload['professions']),
          categories: _stringList(payload['categories']),
          serviceRadiusKm: (payload['serviceRadiusKm'] as num?)?.toInt() ?? 25,
          profilePhotoUrl: payload['profilePhotoUrl']?.toString(),
          galleryPhotoUrls: _stringList(payload['galleryPhotoUrls']),
        );
        await clearSignupDraftFromServer(userId);
        await PendingProfessionalDraft.clear();
        await _clearPendingMetadata();
        return true;
      }

      if (kind == 'client') {
        await finalizeClientRegistration(
          ref: ref,
          userId: userId,
          fullName: payload['fullName']?.toString() ?? '',
          avatarUrl: payload['profilePhotoUrl']?.toString() ??
              payload['avatarUrl']?.toString(),
        );
        await clearSignupDraftFromServer(userId);
        await PendingClientDraft.clear();
        await _clearPendingMetadata();
        return true;
      }
    }
  }

  // 4) user_metadata (signUp / Edge Function) — último fallback cross-browser.
  final meta = await _pendingPayloadFromUserMetadata();
  if (meta != null) {
    final kind = meta['kind']?.toString();
    final payload = meta['payload'];
    if (payload is Map<String, dynamic>) {
      if (kind == 'professional') {
        await publishProfessionalRegistration(
          ref: ref,
          userId: userId,
          accountEmail: accountEmail.isNotEmpty
              ? accountEmail
              : (payload['email']?.toString() ?? ''),
          fullName: payload['businessName']?.toString() ??
              payload['fullName']?.toString() ??
              '',
          city: payload['city']?.toString() ?? '',
          address: payload['address']?.toString() ?? '',
          latitude: (payload['latitude'] as num?)?.toDouble() ?? 0,
          longitude: (payload['longitude'] as num?)?.toDouble() ?? 0,
          phoneE164: payload['phoneE164']?.toString() ?? '',
          bio: payload['bio']?.toString() ?? '',
          professions: _stringList(payload['professions']),
          categories: _stringList(payload['categories']),
          serviceRadiusKm: (payload['serviceRadiusKm'] as num?)?.toInt() ?? 25,
          profilePhotoUrl: payload['profilePhotoUrl']?.toString(),
          galleryPhotoUrls: _stringList(payload['galleryPhotoUrls']),
        );
        await clearSignupDraftFromServer(userId);
        await PendingProfessionalDraft.clear();
        await _clearPendingMetadata();
        return true;
      }
      if (kind == 'client') {
        await finalizeClientRegistration(
          ref: ref,
          userId: userId,
          fullName: payload['fullName']?.toString() ?? '',
          avatarUrl: payload['profilePhotoUrl']?.toString(),
        );
        await clearSignupDraftFromServer(userId);
        await PendingClientDraft.clear();
        await _clearPendingMetadata();
        return true;
      }
    }
  }

  return false;
}

Future<Map<String, dynamic>?> _pendingPayloadFromUserMetadata() async {
  try {
    final user = Supabase.instance.client.auth.currentUser;
    final meta = user?.userMetadata;
    if (meta == null) return null;

    final pendingPro = meta['pending_professional'];
    if (pendingPro is Map) {
      return {
        'kind': 'professional',
        'payload': Map<String, dynamic>.from(pendingPro),
      };
    }
    final pendingClient = meta['pending_client'];
    if (pendingClient is Map) {
      return {
        'kind': 'client',
        'payload': Map<String, dynamic>.from(pendingClient),
      };
    }
  } catch (e) {
    debugPrint('_pendingPayloadFromUserMetadata: $e');
  }
  return null;
}

Future<void> _clearPendingMetadata() async {
  try {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final meta = Map<String, dynamic>.from(user.userMetadata ?? {});
    meta.remove('pending_professional');
    meta.remove('pending_client');
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(data: meta),
    );
  } catch (e) {
    debugPrint('_clearPendingMetadata: $e');
  }
}
