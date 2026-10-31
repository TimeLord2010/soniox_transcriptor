import 'dart:convert';

import 'package:vit_soniox/vit_soniox.dart';

/// Uma mensagem do WebSocket de uma sessão com tradução ligada, já separada nas
/// duas metades que o Soniox manda no mesmo stream.
///
/// Com `translation` no config, cada token vem marcado com
/// `translation_status`:
/// - `original` / `none` → transcrição (o que foi falado);
/// - `translation` → o texto traduzido, sem timestamps e em geral em um evento
///   próprio, logo depois dos originais a que se refere.
///
/// O pacote `vit_soniox` não expõe esse campo e junta tudo em `finalText` — com
/// a tradução ligada, o texto traduzido entraria misturado na transcrição. Por
/// isso a sessão com tradução escuta `SonioxWebsocket.rawMessages` e separa as
/// duas metades aqui, em vez de forçar um fork do pacote.
class TranslatedEvent {
  /// Tokens finais do que foi falado (o que entra no texto da sandbox).
  final List<TranscriptionToken> finalOriginals;

  /// Tokens ainda não finais do que foi falado; valem só para a prévia ao vivo
  /// e são substituídos a cada mensagem, como no pacote.
  final List<TranscriptionToken> nonFinalOriginals;

  /// Tradução acumulada desta mensagem (tokens finais, concatenados).
  final String finalTranslation;

  /// Prévia da tradução ainda não final.
  final String nonFinalTranslation;

  const TranslatedEvent({
    this.finalOriginals = const [],
    this.nonFinalOriginals = const [],
    this.finalTranslation = '',
    this.nonFinalTranslation = '',
  });

  /// Lê uma mensagem crua do Soniox. Devolve `null` para eventos sem tokens
  /// (erros, `finished`, mensagens de outro tipo) — quem chama só precisa
  /// cuidar dos casos de token.
  static TranslatedEvent? fromRawMessage(String raw) {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    final Object? rawTokens = decoded['tokens'];
    if (rawTokens is! List) return null;

    final finalOriginals = <TranscriptionToken>[];
    final nonFinalOriginals = <TranscriptionToken>[];
    final finalTranslation = StringBuffer();
    final nonFinalTranslation = StringBuffer();

    for (final Object? item in rawTokens) {
      // Token malformado não pode derrubar a sessão: o resto do evento ainda
      // serve para atualizar a tela.
      if (item is! Map) continue;
      final map = item.cast<String, dynamic>();
      final text = map['text'];
      if (text is! String || text.isEmpty) continue;
      // Marcador de fim de fala, não é conteúdo (nem para traduzir).
      if (text == '<end>') continue;

      final isTranslation = map['translation_status'] == 'translation';
      final isFinal = map['is_final'] == true;

      if (isTranslation) {
        (isFinal ? finalTranslation : nonFinalTranslation).write(text);
        continue;
      }

      final token = TranscriptionToken(
        text: text,
        isFinal: isFinal,
        // Token traduzido não tem `confidence`/timestamps; os originais têm.
        confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
        speaker: map['speaker'] as String?,
        startMs: (map['start_ms'] as num?)?.toInt(),
        endMs: (map['end_ms'] as num?)?.toInt(),
      );
      (isFinal ? finalOriginals : nonFinalOriginals).add(token);
    }

    return TranslatedEvent(
      finalOriginals: finalOriginals,
      nonFinalOriginals: nonFinalOriginals,
      finalTranslation: finalTranslation.toString(),
      nonFinalTranslation: nonFinalTranslation.toString(),
    );
  }
}
