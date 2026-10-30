import 'package:flutter_test/flutter_test.dart';
import 'package:soniox_transcriptor/modules/diarized_text.dart';
import 'package:vit_soniox/vit_soniox.dart';

TranscriptionToken token(String text, {String? speaker, bool isFinal = true}) {
  return TranscriptionToken(
    text: text,
    isFinal: isFinal,
    confidence: 1,
    speaker: speaker,
    startMs: 0,
    endMs: 0,
  );
}

void main() {
  test('primeiro bloco abre com o rótulo, sem linha nova antes', () {
    final builder = DiarizedTextBuilder();

    final text = builder.take([
      token('Olá, ', speaker: '1'),
      token('tudo bem?', speaker: '1'),
    ], followsText: false);

    expect(text, 'Falante 1: Olá, tudo bem?');
  });

  test('mesmo falante em tokens seguidos não repete o rótulo', () {
    final builder = DiarizedTextBuilder();
    builder.take([token('primeira ', speaker: '1')], followsText: false);

    final text = builder.take([
      token('segunda ', speaker: '1'),
      token('parte.', speaker: '1'),
    ], followsText: true);

    expect(text, 'segunda parte.');
  });

  test('troca de falante abre bloco novo em outra linha', () {
    final builder = DiarizedTextBuilder();
    builder.take([token('Bom dia.', speaker: '1')], followsText: false);

    final text = builder.take([
      token('Bom dia.', speaker: '2'),
    ], followsText: true);

    expect(text, '\nFalante 2: Bom dia.');
  });

  test('falante que volta depois de outro ganha rótulo de novo', () {
    final builder = DiarizedTextBuilder();
    builder.take([token('a', speaker: '1')], followsText: false);
    builder.take([token('b', speaker: '2')], followsText: true);

    final text = builder.take([token('c', speaker: '1')], followsText: true);

    expect(text, '\nFalante 1: c');
  });

  test('com texto antes (base da sandbox) começa em linha nova', () {
    final builder = DiarizedTextBuilder();

    final text = builder.take([token('oi', speaker: '1')], followsText: true);

    expect(text, '\nFalante 1: oi');
  });

  test('token de fim de fala não entra no texto', () {
    final builder = DiarizedTextBuilder();

    final text = builder.take([
      token('oi', speaker: '1'),
      token('<end>', speaker: '1'),
    ], followsText: false);

    expect(text, 'Falante 1: oi');
  });

  test('token sem falante não ganha rótulo nem quebra o bloco atual', () {
    final builder = DiarizedTextBuilder();
    builder.take([token('antes ', speaker: '1')], followsText: false);

    final text = builder.take([token('sem rótulo')], followsText: true);

    expect(text, 'sem rótulo');
  });
}
