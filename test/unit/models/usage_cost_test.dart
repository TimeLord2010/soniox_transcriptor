import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soniox_transcriptor/models/usage_cost.dart';

// Entrada real de /v1/usage-logs (sessão de teste, stt-rt-v5).
const sample = '''
{"usage_logs":[
 {"uuid":"e7cde679","request_scope":"api","client_reference_id":"probe-1",
  "model":"stt-rt-v5","start_time":"2026-11-17T12:34:40.443Z",
  "end_time":"2026-11-17T12:34:44.450Z","input_text_tokens":8,
  "input_audio_tokens":33,"input_audio_duration_ms":3997,"output_text_tokens":15,
  "output_audio_tokens":0,"cost_usd":"0.0001580000"},
 {"uuid":"x","client_reference_id":"outra","cost_usd":"1.5000000000",
  "input_audio_tokens":1,"input_text_tokens":2,"output_text_tokens":3},
 {"uuid":"y","cost_usd":"0.1"},
 {"uuid":"z","client_reference_id":"sem-custo"}
],"next_page_cursor":null}
''';

void main() {
  test('parseia o log de uso e casa pela client_reference_id', () {
    final byRef = UsageCost.byReference(jsonDecode(sample));
    expect(byRef.keys, unorderedEquals(['probe-1', 'outra']));
    final cost = byRef['probe-1']!;
    expect(cost.costE10, 1580000);
    expect(cost.usd, closeTo(0.000158, 1e-12));
    expect(cost.inputAudioTokens, 33);
    expect(cost.inputTextTokens, 8);
    expect(cost.outputTextTokens, 15);
    expect(byRef['outra']!.costE10, 15000000000);
  });

  test('custo decimal em texto vira inteiro exato', () {
    expect(UsageCost.parseUsdE10('0.0081000000'), 81000000);
    expect(UsageCost.parseUsdE10('2'), 20000000000);
    expect(UsageCost.parseUsdE10('lixo'), isNull);
    expect(UsageCost.parseUsdE10(null), isNull);
  });

  test('resposta fora do formato não quebra', () {
    expect(UsageCost.byReference('x'), isEmpty);
    expect(UsageCost.byReference({'usage_logs': 1}), isEmpty);
  });
}
