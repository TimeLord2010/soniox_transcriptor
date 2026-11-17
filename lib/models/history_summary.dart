import 'transcription_record.dart';

/// Velocidade média de digitação usada para estimar o "tempo salvo":
/// 200 caracteres por minuto (≈ 40 palavras por minuto).
const int kTypingCharsPerMinute = 200;

/// Totais do histórico exibidos no topo da aba "Histórico". Persistidos pelos
/// stores e atualizados de forma incremental (insert/delete/prune/limpar), para
/// o cabeçalho não varrer os registros.
class HistoryTotals {
  const HistoryTotals({
    this.totalChars = 0,
    this.audioMs = 0,
    this.recordsWithDuration = 0,
    this.recordsWithoutDuration = 0,
    this.costE10 = 0,
    this.pendingCost = 0,
    this.noCost = 0,
    this.emptySessionsWithCost = 0,
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
    final cost = json['cost_e10'];
    final pending = json['pending_cost'];
    final none = json['no_cost'];
    final empty = json['empty_with_cost'];
    // Totais gravados antes do custo exato não têm os campos de custo: devolve
    // null para o store recalcular uma vez a partir dos registros.
    if (chars is! int ||
        ms is! int ||
        withD is! int ||
        withoutD is! int ||
        cost is! int ||
        pending is! int ||
        none is! int ||
        empty is! int) {
      return null;
    }
    return HistoryTotals(
      totalChars: chars,
      audioMs: ms,
      recordsWithDuration: withD,
      recordsWithoutDuration: withoutD,
      costE10: cost,
      pendingCost: pending,
      noCost: none,
      emptySessionsWithCost: empty,
    );
  }

  final int totalChars;
  final int audioMs;
  final int recordsWithDuration;
  final int recordsWithoutDuration;

  /// Soma dos custos exatos já conhecidos (1e-10 US$), incluindo as sessões
  /// sem texto.
  final int costE10;

  /// Registros (visíveis ou sem texto) cujo custo ainda não chegou.
  final int pendingCost;

  /// Registros visíveis sem custo (antigos ou não encontrados no log).
  final int noCost;

  /// Sessões sem texto, já com custo, somadas em [costE10].
  final int emptySessionsWithCost;

  HistoryTotals plus(TranscriptionRecord record) => _apply(record, 1);

  HistoryTotals minus(TranscriptionRecord record) => _apply(record, -1);

  HistoryTotals _apply(TranscriptionRecord record, int sign) {
    final state = record.costState;
    final costFields = (
      cost: costE10 + sign * (record.costE10 ?? 0),
      pending: pendingCost + (state == CostState.pending ? sign : 0),
    );
    if (record.isHidden) {
      // Sessão sem texto: só custo (e a contagem de sessões sem texto).
      return HistoryTotals(
        totalChars: totalChars,
        audioMs: audioMs,
        recordsWithDuration: recordsWithDuration,
        recordsWithoutDuration: recordsWithoutDuration,
        costE10: costFields.cost,
        pendingCost: costFields.pending,
        noCost: noCost,
        emptySessionsWithCost:
            emptySessionsWithCost + (state == CostState.known ? sign : 0),
      );
    }
    final ms = record.audioDurationMs;
    return HistoryTotals(
      totalChars: totalChars + sign * record.text.length,
      audioMs: audioMs + sign * (ms ?? 0),
      recordsWithDuration: recordsWithDuration + (ms != null ? sign : 0),
      recordsWithoutDuration: recordsWithoutDuration + (ms == null ? sign : 0),
      costE10: costFields.cost,
      pendingCost: costFields.pending,
      noCost: noCost + (state == CostState.unavailable ? sign : 0),
      emptySessionsWithCost: emptySessionsWithCost,
    );
  }

  Map<String, Object?> toJson() => {
    'total_chars': totalChars,
    'audio_ms': audioMs,
    'with_duration': recordsWithDuration,
    'without_duration': recordsWithoutDuration,
    'cost_e10': costE10,
    'pending_cost': pendingCost,
    'no_cost': noCost,
    'empty_with_cost': emptySessionsWithCost,
  };

  int get recordCount => recordsWithDuration + recordsWithoutDuration;

  Duration get totalAudio => Duration(milliseconds: audioMs);

  /// Tempo que levaria para digitar [totalChars] à [kTypingCharsPerMinute].
  Duration get timeSaved =>
      Duration(seconds: (totalChars * 60 / kTypingCharsPerMinute).round());

  /// Custo exato total (US$) dos registros com custo conhecido.
  double get costUsd => costE10 / 1e10;
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

/// Custo exato em US$, pt-BR: 4 a 6 casas decimais (sem zeros sobrando além
/// da quarta), porque uma sessão curta custa frações de centavo.
/// 0.0123 -> "US$ 0,0123"; 0.000158 -> "US$ 0,000158"; `null` -> "—".
String formatUsdPtBr(double? usd) {
  if (usd == null) return '—';
  var text = usd.toStringAsFixed(6);
  while (text.endsWith('0') && text.length - text.indexOf('.') - 1 > 4) {
    text = text.substring(0, text.length - 1);
  }
  final dot = text.indexOf('.');
  final whole = formatThousandsPtBr(int.parse(text.substring(0, dot)));
  return 'US\$ $whole,${text.substring(dot + 1)}';
}
