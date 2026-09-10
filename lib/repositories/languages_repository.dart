import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soniox_transcriptor/models/languages.dart';

class LanguagesRepository {
  static const _languagesKey = 'languages';

  SharedPreferences get _sp => GetIt.I.get<SharedPreferences>();

  Future<Set<Language>> getLanguages() async {
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
