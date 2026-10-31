import 'package:flutter_test/flutter_test.dart';
import 'package:soniox_transcriptor/models/languages.dart';
import 'package:soniox_transcriptor/modules/session_config.dart';

/// O que vai no `start` do WebSocket é contrato com o Soniox: a tradução
/// one-way não é campo tipado do pacote (entra por `extraParams`), então o
/// formato precisa ficar preso aqui.
void main() {
  Map<String, dynamic> config({
    Language? translationTarget,
    bool diarization = false,
    List<String> languages = const ['pt'],
  }) {
    return buildSessionConfig(
      apiKey: 'chave-de-teste',
      languages: languages,
      speakerDiarization: diarization,
      translationTarget: translationTarget,
      contextText: 'reunião de orçamento',
      terms: ['Soniox'],
    ).toMap;
  }

  test('usa o modelo de tradução do Soniox', () {
    expect(config()['model'], 'stt-rt-v5');
  });

  test('tradução desligada não manda bloco translation', () {
    expect(config().containsKey('translation'), isFalse);
  });

  test('tradução ligada manda one_way com a língua alvo', () {
    expect(config(translationTarget: Language.en)['translation'], {
      'type': 'one_way',
      'target_language': 'en',
    });
  });

  test('tradução ligada não fixa língua de origem', () {
    // One-way: a origem é detectada pelo Soniox; só o alvo é configurado.
    final translation = config(translationTarget: Language.pt)['translation'];
    expect(translation.keys, ['type', 'target_language']);
  });

  test('idiomas de entrada seguem como hints estritos', () {
    final map = config(languages: ['pt', 'en']);

    expect(map['language_hints'], ['pt', 'en']);
    expect(map['language_hints_strict'], isTrue);
  });

  test('sem idiomas de entrada, hints não é estrito', () {
    expect(config(languages: [])['language_hints_strict'], isFalse);
  });

  test('diarização e tradução convivem na mesma sessão', () {
    final map = config(translationTarget: Language.en, diarization: true);

    expect(map['enable_speaker_diarization'], isTrue);
    expect(map['translation'], {'type': 'one_way', 'target_language': 'en'});
  });

  test('áudio segue PCM 16 kHz mono', () {
    final map = config();

    expect(map['audio_format'], 'pcm_s16le');
    expect(map['sample_rate'], 16000);
    expect(map['num_channels'], 1);
  });
}
