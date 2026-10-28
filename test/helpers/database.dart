import 'package:get_it/get_it.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:soniox_transcriptor/repositories/transcription_repository.dart';

/// Schema de `transcriptions`: o mesmo de `DatabaseModule.open`, que não pode
/// ser usado aqui porque depende de `path_provider`.
const _transcriptionsSchema = '''
  CREATE TABLE IF NOT EXISTS transcriptions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    final_text TEXT NOT NULL,
    non_final_text TEXT NOT NULL,
    created_at INTEGER NOT NULL
  )
''';

/// Abre um SQLite em memória com o schema e registra no GetIt o banco e o
/// [TranscriptionRepository], como o `main()` faz em produção.
Database setUpDatabase() {
  final db = sqlite3.openInMemory();
  db.execute(_transcriptionsSchema);
  GetIt.I.registerSingleton<Database>(db);
  GetIt.I.registerSingleton<TranscriptionRepository>(TranscriptionRepository());
  return db;
}
