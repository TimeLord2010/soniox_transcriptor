import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soniox_transcriptor/models/languages.dart';
import 'package:soniox_transcriptor/repositories/context_repository.dart';
import 'package:soniox_transcriptor/repositories/languages_repository.dart';
import 'package:soniox_transcriptor/repositories/terms_repository.dart';

final contextProvider = StateNotifierProvider<ContextNotifier, String>(
  (ref) => ContextNotifier(),
);

final languagesProvider =
    StateNotifierProvider<LanguagesNotifier, Set<Language>>(
      (ref) => LanguagesNotifier(),
    );

final termsProvider = StateNotifierProvider<TermsNotifier, List<String>>(
  (ref) => TermsNotifier(),
);

class ContextNotifier extends StateNotifier<String> {
  final _repo = ContextRepository();

  ContextNotifier() : super('') {
    _load();
  }

  void _load() {
    final context = _repo.getContext();
    state = context;
  }

  Future<void> setContext(String text) async {
    await _repo.setContext(text);
    state = text;
  }
}

class LanguagesNotifier extends StateNotifier<Set<Language>> {
  final _repo = LanguagesRepository();

  LanguagesNotifier() : super({.pt}) {
    _load();
  }

  Future<void> _load() async {
    state = await _repo.getLanguages();
  }

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
  final _repo = TermsRepository();

  TermsNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final terms = await _repo.getAllTerms();
    state = terms;
  }

  Future<void> addTerm(String term) async {
    await _repo.addTerm(term);
    await _load();
  }

  Future<void> deleteTerm(String term) async {
    await _repo.deleteTerm(term);
    await _load();
  }
}
