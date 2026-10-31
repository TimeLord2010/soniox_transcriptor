import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../models/transcription_record.dart';
import 'history_store.dart';

/// Histórico em SQLite (macOS/Android). Só é compilado onde `dart:io` e
/// `dart:ffi` existem — no web o `history_store_factory` escolhe o store em
/// `SharedPreferences`.
class SqliteHistoryStore implements HistoryStore {
  static const schema = '''
    CREATE TABLE IF NOT EXISTS transcriptions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      final_text TEXT NOT NULL,
      non_final_text TEXT NOT NULL,
      created_at INTEGER NOT NULL
    )
  ''';

  /// Banco em arquivo no diretório de suporte do app, como o app sempre fez.
  static Future<SqliteHistoryStore> open() async {
    final dir = await getApplicationSupportDirectory();
    final db = sqlite3.open(path.join(dir.path, 'soniox_transcriptor.db'));
    return SqliteHistoryStore(db);
  }

  /// Aceita um banco já aberto (testes usam `sqlite3.openInMemory()`).
  SqliteHistoryStore(this._db) {
    _db.execute(schema);
  }

  final Database _db;

  @override
  Future<void> load() async {
    // Abrir o banco já expõe o histórico; nada para carregar.
  }

  @override
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
  }

  @override
  List<TranscriptionRecord> getAll() {
    final result = _db.select('''
      SELECT * FROM transcriptions
      ORDER BY created_at DESC, id DESC
    ''');
    return result.map(TranscriptionRecord.fromMap).toList();
  }

  @override
  void delete(int id) {
    final stmt = _db.prepare('DELETE FROM transcriptions WHERE id = ?');
    stmt.execute([id]);
    stmt.close();
  }

  @override
  void deleteOldest(int count) {
    if (count <= 0) return;
    final stmt = _db.prepare('''
      DELETE FROM transcriptions
      WHERE id IN (
        SELECT id FROM transcriptions
        ORDER BY created_at ASC, id ASC
        LIMIT ?
      )
    ''');
    stmt.execute([count]);
    stmt.close();
  }

  @override
  void deleteAll() {
    _db.execute('DELETE FROM transcriptions');
  }
}

/// Entrada do `history_store_factory` nesta plataforma.
Future<HistoryStore> openHistoryStore() => SqliteHistoryStore.open();
