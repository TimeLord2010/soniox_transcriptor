import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soniox_transcriptor/repositories/profile_repository.dart';

class LocalStorageModule {
  static const _apiKeyKey = 'api_key';
  static const _selectedDeviceKey = 'selected_input_device_label';

  /// Retrieves the API key saved for [profileId], or null if none is stored.
  static String? getApiKey(String profileId) {
    final prefs = GetIt.I.get<SharedPreferences>();
    return prefs.getString(ProfileRepository.keyFor(profileId, _apiKeyKey));
  }

  /// Saves the API key. Passing null removes the stored key.
  static Future<void> setApiKey(String profileId, String? key) async {
    final prefs = GetIt.I.get<SharedPreferences>();
    final storageKey = ProfileRepository.keyFor(profileId, _apiKeyKey);
    if (key == null) {
      await prefs.remove(storageKey);
    } else {
      await prefs.setString(storageKey, key);
    }
  }

  /// Retrieves the input device label saved for [profileId], or null.
  static String? getSelectedDeviceLabel(String profileId) {
    final prefs = GetIt.I.get<SharedPreferences>();
    return prefs.getString(
      ProfileRepository.keyFor(profileId, _selectedDeviceKey),
    );
  }

  /// Saves the input device label.
  static Future<void> setSelectedDeviceLabel(
    String profileId,
    String label,
  ) async {
    final prefs = GetIt.I.get<SharedPreferences>();
    await prefs.setString(
      ProfileRepository.keyFor(profileId, _selectedDeviceKey),
      label,
    );
  }
}
