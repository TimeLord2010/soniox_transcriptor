import 'package:get_it/get_it.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:soniox_transcriptor/repositories/history_store.dart';
import 'package:soniox_transcriptor/repositories/history_store_sqlite.dart';
import 'package:soniox_transcriptor/repositories/transcription_repository.dart';

/// Abre um SQLite em memória e registra no GetIt o [HistoryStore] e o
/// [TranscriptionRepository], como o `main()` faz em produção (lá o store abre
/// um arquivo via `path_provider`, que não existe em teste).
Database setUpDatabase() {
  final db = sqlite3.openInMemory();
  final store = SqliteHistoryStore(db);
  GetIt.I.registerSingleton<HistoryStore>(store);
  GetIt.I.registerSingleton<TranscriptionRepository>(
    TranscriptionRepository(store: store),
  );
  return db;
}
