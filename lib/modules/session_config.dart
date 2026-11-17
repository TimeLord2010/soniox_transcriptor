import 'dart:math';

import 'package:soniox_transcriptor/models/languages.dart';
import 'package:vit_soniox/vit_soniox.dart';

/// PCM 16 kHz mono, com as opções de sessão do perfil: modelo escolhido (a
/// lista vem da API do Soniox, não do código), idiomas de entrada,
/// diarização, contexto/termos e tradução ao vivo.
///
/// Fica fora da tela porque é o CONTRATO com o Soniox: a tradução one-way não
/// tem campo próprio no pacote e entra por `extraParams`, então o formato exato
/// enviado precisa de teste (ver `test/unit/modules/session_config_test.dart`).
SonioxSessionConfig buildSessionConfig({
  required String apiKey,
  required String model,
  required List<String> languages,
  required bool speakerDiarization,
  required Language? translationTarget,
  required String contextText,
  required List<String> terms,
  String? clientReferenceId,
}) {
  return SonioxSessionConfig(
    apiKey: apiKey,
    model: model,
    audio: AudioConfig.pcms16le(),
    languageHints: languages,
    languageStrict: languages.isNotEmpty,
    speakerDiarization: speakerDiarization,
    context: SessionContext(text: contextText, terms: terms),
    // One-way: o Soniox detecta o que foi falado e traduz tudo para o alvo —
    // não se configura língua de origem.
    extraParams: {
      // Identificador da sessão no log de uso do Soniox: é como o app acha o
      // custo exato dela depois.
      'client_reference_id': ?clientReferenceId,
      if (translationTarget != null)
        'translation': {
          'type': 'one_way',
          'target_language': translationTarget.name,
        },
    },
  );
}

/// `client_reference_id` da sessão (UUID v4), gravado no registro e usado para
/// achar a entrada correspondente em `/v1/usage-logs`.
String newClientReferenceId([Random? random]) {
  final rng = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int from, int to) => bytes
      .sublist(from, to)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

/// A referência que a sessão enviou no `start` (`null` se a config não tem).
String? clientReferenceIdOf(SonioxSessionConfig config) =>
    config.extraParams['client_reference_id'] as String?;
