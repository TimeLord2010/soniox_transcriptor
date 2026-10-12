import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soniox_transcriptor/repositories/profile_repository.dart';

class ContextRepository {
  ContextRepository(this.profileId);

  final String profileId;

  SharedPreferences get _sp => GetIt.I.get<SharedPreferences>();

  String get _key => ProfileRepository.keyFor(profileId, 'context_text');

  String getContext() {
    return _sp.getString(_key) ?? '';
  }

  Future<void> setContext(String text) async {
    await _sp.setString(_key, text);
  }
}
