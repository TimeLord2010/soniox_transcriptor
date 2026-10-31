import 'package:get_it/get_it.dart';

import '../models/transcription_record.dart';
import 'history_store.dart';

/// Histórico de transcrições: o limite de registros e a API que a UI usa.
///
/// A persistência fica atrás de [HistoryStore] porque o web não tem sqlite3
/// (nem `dart:ffi` nem `path_provider`).
class TranscriptionRepository {
  /// Quantos registros o histórico guarda.
  static const maxRecords = 100;

  final HistoryStore _store;

  /// Usa o store do GetIt — o `main()` registra o da plataforma atual, e os
  /// testes registram um SQLite em memória (ou o store em prefs).
  TranscriptionRepository({HistoryStore? store})
    : _store = store ?? GetIt.I.get<HistoryStore>();

  void insert(TranscriptionRecord record) {
    _store.insert(record);
    _enforceMaxRecords();
  }

  void _enforceMaxRecords() {
    final excess = _store.getAll().length - maxRecords;
    if (excess > 0) _store.deleteOldest(excess);
  }

  List<TranscriptionRecord> getAll() => _store.getAll();

  void delete(int id) => _store.delete(id);

  void deleteAll() => _store.deleteAll();
}
