import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soniox_transcriptor/models/languages.dart';
import 'package:soniox_transcriptor/providers/profile_providers.dart';
import 'package:soniox_transcriptor/repositories/context_repository.dart';
import 'package:soniox_transcriptor/repositories/diarization_repository.dart';
import 'package:soniox_transcriptor/repositories/languages_repository.dart';
import 'package:soniox_transcriptor/repositories/terms_repository.dart';
import 'package:soniox_transcriptor/repositories/translation_repository.dart';

final contextProvider = StateNotifierProvider<ContextNotifier, String>(
  (ref) => ContextNotifier(ref.watch(activeProfileIdProvider)),
);

final languagesProvider =
    StateNotifierProvider<LanguagesNotifier, Set<Language>>(
      (ref) => LanguagesNotifier(ref.watch(activeProfileIdProvider)),
    );

final termsProvider = StateNotifierProvider<TermsNotifier, List<String>>(
  (ref) => TermsNotifier(ref.watch(activeProfileIdProvider)),
);

final diarizationProvider = StateNotifierProvider<DiarizationNotifier, bool>(
  (ref) => DiarizationNotifier(ref.watch(activeProfileIdProvider)),
);

/// Língua alvo da tradução ao vivo. `null` = tradução desligada: sem alvo não
/// há o que pedir ao Soniox.
final translationProvider =
    StateNotifierProvider<TranslationNotifier, Language?>(
      (ref) => TranslationNotifier(ref.watch(activeProfileIdProvider)),
    );

class ContextNotifier extends StateNotifier<String> {
  final ContextRepository _repo;

  ContextNotifier(String profileId)
    : _repo = ContextRepository(profileId),
      super(ContextRepository(profileId).getContext());

  Future<void> setContext(String text) async {
    await _repo.setContext(text);
    state = text;
  }
}

class LanguagesNotifier extends StateNotifier<Set<Language>> {
  final LanguagesRepository _repo;

  LanguagesNotifier(String profileId)
    : _repo = LanguagesRepository(profileId),
      super(LanguagesRepository(profileId).getLanguages());

  Future<void> toggleLanguage(Language language) async {
    final updated = {...state};
    if (!updated.remove(language)) {
      updated.add(language);
    }
    await _repo.setLanguages(updated);
    state = updated;
  }
}

class TermsNotifier extends StateNotifier<List<String>> {
  final TermsRepository _repo;

  TermsNotifier(String profileId)
    : _repo = TermsRepository(profileId),
      super(TermsRepository(profileId).getAllTerms());

  void _load() {
    state = _repo.getAllTerms();
  }

  Future<void> addTerm(String term) async {
    await _repo.addTerm(term);
    _load();
  }

  Future<void> deleteTerm(String term) async {
    await _repo.deleteTerm(term);
    _load();
  }
}

class DiarizationNotifier extends StateNotifier<bool> {
  final DiarizationRepository _repo;

  DiarizationNotifier(String profileId)
    : _repo = DiarizationRepository(profileId),
      super(DiarizationRepository(profileId).getSpeakerDiarization());

  Future<void> setDiarization(bool enabled) async {
    await _repo.setSpeakerDiarization(enabled);
    state = enabled;
  }
}

/// Liga/desliga a tradução e guarda a língua alvo.
///
/// Ligar sem alvo salvo escolhe um alvo útil de cara (uma língua que NÃO está
/// entre as de entrada — traduzir para a mesma língua que se fala não serve
/// para nada), para a sessão já nascer válida em vez de esperar um segundo
/// clique.
class TranslationNotifier extends StateNotifier<Language?> {
  TranslationNotifier(this.profileId)
    : _repo = TranslationRepository(profileId),
      super(TranslationRepository(profileId).getTarget());

  final String profileId;
  final TranslationRepository _repo;

  Future<void> setEnabled(bool enabled) async {
    if (!enabled) {
      await _repo.clear();
      state = null;
      return;
    }
    final target = state ?? _defaultTarget();
    await _repo.setTarget(target);
    state = target;
  }

  Future<void> setTarget(Language target) async {
    await _repo.setTarget(target);
    state = target;
  }

  /// Primeira língua fora das de entrada; se todas estiverem selecionadas (ou
  /// nenhuma), inglês é o alvo padrão.
  Language _defaultTarget() {
    final spoken = LanguagesRepository(profileId).getLanguages();
    if (spoken.isEmpty) return Language.en;
    for (final language in Language.values) {
      if (!spoken.contains(language)) return language;
    }
    return Language.en;
  }
}
