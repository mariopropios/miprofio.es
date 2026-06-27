import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';

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
      state = AsyncData(current);
      rethrow;
    }
  }
}

final savedProfessionalIdsProvider =
    AsyncNotifierProvider<SavedProfessionalIdsNotifier, Set<String>>(
  SavedProfessionalIdsNotifier.new,
);
