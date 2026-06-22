import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:soniox_transcriptor/models/languages.dart';
import 'package:soniox_transcriptor/repositories/terms_repository.dart';

final contextText = StateProvider<String>((_) => '');

final languagesProvider = StateProvider<Set<Language>>((_) => {.pt});

final termsProvider = StateNotifierProvider<TermsNotifier, List<String>>(
  (ref) => TermsNotifier(),
);

class TermsNotifier extends StateNotifier<List<String>> {
  final TermsRepository _repo = GetIt.I.get<TermsRepository>();

  TermsNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final terms = await _repo.getAllTerms();
    state = terms;
  }

  Future<void> addTerm(String term) async {
    _repo.addTerm(term);
    await _load();
  }

  Future<void> deleteTerm(String term) async {
    _repo.deleteTerm(term);
    await _load();
  }
}
