import 'package:vit_soniox/vit_soniox.dart';

/// Monta o texto final com o falante na frente de cada bloco, para a sessão
/// aberta com diarização ligada.
///
/// O Soniox entrega o falante por TOKEN (`speaker`), não por frase, e repete o
/// mesmo rótulo em vários tokens seguidos. Então:
/// - o rótulo só é escrito quando o falante MUDA (senão a fala viraria
///   "Falante 1: Falante 1: Falante 1: ...");
/// - cada bloco começa em linha nova, o que dá o formato de diálogo;
/// - o estado do falante atual atravessa as mensagens do WebSocket, porque a
///   fala de uma pessoa chega fatiada em vários eventos.
///
/// O texto não-final (ao vivo) é concatenado sem rótulo pelo chamador: ele
/// precede o primeiro token final da fala, que é quem traz o falante.
class DiarizedTextBuilder {
  String? _speaker;

  /// Trecho pronto para concatenar no texto da sessão.
  ///
  /// [followsText] diz se já existe texto antes deste trecho (base da sandbox
  /// ou falas anteriores): decide a quebra de linha antes do primeiro rótulo.
  String take(
    Iterable<TranscriptionToken> tokens, {
    required bool followsText,
  }) {
    final out = StringBuffer();
    var hasText = followsText;
    for (final token in tokens) {
      // Marcador de fim de fala: não é conteúdo.
      if (token.isEndpoint) continue;
      final speaker = token.speaker;
      if (speaker != null && speaker != _speaker) {
        _speaker = speaker;
        if (hasText) out.write('\n');
        out.write('${label(speaker)}: ');
        hasText = true;
      }
      out.write(token.text);
      hasText = true;
    }
    return out.toString();
  }

  /// Rótulo mostrado no texto para o falante `speaker` do Soniox ("1", "2", ...).
  static String label(String speaker) => 'Falante $speaker';
}
