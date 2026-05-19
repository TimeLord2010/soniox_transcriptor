import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalRepository {
  static const _apiKeyKey = 'api_key';

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
}
