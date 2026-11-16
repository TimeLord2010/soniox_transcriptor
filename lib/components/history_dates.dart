/// Data e hora do histórico em português, no fuso do aparelho.
///
/// O histórico mostrava `toIso8601String()` cru ("2026-11-16T19:23:05.123-0300"),
/// que serve para máquina e não para quem lê. A data virou cabeçalho do dia
/// (Hoje, Ontem, "dom 16/11/2026") e o registro mostra só a hora.
library;

const _weekdays = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];

String _two(int value) => value.toString().padLeft(2, '0');

/// Hora do registro: "19:23".
String historyTime(DateTime when) => '${_two(when.hour)}:${_two(when.minute)}';

/// Cabeçalho do dia do registro, comparado com [now].
///
/// A comparação é de dia civil (ano/mês/dia), não de diferença em horas: às
/// 00h10 "ontem às 23h50" são dias diferentes e `difference().inHours` diria
/// que é o mesmo dia.
String historyDayLabel(DateTime when, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final day = DateTime(when.year, when.month, when.day);
  final today = DateTime(reference.year, reference.month, reference.day);
  final days = today.difference(day).inDays;
  if (days == 0) return 'Hoje';
  if (days == 1) return 'Ontem';
  // Data futura (relógio do aparelho mexido, fuso) cai no formato completo,
  // que nunca mente sobre o dia.
  final weekday = _weekdays[when.weekday - 1];
  return '$weekday ${_two(when.day)}/${_two(when.month)}/${when.year}';
}
