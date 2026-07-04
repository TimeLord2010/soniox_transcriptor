import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TermsRepository {
  static const _termsKey = 'terms';

  SharedPreferences get _sp => GetIt.I.get<SharedPreferences>();

  Future<List<String>> getAllTerms() async {
    return _sp.getStringList(_termsKey) ?? [];
  }

  Future<void> addTerm(String term) async {
    final terms = _sp.getStringList(_termsKey) ?? [];
    if (terms.contains(term)) return;
    final updated = [term, ...terms];
    await _sp.setStringList(_termsKey, updated);
  }

  Future<void> deleteTerm(String term) async {
    final terms = _sp.getStringList(_termsKey) ?? [];
    final updated = terms.where((t) => t != term).toList();
    await _sp.setStringList(_termsKey, updated);
  }
}
