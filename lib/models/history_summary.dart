import 'transcription_record.dart';

/// Velocidade média de digitação usada para estimar o "tempo salvo":
/// 200 caracteres por minuto (≈ 40 palavras por minuto).
const int kTypingCharsPerMinute = 200;

/// Totais do histórico exibidos no topo da aba "Histórico".
class HistorySummary {
  const HistorySummary({
    required this.totalChars,
    required this.totalAudio,
    required this.recordsWithDuration,
    required this.recordsWithoutDuration,
  });

  factory HistorySummary.from(List<TranscriptionRecord> records) {
    var chars = 0;
    var audioMs = 0;
    var withDuration = 0;
    for (final record in records) {
      chars += record.text.length;
      final ms = record.audioDurationMs;
      if (ms != null) {
        audioMs += ms;
        withDuration++;
      }
    }
    return HistorySummary(
      totalChars: chars,
      totalAudio: Duration(milliseconds: audioMs),
      recordsWithDuration: withDuration,
      recordsWithoutDuration: records.length - withDuration,
    );
  }

  final int totalChars;
  final Duration totalAudio;
  final int recordsWithDuration;
  final int recordsWithoutDuration;

  /// Tempo que levaria para digitar [totalChars] à [kTypingCharsPerMinute].
  Duration get timeSaved =>
      Duration(seconds: (totalChars * 60 / kTypingCharsPerMinute).round());
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
