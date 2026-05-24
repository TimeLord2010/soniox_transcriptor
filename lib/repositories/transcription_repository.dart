import 'package:get_it/get_it.dart';
import 'package:sqlite3/sqlite3.dart';

import '../models/transcription_record.dart';

class TranscriptionRepository {
  static const _maxRecords = 100;

  Database get _db => GetIt.I.get<Database>();

  void insert(TranscriptionRecord record) {
    final stmt = _db.prepare('''
      INSERT INTO transcriptions (final_text, non_final_text, created_at)
      VALUES (?, ?, ?)
    ''');
    stmt.execute([
      record.finalText,
      record.nonFinalText,
      record.createdAt.millisecondsSinceEpoch,
    ]);
    stmt.close();

    _enforceMaxRecords();
  }

  void _enforceMaxRecords() {
    final count = _getCount();
    if (count > _maxRecords) {
      final toDelete = count - _maxRecords;
      final stmt = _db.prepare('''
        DELETE FROM transcriptions
        WHERE id IN (
          SELECT id FROM transcriptions
          ORDER BY created_at ASC
          LIMIT ?
        )
      ''');
      stmt.execute([toDelete]);
      stmt.close();
    }
  }

  int _getCount() {
    final result = _db.select('SELECT COUNT(*) as count FROM transcriptions');
    return result.first['count'] as int;
  }

  List<TranscriptionRecord> getAll() {
    final result = _db.select('''
      SELECT * FROM transcriptions
      ORDER BY created_at DESC
    ''');
    return result.map(TranscriptionRecord.fromRow).toList();
  }

  void delete(int id) {
    final stmt = _db.prepare('DELETE FROM transcriptions WHERE id = ?');
    stmt.execute([id]);
    stmt.close();
  }

  void deleteAll() {
    _db.execute('DELETE FROM transcriptions');
  }
}
