class TranscriptionRecord {
  final int? id;
  final String finalText;
  final String nonFinalText;
  final DateTime createdAt;

  /// Tempo de áudio efetivamente capturado, em ms. `null` nos registros
  /// antigos (anteriores a este campo) e nos importados do teclado.
  final int? audioDurationMs;

  TranscriptionRecord({
    this.id,
    required this.finalText,
    required this.nonFinalText,
    required this.createdAt,
    this.audioDurationMs,
  });

  String get text => finalText + nonFinalText;

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
    );
  }

  Map<String, Object?> toMap() {
    return {
      'final_text': finalText,
      'non_final_text': nonFinalText,
      'created_at': createdAt.millisecondsSinceEpoch,
      if (audioDurationMs != null) 'audio_duration_ms': audioDurationMs,
    };
  }

  /// Inclui o `id`: formato do JSON que o store web persiste em
  /// `SharedPreferences`.
  Map<String, Object?> toJson() => {'id': id, ...toMap()};
}
