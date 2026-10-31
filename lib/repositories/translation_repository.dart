import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soniox_transcriptor/models/languages.dart';
import 'package:soniox_transcriptor/repositories/profile_repository.dart';

/// Preferência de sessão: quando tem língua alvo, o Soniox traduz a fala para
/// ela ao vivo (`translation` one-way no config da sessão). Sem valor salvo, a
/// tradução está desligada — não existe "traduzir sem alvo".
class TranslationRepository {
  TranslationRepository(this.profileId);

  final String profileId;

  static const _key = 'translation_target';

  SharedPreferences get _sp => GetIt.I.get<SharedPreferences>();

  String get _storageKey => ProfileRepository.keyFor(profileId, _key);

  /// Língua alvo salva, ou `null` quando a tradução está desligada.
  Language? getTarget() {
    final stored = _sp.getString(_storageKey);
    if (stored == null) return null;
    // Nome desconhecido (versão antiga, valor corrompido) equivale a desligado
    // em vez de estourar na abertura da tela.
    for (final language in Language.values) {
      if (language.name == stored) return language;
    }
    return null;
  }

  Future<void> setTarget(Language target) async {
    await _sp.setString(_storageKey, target.name);
  }

  Future<void> clear() async {
    await _sp.remove(_storageKey);
  }
}
