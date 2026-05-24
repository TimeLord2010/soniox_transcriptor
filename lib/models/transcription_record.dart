import 'package:sqlite3/sqlite3.dart';

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

  factory TranscriptionRecord.fromRow(Row row) {
    return TranscriptionRecord(
      id: row['id'] as int,
      finalText: row['final_text'] as String,
      nonFinalText: row['non_final_text'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'final_text': finalText,
      'non_final_text': nonFinalText,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }
}
