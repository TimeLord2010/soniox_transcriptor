import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../models/history_summary.dart';
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
      created_at INTEGER NOT NULL,
      audio_duration_ms INTEGER
    )
  ''';

  /// Linha única (id = 1) com os totais do histórico, atualizada a cada
  /// mudança.
  static const totalsSchema = '''
    CREATE TABLE IF NOT EXISTS history_totals (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      total_chars INTEGER NOT NULL,
      audio_ms INTEGER NOT NULL,
      with_duration INTEGER NOT NULL,
      without_duration INTEGER NOT NULL
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
    // Bancos criados antes do campo de duração não têm a coluna.
    final columns = _db
        .select('PRAGMA table_info(transcriptions)')
        .map((row) => row['name'])
        .toList();
    if (!columns.contains('audio_duration_ms')) {
      _db.execute(
        'ALTER TABLE transcriptions ADD COLUMN audio_duration_ms INTEGER',
      );
    }
    _db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transcriptions_created_at '
      'ON transcriptions (created_at)',
    );
    _db.execute(totalsSchema);
    _totals = _readTotals() ?? _migrateTotals();
  }

  final Database _db;
  late HistoryTotals _totals;

  @override
  HistoryTotals get totals => _totals;

  HistoryTotals? _readTotals() {
    final rows = _db.select('SELECT * FROM history_totals WHERE id = 1');
    if (rows.isEmpty) return null;
    final row = rows.single;
    return HistoryTotals(
      totalChars: row['total_chars'] as int,
      audioMs: row['audio_ms'] as int,
      recordsWithDuration: row['with_duration'] as int,
      recordsWithoutDuration: row['without_duration'] as int,
    );
  }

  /// Primeira abertura depois da atualização: calcula uma vez a partir dos
  /// registros que já existiam e grava; daí em diante só incremental.
  HistoryTotals _migrateTotals() {
    final totals = HistoryTotals.fromRecords(
      _db
          .select('SELECT * FROM transcriptions')
          .map(TranscriptionRecord.fromMap),
    );
    _saveTotals(totals);
    return totals;
  }

  void _saveTotals(HistoryTotals totals) {
    _totals = totals;
    final stmt = _db.prepare('''
      INSERT OR REPLACE INTO history_totals
        (id, total_chars, audio_ms, with_duration, without_duration)
      VALUES (1, ?, ?, ?, ?)
    ''');
    stmt.execute([
      totals.totalChars,
      totals.audioMs,
      totals.recordsWithDuration,
      totals.recordsWithoutDuration,
    ]);
    stmt.close();
  }

  @override
  Future<void> load() async {
    // Abrir o banco já expõe o histórico; nada para carregar.
  }

  @override
  void insert(TranscriptionRecord record) {
    final stmt = _db.prepare('''
      INSERT INTO transcriptions (final_text, non_final_text, created_at, audio_duration_ms)
      VALUES (?, ?, ?, ?)
    ''');
    stmt.execute([
      record.finalText,
      record.nonFinalText,
      record.createdAt.millisecondsSinceEpoch,
      record.audioDurationMs,
    ]);
    stmt.close();
    _saveTotals(_totals.plus(record));
  }

  @override
  List<TranscriptionRecord> page({required int limit, int offset = 0}) {
    final result = _db.select(
      'SELECT * FROM transcriptions ORDER BY created_at DESC, id DESC '
      'LIMIT ? OFFSET ?',
      [limit, offset],
    );
    return result.map(TranscriptionRecord.fromMap).toList();
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
    final rows = _db.select('SELECT * FROM transcriptions WHERE id = ?', [id]);
    if (rows.isEmpty) return;
    final stmt = _db.prepare('DELETE FROM transcriptions WHERE id = ?');
    stmt.execute([id]);
    stmt.close();
    _saveTotals(_totals.minus(TranscriptionRecord.fromMap(rows.single)));
  }

  @override
  int pruneOlderThan(DateTime cutoff) {
    final ms = cutoff.millisecondsSinceEpoch;
    final rows = _db.select(
      'SELECT * FROM transcriptions WHERE created_at < ?',
      [ms],
    );
    if (rows.isEmpty) return 0;
    var totals = _totals;
    for (final row in rows) {
      totals = totals.minus(TranscriptionRecord.fromMap(row));
    }
    final stmt = _db.prepare('DELETE FROM transcriptions WHERE created_at < ?');
    stmt.execute([ms]);
    stmt.close();
    _saveTotals(totals);
    return rows.length;
  }

  @override
  void deleteAll() {
    _db.execute('DELETE FROM transcriptions');
    _saveTotals(HistoryTotals.empty);
  }
}

/// Entrada do `history_store_factory` nesta plataforma.
Future<HistoryStore> openHistoryStore() => SqliteHistoryStore.open();
