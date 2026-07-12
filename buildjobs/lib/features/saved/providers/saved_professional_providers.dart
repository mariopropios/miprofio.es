import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/repository_providers.dart';

/// Deltas locales de savedCount por profesional.
/// Ej: {id1: +1, id2: -1} — se suma al savedCount del modelo para la UI.
final savedCountDeltaProvider =
    StateProvider<Map<String, int>>((_) => const {});

/// Conteo efectivo de guardados (base + deltas optimistas / realtime).
final effectiveSavedCountProvider = Provider.family<int, String>((ref, id) {
  ref.watch(professionalSavedCountRealtimeProvider(id));

  final base = ref.watch(professionalDetailProvider(id)).maybeWhen(
        data: (p) => p?.savedCount ?? 0,
        orElse: () => 0,
      );
  final delta = ref.watch(savedCountDeltaProvider)[id] ?? 0;
  return (base + delta).clamp(0, 999999);
});

/// Escucha nuevos guardados en tiempo real y actualiza el contador al instante.
final professionalSavedCountRealtimeProvider =
    Provider.family<void, String>((ref, professionalId) {
  final channel = Supabase.instance.client
      .channel('professional_saves_$professionalId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'saved_professionals',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'professional_id',
          value: professionalId,
        ),
        callback: (payload) {
          final saverId = payload.newRecord['user_id'] as String?;
          final me = Supabase.instance.client.auth.currentUser?.id;
          if (saverId != null && saverId == me) return;
          _applyDelta(ref, professionalId, 1);
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'saved_professionals',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'professional_id',
          value: professionalId,
        ),
        callback: (payload) {
          final saverId = payload.oldRecord['user_id'] as String?;
          final me = Supabase.instance.client.auth.currentUser?.id;
          if (saverId != null && saverId == me) return;
          _applyDelta(ref, professionalId, -1);
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'professionals',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: professionalId,
        ),
        callback: (_) {
          _clearDelta(ref, professionalId);
          ref.invalidate(professionalDetailProvider(professionalId));
        },
      )
      .subscribe();

  ref.onDispose(channel.unsubscribe);
});

void _applyDelta(Ref ref, String professionalId, int delta) {
  final current = Map<String, int>.from(ref.read(savedCountDeltaProvider));
  current[professionalId] = (current[professionalId] ?? 0) + delta;
  ref.read(savedCountDeltaProvider.notifier).state = current;
}

void _clearDelta(Ref ref, String professionalId) {
  final current = Map<String, int>.from(ref.read(savedCountDeltaProvider));
  if (!current.containsKey(professionalId)) return;
  current.remove(professionalId);
  ref.read(savedCountDeltaProvider.notifier).state = current;
}

/// IDs de profesionales guardados con actualización optimista al pulsar el corazón.
class SavedProfessionalIdsNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return {};
    return ref.read(savedProfessionalRepositoryProvider).getSavedIds();
  }

  Future<void> toggle(String professionalId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw Exception('Usuario no autenticado');

    final current = state.valueOrNull ?? {};
    final wasSaved = current.contains(professionalId);
    final next = wasSaved
        ? (Set<String>.from(current)..remove(professionalId))
        : (Set<String>.from(current)..add(professionalId));

    // Actualización optimista del conteo de likes
    _applyDelta(ref, professionalId, wasSaved ? -1 : 1);

    state = AsyncData(next);

    try {
      final repo = ref.read(savedProfessionalRepositoryProvider);
      if (wasSaved) {
        await repo.unsave(professionalId);
      } else {
        await repo.save(professionalId);
      }
      ref.invalidate(savedProfessionalsProvider);
      ref.invalidate(professionalDetailProvider(professionalId));
      await ref.read(professionalDetailProvider(professionalId).future);
      _clearDelta(ref, professionalId);
    } catch (e) {
      // Revertir tanto el estado como el delta
      _applyDelta(ref, professionalId, wasSaved ? 1 : -1);
      state = AsyncData(current);
      rethrow;
    }
  }
}

final savedProfessionalIdsProvider =
    AsyncNotifierProvider<SavedProfessionalIdsNotifier, Set<String>>(
  SavedProfessionalIdsNotifier.new,
);
