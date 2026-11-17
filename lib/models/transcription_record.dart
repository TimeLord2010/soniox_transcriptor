import 'usage_cost.dart';

/// Situação do custo exato de um registro.
enum CostState {
  /// O Soniox já informou o custo.
  known,

  /// Sessão com referência enviada ao Soniox; o log de uso ainda não trouxe.
  pending,

  /// Sem custo: registro antigo (sem referência) ou o log não trouxe em 24 h.
  unavailable,
}

class TranscriptionRecord {
  final int? id;
  final String finalText;
  final String nonFinalText;
  final DateTime createdAt;

  /// Tempo de áudio efetivamente capturado, em ms. `null` nos registros
  /// antigos (anteriores a este campo) e nos importados do teclado.
  final int? audioDurationMs;

  /// `client_reference_id` enviado ao Soniox na sessão: é a chave para achar o
  /// custo no log de uso. `null` nos registros antigos e nos do teclado.
  final String? clientReferenceId;

  /// Custo exato (1e-10 US$) e tokens, vindos do log de uso. `null` até chegar.
  final int? costE10;
  final int? inputAudioTokens;
  final int? inputTextTokens;
  final int? outputTextTokens;

  /// O log de uso não trouxe o custo dentro do prazo: desistimos.
  final bool costUnavailable;

  TranscriptionRecord({
    this.id,
    required this.finalText,
    required this.nonFinalText,
    required this.createdAt,
    this.audioDurationMs,
    this.clientReferenceId,
    this.costE10,
    this.inputAudioTokens,
    this.inputTextTokens,
    this.outputTextTokens,
    this.costUnavailable = false,
  });

  String get text => finalText + nonFinalText;

  /// Sessão sem texto: o Soniox cobra mesmo assim, então o registro existe só
  /// para o custo — não aparece na lista nem entra nas contagens.
  bool get isHidden => text.isEmpty;

  CostState get costState {
    if (costE10 != null) return CostState.known;
    if (clientReferenceId == null || costUnavailable) {
      return CostState.unavailable;
    }
    return CostState.pending;
  }

  double? get costUsd => costE10 == null ? null : costE10! / 1e10;

  TranscriptionRecord copyWithCost(UsageCost? cost) => TranscriptionRecord(
    id: id,
    finalText: finalText,
    nonFinalText: nonFinalText,
    createdAt: createdAt,
    audioDurationMs: audioDurationMs,
    clientReferenceId: clientReferenceId,
    costE10: cost?.costE10,
    inputAudioTokens: cost?.inputAudioTokens,
    inputTextTokens: cost?.inputTextTokens,
    outputTextTokens: cost?.outputTextTokens,
    costUnavailable: cost == null,
  );

  /// Recebe `Map` de propósito (e não `Row` do sqlite3): este pacote também
  /// compila para web, onde `sqlite3`/`dart:ffi` não existe. A linha devolvida
  /// pelo banco é um `Map<String, dynamic>`, então o store em SQLite passa ela
  /// direto.
  factory TranscriptionRecord.fromMap(Map<String, Object?> map) {
    return TranscriptionRecord(
      id: map['id'] as int?,
      finalText: map['final_text'] as String,
      nonFinalText: map['non_final_text'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      audioDurationMs: (map['audio_duration_ms'] as num?)?.toInt(),
      clientReferenceId: map['client_reference_id'] as String?,
      costE10: (map['cost_e10'] as num?)?.toInt(),
      inputAudioTokens: (map['input_audio_tokens'] as num?)?.toInt(),
      inputTextTokens: (map['input_text_tokens'] as num?)?.toInt(),
      outputTextTokens: (map['output_text_tokens'] as num?)?.toInt(),
      costUnavailable: ((map['cost_unavailable'] as num?)?.toInt() ?? 0) != 0,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'final_text': finalText,
      'non_final_text': nonFinalText,
      'created_at': createdAt.millisecondsSinceEpoch,
      if (audioDurationMs != null) 'audio_duration_ms': audioDurationMs,
      if (clientReferenceId != null) 'client_reference_id': clientReferenceId,
      if (costE10 != null) 'cost_e10': costE10,
      if (inputAudioTokens != null) 'input_audio_tokens': inputAudioTokens,
      if (inputTextTokens != null) 'input_text_tokens': inputTextTokens,
      if (outputTextTokens != null) 'output_text_tokens': outputTextTokens,
      if (costUnavailable) 'cost_unavailable': 1,
    };
  }

  /// Inclui o `id`: formato do JSON que o store web persiste em
  /// `SharedPreferences`.
  Map<String, Object?> toJson() => {'id': id, ...toMap()};
}
