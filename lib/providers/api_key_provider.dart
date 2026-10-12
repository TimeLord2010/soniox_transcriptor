import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soniox_transcriptor/modules/local_storage_module.dart';
import 'package:soniox_transcriptor/providers/profile_providers.dart';

/// The Soniox API key of the active profile ('' when unset).
final apiKeyProvider = StateNotifierProvider<ApiKeyNotifier, String>(
  (ref) => ApiKeyNotifier(ref.watch(activeProfileIdProvider)),
);

class ApiKeyNotifier extends StateNotifier<String> {
  final String _profileId;

  ApiKeyNotifier(this._profileId)
    : super(LocalStorageModule.getApiKey(_profileId) ?? '');

  /// Saves [key]. An empty key clears the stored one.
  Future<void> setApiKey(String key) async {
    await LocalStorageModule.setApiKey(_profileId, key.isEmpty ? null : key);
    state = key;
  }
}
