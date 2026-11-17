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
  test('plus/minus mantêm totais e contagens', () {
    final a = rec('a' * 100, ms: 60000);
    final b = rec('b' * 200);
    final t = HistoryTotals.empty.plus(a).plus(b);
    expect(t.totalChars, 300);
    expect(t.audioMs, 60000);
    expect(t.recordsWithDuration, 1);
    expect(t.recordsWithoutDuration, 1);
    expect(t.timeSaved, const Duration(seconds: 90));
    final back = t.minus(b);
    expect(back.totalChars, 100);
    expect(back.recordsWithoutDuration, 0);
  });

  test('json faz ida e volta; formato ruim vira null', () {
    final t = HistoryTotals.fromRecords([rec('abc', ms: 1000)]);
    final back = HistoryTotals.fromJson(t.toJson())!;
    expect(back.totalChars, 3);
    expect(back.audioMs, 1000);
    expect(HistoryTotals.fromJson({'x': 1}), isNull);
    expect(HistoryTotals.fromJson('lixo'), isNull);
  });

  test('fórmula de custo: US\$ 0,12 por hora de áudio', () {
    expect(kSonioxUsdPerAudioHour, closeTo(0.12, 1e-9));
    expect(estimateSonioxCostUsd(3600000), closeTo(0.12, 1e-9));
    expect(estimateSonioxCostUsd(10 * 3600000), closeTo(1.2, 1e-9));
    expect(HistoryTotals.fromRecords([rec('a')]).costUsd, isNull);
    expect(
      HistoryTotals.fromRecords([rec('a', ms: 3600000)]).costUsd,
      closeTo(0.12, 1e-9),
    );
  });

  test('formatadores', () {
    expect(formatThousandsPtBr(12345), '12.345');
    expect(formatDurationPt(const Duration(seconds: 30)), '30 s');
    expect(formatDurationPt(const Duration(minutes: 45)), '45 min');
    expect(
      formatDurationPt(const Duration(hours: 2, minutes: 15)),
      '2 h 15 min',
    );
    expect(formatUsdPtBr(0.42), 'US\$ 0,42');
    expect(formatUsdPtBr(1234.5), 'US\$ 1.234,50');
    expect(formatUsdPtBr(0.0001), '< US\$ 0,01');
    expect(formatUsdPtBr(null), '—');
  });
}
