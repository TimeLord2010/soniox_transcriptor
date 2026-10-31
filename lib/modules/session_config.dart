import 'package:soniox_transcriptor/models/languages.dart';
import 'package:vit_soniox/vit_soniox.dart';

/// Um `stt-rt-v5`, PCM 16 kHz mono, com as opções de sessão do perfil:
/// idiomas de entrada, diarização, contexto/termos e tradução ao vivo.
///
/// Fica fora da tela porque é o CONTRATO com o Soniox: a tradução one-way não
/// tem campo próprio no pacote e entra por `extraParams`, então o formato exato
/// enviado precisa de teste (ver `test/unit/modules/session_config_test.dart`).
SonioxSessionConfig buildSessionConfig({
  required String apiKey,
  required List<String> languages,
  required bool speakerDiarization,
  required Language? translationTarget,
  required String contextText,
  required List<String> terms,
}) {
  return SonioxSessionConfig(
    apiKey: apiKey,
    model: 'stt-rt-v5',
    audio: AudioConfig.pcms16le(),
    languageHints: languages,
    languageStrict: languages.isNotEmpty,
    speakerDiarization: speakerDiarization,
    context: SessionContext(text: contextText, terms: terms),
    // One-way: o Soniox detecta o que foi falado e traduz tudo para o alvo —
    // não se configura língua de origem.
    extraParams: {
      if (translationTarget != null)
        'translation': {
          'type': 'one_way',
          'target_language': translationTarget.name,
        },
    },
  );
}
