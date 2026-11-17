import 'package:get_it/get_it.dart';

import '../models/history_summary.dart';
import '../models/transcription_record.dart';
import 'history_store.dart';

/// Histórico de transcrições: a retenção e a API que a UI usa.
///
/// A persistência fica atrás de [HistoryStore] porque o web não tem sqlite3
/// (nem `dart:ffi` nem `path_provider`).
class TranscriptionRepository {
  /// Por quanto tempo o histórico guarda cada registro (3 meses).
  static const retention = Duration(days: 90);

  final HistoryStore _store;

  /// Usa o store do GetIt — o `main()` registra o da plataforma atual, e os
  /// testes registram um SQLite em memória (ou o store em prefs).
  TranscriptionRepository({HistoryStore? store})
    : _store = store ?? GetIt.I.get<HistoryStore>();

  /// Grava e poda o que passou da retenção, contada a partir da data do próprio
  /// registro (que é "agora" no uso real).
  void insert(TranscriptionRecord record) {
    _store.insert(record);
    _store.pruneOlderThan(record.createdAt.subtract(retention));
  }

  /// Poda pelo relógio; chamado quando o app abre.
  int pruneExpired({DateTime? now}) =>
      _store.pruneOlderThan((now ?? DateTime.now()).subtract(retention));

  List<TranscriptionRecord> page({required int limit, int offset = 0}) =>
      _store.page(limit: limit, offset: offset);

  List<TranscriptionRecord> getAll() => _store.getAll();

  HistoryTotals get totals => _store.totals;

  void delete(int id) => _store.delete(id);

  void deleteAll() => _store.deleteAll();
}
