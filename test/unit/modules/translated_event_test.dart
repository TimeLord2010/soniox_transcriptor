import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soniox_transcriptor/modules/translated_event.dart';

/// Payloads reais de uma sessão `one_way` (pt → en) com `stt-rt-v5`, recortados
/// para os campos que o parser usa.
Map<String, dynamic> original(String text, {required bool isFinal}) => {
  'text': text,
  'start_ms': 180,
  'end_ms': 240,
  'confidence': 0.996,
  'is_final': isFinal,
  'language': 'pt',
  'translation_status': 'original',
};

Map<String, dynamic> translation(String text, {bool isFinal = true}) => {
  'text': text,
  'confidence': 1,
  'is_final': isFinal,
  'language': 'en',
  'translation_status': 'translation',
  'source_language': 'pt',
};

String message(List<Map<String, dynamic>> tokens) =>
    jsonEncode({'tokens': tokens});

void main() {
  group('TranslatedEvent.fromRawMessage', () {
    test('separa tradução de transcrição no mesmo evento', () {
      final event = TranslatedEvent.fromRawMessage(
        message([
          original('Bom', isFinal: true),
          original(' dia', isFinal: true),
          translation('Good'),
          translation(' morning'),
        ]),
      );

      expect(event, isNotNull);
      expect(
        event!.finalOriginals.map((token) => token.text).join(),
        'Bom dia',
      );
      expect(event.finalTranslation, 'Good morning');
    });

    test('evento só com tradução não escreve nada na transcrição', () {
      // O Soniox manda a tradução num evento próprio, depois dos originais.
      final event = TranslatedEvent.fromRawMessage(
        message([translation('Good morning')]),
      );

      expect(event!.finalOriginals, isEmpty);
      expect(event.nonFinalOriginals, isEmpty);
      expect(event.finalTranslation, 'Good morning');
    });

    test('tokens não finais ficam separados dos finais', () {
      final event = TranslatedEvent.fromRawMessage(
        message([
          original('Vamos', isFinal: false),
          translation('Let us', isFinal: false),
        ]),
      );

      expect(event!.finalOriginals, isEmpty);
      expect(
        event.nonFinalOriginals.map((token) => token.text).join(),
        'Vamos',
      );
      expect(event.finalTranslation, '');
      expect(event.nonFinalTranslation, 'Let us');
    });

    test('token traduzido sem confidence nem timestamps não estoura', () {
      final event = TranslatedEvent.fromRawMessage(
        message([
          {
            'text': 'Good morning',
            'is_final': true,
            'translation_status': 'translation',
          },
        ]),
      );

      expect(event!.finalTranslation, 'Good morning');
    });

    test('marcador de fim de fala não entra em nenhum dos textos', () {
      final event = TranslatedEvent.fromRawMessage(
        message([
          original('Bom dia', isFinal: true),
          {'text': '<end>', 'is_final': true, 'translation_status': 'none'},
        ]),
      );

      expect(
        event!.finalOriginals.map((token) => token.text).join(),
        'Bom dia',
      );
      expect(event.finalTranslation, isEmpty);
    });

    test('erro do Soniox não é evento de tokens', () {
      final event = TranslatedEvent.fromRawMessage(
        jsonEncode({
          'error_code': 401,
          'error_message': 'Invalid API key',
          'tokens': [],
        }),
      );

      // Sem tokens de conteúdo: nada a escrever na tela.
      expect(event, isNotNull);
      expect(event!.finalOriginals, isEmpty);
      expect(event.finalTranslation, isEmpty);
    });

    test('mensagem sem a lista de tokens devolve null', () {
      expect(
        TranslatedEvent.fromRawMessage(jsonEncode({'finished': true})),
        isNull,
      );
    });

    test('JSON inválido propaga o erro em vez de sumir em silêncio', () {
      expect(
        () => TranslatedEvent.fromRawMessage('não é json'),
        throwsFormatException,
      );
    });
  });
}
