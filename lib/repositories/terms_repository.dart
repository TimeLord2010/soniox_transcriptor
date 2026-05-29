import 'package:get_it/get_it.dart';
import 'package:sqlite3/sqlite3.dart';

class TermsRepository {
  Database get _db => GetIt.I.get<Database>();

  Future<List<String>> getAllTerms() async {
    final result = _db.select(
      'SELECT term FROM terms ORDER BY created_at DESC',
    );
    return result.map((row) => row['term'] as String).toList();
  }

  void addTerm(String term) {
    final stmt = _db.prepare('''
      INSERT OR IGNORE INTO terms (term, created_at)
      VALUES (?, ?)
    ''');
    stmt.execute([term, DateTime.now().millisecondsSinceEpoch]);
    stmt.close();
  }

  void deleteTerm(String term) {
    final stmt = _db.prepare('DELETE FROM terms WHERE term = ?');
    stmt.execute([term]);
    stmt.close();
  }
}
