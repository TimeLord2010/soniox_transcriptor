import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageModule {
  static const _apiKeyKey = 'api_key';
  static const _selectedDeviceKey = 'selected_input_device_label';

  /// Retrieves the saved API key, or null if none is stored.
  static String? getApiKey() {
    final prefs = GetIt.I.get<SharedPreferences>();
    return prefs.getString(_apiKeyKey);
  }

  /// Saves the API key. Passing null removes the stored key.
  static Future<void> setApiKey(String? key) async {
    final prefs = GetIt.I.get<SharedPreferences>();
    if (key == null) {
      await prefs.remove(_apiKeyKey);
    } else {
      await prefs.setString(_apiKeyKey, key);
    }
  }

  /// Retrieves the saved input device label, or null if none is stored.
  static String? getSelectedDeviceLabel() {
    final prefs = GetIt.I.get<SharedPreferences>();
    return prefs.getString(_selectedDeviceKey);
  }

  /// Saves the input device label.
  static Future<void> setSelectedDeviceLabel(String label) async {
    final prefs = GetIt.I.get<SharedPreferences>();
    await prefs.setString(_selectedDeviceKey, label);
  }
}
