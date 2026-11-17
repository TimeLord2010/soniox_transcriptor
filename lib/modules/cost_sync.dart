import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:soniox_transcriptor/models/usage_cost.dart';
import 'package:soniox_transcriptor/repositories/history_store.dart';
import 'package:soniox_transcriptor/repositories/usage_logs_repository.dart';

/// Busca o custo exato das sessões no log de uso do Soniox e grava no
/// histórico. O log demora alguns segundos para registrar a sessão, então a
/// busca repete com espera crescente (15 s, 1 min, 5 min, 30 min) enquanto
/// houver sessão sem custo; passadas 24 h sem aparecer, vira "sem custo".
class CostSync {
  CostSync({
    required HistoryStore store,
    required UsageLogsRepository repository,
    required List<String> Function() apiKeys,
    DateTime Function()? now,
    this.onChanged,
  }) : _store = store,
       _repository = repository,
       _apiKeys = apiKeys,
       _now = now ?? DateTime.now;

  static const backoff = [
    Duration(seconds: 15),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 30),
  ];

  /// Quanto tempo esperamos o Soniox registrar a sessão.
  static const giveUpAfter = Duration(hours: 24);

  final HistoryStore _store;
  final UsageLogsRepository _repository;

  /// Chaves de TODOS os perfis: o log de uso é por projeto (chave), e o
  /// registro não guarda de qual perfil veio.
  final List<String> Function() _apiKeys;
  final DateTime Function() _now;

  /// A UI relê o histórico quando algum custo chegou.
  VoidCallback? onChanged;

  Timer? _timer;
  int _attempt = 0;
  bool _running = false;
  bool _disposed = false;

  /// Uma sessão acabou de terminar: recomeça a espera curta.
  void sessionEnded() {
    _attempt = 0;
    _schedule();
  }

  /// Ao abrir o app: resolve já tudo que ficou pendente.
  Future<void> reconcile() => _run();

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }

  void _schedule() {
    if (_disposed) return;
    _timer?.cancel();
    final delay = backoff[_attempt.clamp(0, backoff.length - 1)];
    _timer = Timer(delay, () {
      _attempt++;
      unawaited(_run());
    });
  }

  Future<void> _run() async {
    if (_running || _disposed) return;
    final pending = _store.pendingCosts();
    if (pending.isEmpty) return;
    _running = true;
    var changed = false;
    try {
      final found = <String, UsageCost>{};
      var reachable = false;
      final oldest = pending
          .map((r) => r.createdAt)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      for (final key in _apiKeys().toSet()) {
        try {
          found.addAll(
            await _repository.fetch(
              key,
              from: oldest.subtract(const Duration(minutes: 30)),
              to: _now().add(const Duration(minutes: 5)),
            ),
          );
          reachable = true;
        } on UsageLogsException catch (error) {
          debugPrint('[cost] $error');
        }
      }
      for (final record in pending) {
        final ref = record.clientReferenceId!;
        final cost = found[ref];
        if (cost != null) {
          _store.applyCost(ref, cost);
          changed = true;
        } else if (reachable &&
            _now().difference(record.createdAt) > giveUpAfter) {
          _store.applyCost(ref, null);
          changed = true;
        }
      }
    } finally {
      _running = false;
    }
    if (changed && !_disposed) onChanged?.call();
    if (_store.pendingCosts().isNotEmpty) _schedule();
  }
}
