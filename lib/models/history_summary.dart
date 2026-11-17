import 'transcription_record.dart';

/// Velocidade média de digitação usada para estimar o "tempo salvo":
/// 200 caracteres por minuto (≈ 40 palavras por minuto).
const int kTypingCharsPerMinute = 200;

// Preço do Soniox em tempo real (WebSocket, modelos stt-rt-*), pay-as-you-go.
// Fonte: https://soniox.com/pricing (consultado em 2026-11-17).
// A página lista: tokens de áudio de entrada US$ 2,00 por 1M, tokens de texto
// de saída US$ 4,00 por 1M, e como referência 1 hora de áudio ≈ 30.000 tokens
// de áudio e ≈ 15.000 tokens de texto (= US$ 0,12 por hora de áudio).
// Os tokens de texto de cada registro não são medidos pelo app, então o custo
// usa a proporção por hora de áudio da própria página.
const double kSonioxAudioUsdPerMillionTokens = 2.00;
const double kSonioxTextOutUsdPerMillionTokens = 4.00;
const int kSonioxAudioTokensPerHour = 30000;
const int kSonioxTextTokensPerHour = 15000;

/// US$ por hora de áudio (0,12), derivado das constantes acima.
const double kSonioxUsdPerAudioHour =
    kSonioxAudioTokensPerHour * kSonioxAudioUsdPerMillionTokens / 1e6 +
    kSonioxTextTokensPerHour * kSonioxTextOutUsdPerMillionTokens / 1e6;

/// Custo estimado, em US$, de [audioMs] de áudio transcrito.
double estimateSonioxCostUsd(int audioMs) =>
    audioMs / Duration.millisecondsPerHour * kSonioxUsdPerAudioHour;

/// Totais do histórico exibidos no topo da aba "Histórico". Persistidos pelos
/// stores e atualizados de forma incremental (insert/delete/prune/limpar), para
/// o cabeçalho não varrer os registros.
class HistoryTotals {
  const HistoryTotals({
    this.totalChars = 0,
    this.audioMs = 0,
    this.recordsWithDuration = 0,
    this.recordsWithoutDuration = 0,
  });

  static const empty = HistoryTotals();

  factory HistoryTotals.fromRecords(Iterable<TranscriptionRecord> records) {
    var totals = empty;
    for (final record in records) {
      totals = totals.plus(record);
    }
    return totals;
  }

  /// `null` se o mapa não tiver o formato esperado.
  static HistoryTotals? fromJson(Object? json) {
    if (json is! Map) return null;
    final chars = json['total_chars'];
    final ms = json['audio_ms'];
    final withD = json['with_duration'];
    final withoutD = json['without_duration'];
    if (chars is! int || ms is! int || withD is! int || withoutD is! int) {
      return null;
    }
    return HistoryTotals(
      totalChars: chars,
      audioMs: ms,
      recordsWithDuration: withD,
      recordsWithoutDuration: withoutD,
    );
  }

  final int totalChars;
  final int audioMs;
  final int recordsWithDuration;
  final int recordsWithoutDuration;

  HistoryTotals plus(TranscriptionRecord record) => _apply(record, 1);

  HistoryTotals minus(TranscriptionRecord record) => _apply(record, -1);

  HistoryTotals _apply(TranscriptionRecord record, int sign) {
    final ms = record.audioDurationMs;
    return HistoryTotals(
      totalChars: totalChars + sign * record.text.length,
      audioMs: audioMs + sign * (ms ?? 0),
      recordsWithDuration: recordsWithDuration + (ms != null ? sign : 0),
      recordsWithoutDuration: recordsWithoutDuration + (ms == null ? sign : 0),
    );
  }

  Map<String, Object?> toJson() => {
    'total_chars': totalChars,
    'audio_ms': audioMs,
    'with_duration': recordsWithDuration,
    'without_duration': recordsWithoutDuration,
  };

  int get recordCount => recordsWithDuration + recordsWithoutDuration;

  Duration get totalAudio => Duration(milliseconds: audioMs);

  /// Tempo que levaria para digitar [totalChars] à [kTypingCharsPerMinute].
  Duration get timeSaved =>
      Duration(seconds: (totalChars * 60 / kTypingCharsPerMinute).round());

  /// Custo estimado do Soniox; `null` sem nenhum registro com duração.
  double? get costUsd =>
      recordsWithDuration == 0 ? null : estimateSonioxCostUsd(audioMs);
}

/// 12345 -> "12.345".
String formatThousandsPtBr(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// "2 h 15 min", "45 min", "30 s", "0 s".
String formatDurationPt(Duration duration) {
  final total = duration.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  if (h > 0) return m > 0 ? '$h h $m min' : '$h h';
  if (m > 0) return '$m min';
  return '$s s';
}

/// 0.42 -> "US\$ 0,42"; abaixo de 1 centavo -> "< US\$ 0,01"; `null` -> "—".
String formatUsdPtBr(double? usd) {
  if (usd == null) return '—';
  if (usd <= 0) return 'US\$ 0,00';
  if (usd < 0.01) return '< US\$ 0,01';
  final cents = (usd * 100).round();
  final whole = formatThousandsPtBr(cents ~/ 100);
  return 'US\$ $whole,${(cents % 100).toString().padLeft(2, '0')}';
}
