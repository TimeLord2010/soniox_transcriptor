import 'history_store.dart';
// Condicional, não `kIsWeb`: no web `dart:io` não existe, então o store em
// SQLite (sqlite3/FFI + path_provider) não pode nem ser compilado. Só o ramo
// escolhido entra no build.
import 'history_store_prefs.dart'
    if (dart.library.io) 'history_store_sqlite.dart'
    as impl;

/// Abre o armazenamento do histórico da plataforma atual, já carregado e
/// pronto para leitura síncrona.
Future<HistoryStore> openHistoryStore() => impl.openHistoryStore();
