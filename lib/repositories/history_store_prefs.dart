import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/history_summary.dart';
import '../models/transcription_record.dart';
import '../models/usage_cost.dart';
import 'history_store.dart';

/// Histórico no web: uma lista JSON em `SharedPreferences` (localStorage).
///
/// O histórico é podado a 90 dias ([TranscriptionRepository.retention]),
/// então reescrever o arquivo inteiro a cada gravação é barato e evita trazer
/// sqlite3 em WASM/OPFS só para isso. Os totais ficam numa chave própria,
/// mantidos de forma incremental.
///
/// O contrato é síncrono: a lista fica em memória depois do [load] (chamado no
/// `main()` antes do `runApp`) e cada mutação persiste em background.
class PrefsHistoryStore implements HistoryStore {
  static const storageKey = 'transcription_history';
  static const totalsKey = 'transcription_history_totals';

  HistoryTotals _totals = HistoryTotals.empty;

  @override
  HistoryTotals get totals => _totals;

  final List<TranscriptionRecord> _records = [];
  int _nextId = 1;

  SharedPreferences get _prefs => GetIt.I.get<SharedPreferences>();

  @override
  Future<void> load() async {
    _records.clear();
    _nextId = 1;
    _totals = HistoryTotals.empty;

    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        throw FormatException(
          'esperava uma lista, veio ${decoded.runtimeType}',
        );
      }
      for (final entry in decoded) {
        if (entry is! Map) {
          throw FormatException('item não é objeto: ${entry.runtimeType}');
        }
        final record = TranscriptionRecord.fromMap(
          entry.map((key, value) => MapEntry('$key', value)),
        );
        _records.add(record);
        final id = record.id;
        if (id != null && id >= _nextId) _nextId = id + 1;
      }
      _sortNewestFirst();
      // Totais persistidos; sem eles (primeira abertura depois da atualização)
      // calcula uma vez a partir dos registros e grava.
      var stored = HistoryTotals.fromJson(
        _decodeOrNull(_prefs.getString(totalsKey)),
      );
      if (stored == null) {
        stored = HistoryTotals.fromRecords(_records);
        _persistTotals(stored);
      }
      _totals = stored;
    } catch (error, stack) {
      // Histórico ilegível não pode derrubar o app nem sumir em silêncio:
      // preserva o arquivo para diagnóstico e começa vazio.
      debugPrint('[history] histórico ilegível, começando vazio: $error');
      debugPrintStack(stackTrace: stack);
      _records.clear();
      _nextId = 1;
      _totals = HistoryTotals.empty;
    }
  }

  Object? _decodeOrNull(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  void insert(TranscriptionRecord record) {
    _records.add(
      TranscriptionRecord.fromMap({...record.toMap(), 'id': _nextId++}),
    );
    _sortNewestFirst();
    _totals = _totals.plus(record);
    _persist();
  }

  @override
  List<TranscriptionRecord> page({required int limit, int offset = 0}) {
    final visible = getAll();
    if (offset >= visible.length) return const [];
    final end = (offset + limit).clamp(0, visible.length);
    return List.unmodifiable(visible.sublist(offset, end));
  }

  @override
  List<TranscriptionRecord> getAll() =>
      List.unmodifiable(_records.where((r) => !r.isHidden));

  @override
  List<TranscriptionRecord> pendingCosts() => _records
      .where((r) => r.costState == CostState.pending)
      .toList()
      .reversed
      .toList();

  @override
  void applyCost(String clientReferenceId, UsageCost? cost) {
    var changed = false;
    for (var i = _records.length - 1; i >= 0; i--) {
      final old = _records[i];
      if (old.clientReferenceId != clientReferenceId) continue;
      changed = true;
      _totals = _totals.minus(old);
      if (old.isHidden && cost == null) {
        _records.removeAt(i);
        continue;
      }
      final updated = old.copyWithCost(cost);
      _records[i] = updated;
      _totals = _totals.plus(updated);
    }
    if (changed) _persist();
  }

  @override
  void delete(int id) {
    final index = _records.indexWhere((record) => record.id == id);
    if (index < 0) return;
    _totals = _totals.minus(_records.removeAt(index));
    _persist();
  }

  @override
  int pruneOlderThan(DateTime cutoff) {
    final old = _records.where((r) => r.createdAt.isBefore(cutoff)).toList();
    if (old.isEmpty) return 0;
    _records.removeWhere((r) => r.createdAt.isBefore(cutoff));
    for (final record in old) {
      _totals = _totals.minus(record);
    }
    _persist();
    return old.length;
  }

  @override
  void deleteAll() {
    _records.clear();
    _totals = HistoryTotals.empty;
    _persist();
  }

  void _sortNewestFirst() {
    // Desempate por id (maior primeiro) para a ordem não depender do
    // `created_at` repetido — o mesmo critério do store em SQLite.
    _records.sort((a, b) {
      final byDate = b.createdAt.compareTo(a.createdAt);
      if (byDate != 0) return byDate;
      return (b.id ?? 0).compareTo(a.id ?? 0);
    });
  }

  void _persistTotals(HistoryTotals totals) {
    unawaited(
      _prefs.setString(totalsKey, jsonEncode(totals.toJson())).catchError((
        Object error,
      ) {
        debugPrint('[history] falha ao persistir totais: $error');
        return false;
      }),
    );
  }

  void _persist() {
    _persistTotals(_totals);
    final payload = jsonEncode(
      _records.map((record) => record.toJson()).toList(),
    );
    unawaited(
      _prefs.setString(storageKey, payload).catchError((Object error) {
        // Falha de gravação nunca silenciosa: a lista em memória continua
        // válida, mas o próximo carregamento perderia este registro.
        debugPrint('[history] falha ao persistir histórico: $error');
        return false;
      }),
    );
  }
}

/// Entrada do `history_store_factory` nesta plataforma.
Future<HistoryStore> openHistoryStore() async {
  final store = PrefsHistoryStore();
  await store.load();
  return store;
}
