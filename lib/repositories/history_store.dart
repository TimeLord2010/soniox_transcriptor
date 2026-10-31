import '../models/transcription_record.dart';

/// Onde o histórico de transcrições mora.
///
/// Existe porque o app roda em plataformas que não têm `sqlite3`: no web
/// `dart:ffi` não existe e `path_provider` não dá diretório de aplicação.
/// O contrato é síncrono para a UI (`historyProvider` lê a lista no primeiro
/// build); o que é assíncrono fica em [load], chamado no `main()` antes do
/// `runApp`.
abstract class HistoryStore {
  /// Carrega o que já está persistido. No SQLite é no-op (abrir o banco já
  /// entrega tudo); no web é obrigatório antes da primeira leitura.
  Future<void> load();

  /// Grava [record]. O `id` é atribuído pelo store; o do [record] é ignorado.
  void insert(TranscriptionRecord record);

  /// Registros do mais novo para o mais antigo.
  List<TranscriptionRecord> getAll();

  void delete(int id);

  /// Descarta os [count] registros mais antigos — usado pelo limite de 100 do
  /// repositório.
  void deleteOldest(int count);

  void deleteAll();
}
