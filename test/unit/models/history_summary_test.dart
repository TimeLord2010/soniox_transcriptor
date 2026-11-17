import 'package:flutter_test/flutter_test.dart';
import 'package:soniox_transcriptor/models/history_summary.dart';
import 'package:soniox_transcriptor/models/transcription_record.dart';

TranscriptionRecord rec(String text, {int? ms}) => TranscriptionRecord(
  finalText: text,
  nonFinalText: '',
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  audioDurationMs: ms,
);

void main() {
  test('soma caracteres e duração, ignorando registros sem duração', () {
    final s = HistorySummary.from([
      rec('a' * 100, ms: 60000),
      rec('b' * 300, ms: 30000),
      rec('c' * 200),
    ]);
    expect(s.totalChars, 600);
    expect(s.totalAudio, const Duration(seconds: 90));
    expect(s.recordsWithoutDuration, 1);
    expect(s.recordsWithDuration, 2);
    expect(s.timeSaved, const Duration(minutes: 3));
  });

  test('histórico vazio', () {
    final s = HistorySummary.from([]);
    expect(s.totalChars, 0);
    expect(s.recordsWithDuration, 0);
  });

  test('formatadores', () {
    expect(formatThousandsPtBr(12345), '12.345');
    expect(formatThousandsPtBr(999), '999');
    expect(formatThousandsPtBr(1000000), '1.000.000');
    expect(formatDurationPt(const Duration(seconds: 30)), '30 s');
    expect(formatDurationPt(const Duration(minutes: 45)), '45 min');
    expect(
      formatDurationPt(const Duration(hours: 2, minutes: 15)),
      '2 h 15 min',
    );
  });
}
