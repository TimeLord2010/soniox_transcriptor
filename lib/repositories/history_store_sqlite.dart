import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../models/history_summary.dart';
import '../models/transcription_record.dart';
import '../models/usage_cost.dart';
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
      audio_duration_ms INTEGER,
      client_reference_id TEXT,
      cost_e10 INTEGER,
      input_audio_tokens INTEGER,
      input_text_tokens INTEGER,
      output_text_tokens INTEGER,
      cost_unavailable INTEGER
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
      without_duration INTEGER NOT NULL,
      cost_e10 INTEGER NOT NULL,
      pending_cost INTEGER NOT NULL,
      no_cost INTEGER NOT NULL,
      empty_with_cost INTEGER NOT NULL
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
    // Bancos criados antes de um campo não têm a coluna.
    final columns = _db
        .select('PRAGMA table_info(transcriptions)')
        .map((row) => row['name'])
        .toList();
    const added = {
      'audio_duration_ms': 'INTEGER',
      'client_reference_id': 'TEXT',
      'cost_e10': 'INTEGER',
      'input_audio_tokens': 'INTEGER',
      'input_text_tokens': 'INTEGER',
      'output_text_tokens': 'INTEGER',
      'cost_unavailable': 'INTEGER',
    };
    added.forEach((name, type) {
      if (!columns.contains(name)) {
        _db.execute('ALTER TABLE transcriptions ADD COLUMN $name $type');
      }
    });
    _db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transcriptions_client_reference_id '
      'ON transcriptions (client_reference_id)',
    );
    // Totais de antes do custo exato: descarta para recalcular uma vez.
    final totalsColumns = _db
        .select('PRAGMA table_info(history_totals)')
        .map((row) => row['name'])
        .toList();
    if (totalsColumns.isNotEmpty && !totalsColumns.contains('cost_e10')) {
      _db.execute('DROP TABLE history_totals');
    }
    _db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transcriptions_created_at '
      'ON transcriptions (created_at)',
    );
    _db.execute(totalsSchema);
    _totals = _readTotals() ?? _migrateTotals();
  }

  /// Sessões sem texto (só custo) não aparecem na lista.
  static const _visible = "WHERE final_text != '' OR non_final_text != ''";

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
      costE10: row['cost_e10'] as int,
      pendingCost: row['pending_cost'] as int,
      noCost: row['no_cost'] as int,
      emptySessionsWithCost: row['empty_with_cost'] as int,
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
        (id, total_chars, audio_ms, with_duration, without_duration,
         cost_e10, pending_cost, no_cost, empty_with_cost)
      VALUES (1, ?, ?, ?, ?, ?, ?, ?, ?)
    ''');
    stmt.execute([
      totals.totalChars,
      totals.audioMs,
      totals.recordsWithDuration,
      totals.recordsWithoutDuration,
      totals.costE10,
      totals.pendingCost,
      totals.noCost,
      totals.emptySessionsWithCost,
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
      INSERT INTO transcriptions (
        final_text, non_final_text, created_at, audio_duration_ms,
        client_reference_id, cost_e10, input_audio_tokens, input_text_tokens,
        output_text_tokens, cost_unavailable
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''');
    stmt.execute([
      record.finalText,
      record.nonFinalText,
      record.createdAt.millisecondsSinceEpoch,
      record.audioDurationMs,
      record.clientReferenceId,
      record.costE10,
      record.inputAudioTokens,
      record.inputTextTokens,
      record.outputTextTokens,
      record.costUnavailable ? 1 : 0,
    ]);
    stmt.close();
    _saveTotals(_totals.plus(record));
  }

  @override
  List<TranscriptionRecord> page({required int limit, int offset = 0}) {
    final result = _db.select(
      'SELECT * FROM transcriptions $_visible '
      'ORDER BY created_at DESC, id DESC LIMIT ? OFFSET ?',
      [limit, offset],
    );
    return result.map(TranscriptionRecord.fromMap).toList();
  }

  @override
  List<TranscriptionRecord> getAll() {
    final result = _db.select('''
      SELECT * FROM transcriptions $_visible
      ORDER BY created_at DESC, id DESC
    ''');
    return result.map(TranscriptionRecord.fromMap).toList();
  }

  @override
  List<TranscriptionRecord> pendingCosts() {
    return _db
        .select(
          'SELECT * FROM transcriptions WHERE client_reference_id IS NOT NULL '
          'AND cost_e10 IS NULL AND COALESCE(cost_unavailable, 0) = 0 '
          'ORDER BY created_at ASC',
        )
        .map(TranscriptionRecord.fromMap)
        .toList();
  }

  @override
  void applyCost(String clientReferenceId, UsageCost? cost) {
    final rows = _db.select(
      'SELECT * FROM transcriptions WHERE client_reference_id = ?',
      [clientReferenceId],
    );
    var totals = _totals;
    for (final row in rows) {
      final old = TranscriptionRecord.fromMap(row);
      totals = totals.minus(old);
      if (old.isHidden && cost == null) {
        final del = _db.prepare('DELETE FROM transcriptions WHERE id = ?');
        del.execute([old.id]);
        del.close();
        continue;
      }
      final updated = old.copyWithCost(cost);
      final stmt = _db.prepare('''
        UPDATE transcriptions SET cost_e10 = ?, input_audio_tokens = ?,
          input_text_tokens = ?, output_text_tokens = ?, cost_unavailable = ?
        WHERE id = ?
      ''');
      stmt.execute([
        updated.costE10,
        updated.inputAudioTokens,
        updated.inputTextTokens,
        updated.outputTextTokens,
        updated.costUnavailable ? 1 : 0,
        old.id,
      ]);
      stmt.close();
      totals = totals.plus(updated);
    }
    if (rows.isNotEmpty) _saveTotals(totals);
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
