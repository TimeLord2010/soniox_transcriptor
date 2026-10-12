import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soniox_transcriptor/models/profile.dart';
import 'package:soniox_transcriptor/repositories/profile_repository.dart';

final profileRepositoryProvider = Provider((ref) => ProfileRepository());

final activeProfileIdProvider =
    StateNotifierProvider<ActiveProfileNotifier, String>(
      (ref) => ActiveProfileNotifier(ref.read(profileRepositoryProvider)),
    );

final profilesProvider = StateNotifierProvider<ProfilesNotifier, List<Profile>>(
  (ref) => ProfilesNotifier(ref),
);

final activeProfileProvider = Provider<Profile>((ref) {
  final id = ref.watch(activeProfileIdProvider);
  final profiles = ref.watch(profilesProvider);
  return profiles.firstWhere((p) => p.id == id, orElse: () => profiles.first);
});

class ActiveProfileNotifier extends StateNotifier<String> {
  final ProfileRepository _repo;

  ActiveProfileNotifier(this._repo) : super(_repo.getActiveProfileId());

  Future<void> select(String id) async {
    if (id == state) return;
    await _repo.setActiveProfileId(id);
    state = id;
  }
}

class ProfilesNotifier extends StateNotifier<List<Profile>> {
  final Ref _ref;
  ProfileRepository get _repo => _ref.read(profileRepositoryProvider);

  ProfilesNotifier(this._ref)
    : super(_ref.read(profileRepositoryProvider).getProfiles());

  /// Creates a profile with empty settings and returns it.
  Future<Profile> create(String name) async {
    final profile = Profile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
    );
    final updated = [...state, profile];
    await _repo.saveProfiles(updated);
    state = updated;
    return profile;
  }

  Future<void> rename(String id, String name) async {
    final updated = [
      for (final p in state) p.id == id ? p.copyWith(name: name) : p,
    ];
    await _repo.saveProfiles(updated);
    state = updated;
  }

  /// Deletes a profile and its settings. The default profile is kept, and
  /// deleting the active profile switches back to the default one.
  Future<void> delete(String id) async {
    if (id == Profile.defaultId) return;
    if (_ref.read(activeProfileIdProvider) == id) {
      await _ref
          .read(activeProfileIdProvider.notifier)
          .select(Profile.defaultId);
    }
    final updated = state.where((p) => p.id != id).toList();
    await _repo.saveProfiles(updated);
    await _repo.deleteProfileSettings(id);
    state = updated;
  }
}
