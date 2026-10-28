import 'package:flutter_test/flutter_test.dart';
import 'package:soniox_transcriptor/models/transcription_record.dart';

void main() {
  group('TranscriptionRecord', () {
    test('text junta o texto final com o não final', () {
      final record = TranscriptionRecord(
        finalText: 'bom dia ',
        nonFinalText: 'tudo bem',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
      );

      expect(record.text, 'bom dia tudo bem');
    });

    test('text funciona com o não final vazio', () {
      final record = TranscriptionRecord(
        finalText: 'só final',
        nonFinalText: '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
      );

      expect(record.text, 'só final');
    });

    test('toMap devolve só as colunas da tabela', () {
      final record = TranscriptionRecord(
        id: 7,
        finalText: 'a',
        nonFinalText: 'b',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1234),
      );

      expect(record.toMap(), {
        'final_text': 'a',
        'non_final_text': 'b',
        'created_at': 1234,
      });
    });
  });
}
