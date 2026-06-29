import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';

/// Deltas locales de savedCount por profesional.
/// Ej: {id1: +1, id2: -1} — se suma al savedCount del modelo para la UI.
final savedCountDeltaProvider =
    StateProvider<Map<String, int>>((_) => const {});

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
    _applyDelta(professionalId, wasSaved ? -1 : 1);

    state = AsyncData(next);

    try {
      final repo = ref.read(savedProfessionalRepositoryProvider);
      if (wasSaved) {
        await repo.unsave(professionalId);
      } else {
        await repo.save(professionalId);
      }
      ref.invalidate(savedProfessionalsProvider);
    } catch (e) {
      // Revertir tanto el estado como el delta
      _applyDelta(professionalId, wasSaved ? 1 : -1);
      state = AsyncData(current);
      rethrow;
    }
  }

  void _applyDelta(String professionalId, int delta) {
    final current = Map<String, int>.from(
      ref.read(savedCountDeltaProvider),
    );
    current[professionalId] = (current[professionalId] ?? 0) + delta;
    ref.read(savedCountDeltaProvider.notifier).state = current;
  }
}

final savedProfessionalIdsProvider =
    AsyncNotifierProvider<SavedProfessionalIdsNotifier, Set<String>>(
  SavedProfessionalIdsNotifier.new,
);
