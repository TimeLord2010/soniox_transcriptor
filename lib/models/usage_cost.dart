/// Custo EXATO de uma sessão, como o Soniox registrou no log de uso
/// (`GET /v1/usage-logs`). O app nunca calcula preço: só guarda o que o
/// Soniox informou.
class UsageCost {
  const UsageCost({
    required this.costE10,
    this.inputAudioTokens = 0,
    this.inputTextTokens = 0,
    this.outputTextTokens = 0,
  });

  /// Custo em unidades de 1e-10 US$ (o Soniox devolve 10 casas decimais).
  /// Inteiro de propósito: somar milhares de custos em `double` acumula erro.
  final int costE10;
  final int inputAudioTokens;
  final int inputTextTokens;
  final int outputTextTokens;

  double get usd => costE10 / 1e10;

  /// Uma entrada de `usage_logs`; `null` se não tiver `cost_usd` legível.
  static UsageCost? fromLogEntry(Map<dynamic, dynamic> entry) {
    final cost = parseUsdE10(entry['cost_usd']);
    if (cost == null) return null;
    int tokens(String key) => (entry[key] as num?)?.toInt() ?? 0;
    return UsageCost(
      costE10: cost,
      inputAudioTokens: tokens('input_audio_tokens'),
      inputTextTokens: tokens('input_text_tokens'),
      outputTextTokens: tokens('output_text_tokens'),
    );
  }

  /// "0.0001580000" (formato do Soniox) -> 1580000. Aceita número também.
  static int? parseUsdE10(Object? value) {
    if (value is num) return (value * 1e10).round();
    if (value is! String) return null;
    final match = RegExp(r'^(\d+)(?:\.(\d+))?$').firstMatch(value.trim());
    if (match == null) return null;
    final whole = int.parse(match.group(1)!);
    final fraction = (match.group(2) ?? '').padRight(10, '0').substring(0, 10);
    return whole * 10000000000 + int.parse(fraction);
  }

  /// Resposta de `/v1/usage-logs` -> custo por `client_reference_id`.
  /// Entradas sem referência ou sem custo são ignoradas; se a mesma referência
  /// aparecer mais de uma vez os valores são somados.
  static Map<String, UsageCost> byReference(Object? json) {
    final result = <String, UsageCost>{};
    final logs = json is Map ? json['usage_logs'] : null;
    if (logs is! List) return result;
    for (final entry in logs) {
      if (entry is! Map) continue;
      final ref = entry['client_reference_id'];
      if (ref is! String || ref.isEmpty) continue;
      final cost = fromLogEntry(entry);
      if (cost == null) continue;
      final previous = result[ref];
      result[ref] = previous == null ? cost : previous.plus(cost);
    }
    return result;
  }

  UsageCost plus(UsageCost other) => UsageCost(
    costE10: costE10 + other.costE10,
    inputAudioTokens: inputAudioTokens + other.inputAudioTokens,
    inputTextTokens: inputTextTokens + other.inputTextTokens,
    outputTextTokens: outputTextTokens + other.outputTextTokens,
  );
}
