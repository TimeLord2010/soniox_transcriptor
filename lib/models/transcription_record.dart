class TranscriptionRecord {
  final int? id;
  final String finalText;
  final String nonFinalText;
  final DateTime createdAt;

  TranscriptionRecord({
    this.id,
    required this.finalText,
    required this.nonFinalText,
    required this.createdAt,
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
    );
  }

  Map<String, Object?> toMap() {
    return {
      'final_text': finalText,
      'non_final_text': nonFinalText,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Inclui o `id`: formato do JSON que o store web persiste em
  /// `SharedPreferences`.
  Map<String, Object?> toJson() => {'id': id, ...toMap()};
}
