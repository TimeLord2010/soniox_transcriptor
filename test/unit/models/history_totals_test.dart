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

  test('custo exato soma só o que o Soniox informou', () {
    TranscriptionRecord withCost(int e10) => TranscriptionRecord(
      finalText: 'a',
      nonFinalText: '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      clientReferenceId: 'r$e10',
      costE10: e10,
    );
    final pending = TranscriptionRecord(
      finalText: 'a',
      nonFinalText: '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      clientReferenceId: 'p',
    );
    final empty = TranscriptionRecord(
      finalText: '',
      nonFinalText: '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      clientReferenceId: 'e',
      costE10: 500000,
    );
    final t = HistoryTotals.fromRecords([
      withCost(1580000),
      withCost(100),
      pending,
      rec('antigo'),
      empty,
    ]);
    expect(t.costE10, 1580000 + 100 + 500000);
    expect(t.costUsd, closeTo(0.000158 + 0.00000001 + 0.00005, 1e-12));
    expect(t.pendingCost, 1);
    expect(t.noCost, 1);
    expect(t.emptySessionsWithCost, 1);
    // A sessão sem texto não conta como transcrição.
    expect(t.recordCount, 4);
    final back = HistoryTotals.fromJson(t.toJson())!;
    expect(back.costE10, t.costE10);
    expect(back.pendingCost, 1);
    // Totais gravados antes do custo exato pedem recálculo.
    expect(
      HistoryTotals.fromJson({
        'total_chars': 1,
        'audio_ms': 1,
        'with_duration': 1,
        'without_duration': 0,
      }),
      isNull,
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
    expect(formatUsdPtBr(0.0123), 'US\$ 0,0123');
    expect(formatUsdPtBr(0.000158), 'US\$ 0,000158');
    expect(formatUsdPtBr(0.42), 'US\$ 0,4200');
    expect(formatUsdPtBr(1234.5), 'US\$ 1.234,5000');
    expect(formatUsdPtBr(null), '—');
  });
}
