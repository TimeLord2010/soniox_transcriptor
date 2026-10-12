import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soniox_transcriptor/models/languages.dart';
import 'package:soniox_transcriptor/repositories/profile_repository.dart';

class LanguagesRepository {
  LanguagesRepository(this.profileId);

  final String profileId;

  SharedPreferences get _sp => GetIt.I.get<SharedPreferences>();

  String get _languagesKey => ProfileRepository.keyFor(profileId, 'languages');

  Set<Language> getLanguages() {
    final stored = _sp.getStringList(_languagesKey);
    if (stored == null) return {Language.pt};
    return stored.map(Language.values.byName).toSet();
  }

  Future<void> setLanguages(Set<Language> languages) async {
    await _sp.setStringList(
      _languagesKey,
      languages.map((l) => l.name).toList(),
    );
  }
}
