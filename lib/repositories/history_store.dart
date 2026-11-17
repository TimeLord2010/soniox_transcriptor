import '../models/history_summary.dart';
import '../models/transcription_record.dart';

/// Onde o histórico de transcrições mora.
///
/// Existe porque o app roda em plataformas que não têm `sqlite3`: no web
/// `dart:ffi` não existe e `path_provider` não dá diretório de aplicação.
/// O contrato é síncrono para a UI; o que é assíncrono fica em [load], chamado
/// no `main()` antes do `runApp`.
abstract class HistoryStore {
  /// Carrega o que já está persistido. No SQLite é no-op (abrir o banco já
  /// entrega tudo); no web é obrigatório antes da primeira leitura.
  Future<void> load();

  /// Grava [record]. O `id` é atribuído pelo store; o do [record] é ignorado.
  void insert(TranscriptionRecord record);

  /// Uma página de registros, do mais novo para o mais antigo.
  List<TranscriptionRecord> page({required int limit, int offset = 0});

  /// Todos os registros, do mais novo para o mais antigo. Só para testes e
  /// migrações: a tela usa [page].
  List<TranscriptionRecord> getAll();

  /// Totais persistidos (caracteres, duração, contagens), mantidos de forma
  /// incremental — nunca recalculados varrendo os registros, exceto na
  /// migração de quem já tinha histórico antes deste campo.
  HistoryTotals get totals;

  void delete(int id);

  /// Apaga os registros com `createdAt` anterior a [cutoff] e devolve quantos
  /// saíram. Os totais descontam o que foi removido.
  int pruneOlderThan(DateTime cutoff);

  /// Apaga tudo e zera os totais.
  void deleteAll();
}
