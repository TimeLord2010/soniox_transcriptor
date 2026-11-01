import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soniox_transcriptor/models/languages.dart';
import 'package:soniox_transcriptor/modules/keyboard_session.dart';

/// Contrato com o teclado Android (Kotlin): o blob publicado aqui é lido em
/// `android/app/src/main/kotlin/com/vit/soniox/keyboard/KeyboardSession.kt`.
/// As chaves são parte do acordo — renomear uma quebra o teclado em silêncio.
void main() {
  test('blob publicado tem exatamente as chaves do contrato', () {
    final map = KeyboardSession.toMap(
      apiKey: 'chave',
      languages: {Language.pt, Language.en},
      contextText: 'reunião sobre o app',
      terms: ['Soniox', 'LEIA'],
      translationTarget: Language.en,
    );

    expect(map, {
      'version': 1,
      'api_key': 'chave',
      'languages': ['pt', 'en'],
      'context_text': 'reunião sobre o app',
      'terms': ['Soniox', 'LEIA'],
      'translation_target': 'en',
    });
  });

  test('tradução desligada publica null explícito', () {
    final map = KeyboardSession.toMap(
      apiKey: '',
      languages: {Language.pt},
      contextText: '',
      terms: [],
      translationTarget: null,
    );

    expect(map['translation_target'], isNull);
    // O teclado trata chave vazia como "sem sessão" e avisa na tela.
    expect(map['api_key'], '');
    expect(map['languages'], ['pt']);
  });

  test('blob sobrevive ao encode/decode que o teclado faz', () {
    final map = KeyboardSession.toMap(
      apiKey: 'k',
      languages: {Language.pt},
      contextText: 'ctx',
      terms: ['termo'],
      translationTarget: Language.en,
    );

    final decoded = jsonDecode(jsonEncode(map)) as Map<String, dynamic>;
    expect(decoded['languages'], ['pt']);
    expect(decoded['terms'], ['termo']);
    expect(decoded['translation_target'], 'en');
  });
}
