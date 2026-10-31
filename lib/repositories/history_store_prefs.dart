import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/transcription_record.dart';
import 'history_store.dart';

/// Histórico no web: uma lista JSON em `SharedPreferences` (localStorage).
///
/// O app guarda no máximo 100 registros ([TranscriptionRepository.maxRecords]),
/// então reescrever o arquivo inteiro a cada gravação é barato e evita trazer
/// sqlite3 em WASM/OPFS só para isso.
///
/// O contrato é síncrono: a lista fica em memória depois do [load] (chamado no
/// `main()` antes do `runApp`) e cada mutação persiste em background.
class PrefsHistoryStore implements HistoryStore {
  static const storageKey = 'transcription_history';

  final List<TranscriptionRecord> _records = [];
  int _nextId = 1;

  SharedPreferences get _prefs => GetIt.I.get<SharedPreferences>();

  @override
  Future<void> load() async {
    _records.clear();
    _nextId = 1;

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
    } catch (error, stack) {
      // Histórico ilegível não pode derrubar o app nem sumir em silêncio:
      // preserva o arquivo para diagnóstico e começa vazio.
      debugPrint('[history] histórico ilegível, começando vazio: $error');
      debugPrintStack(stackTrace: stack);
      _records.clear();
      _nextId = 1;
    }
  }

  @override
  void insert(TranscriptionRecord record) {
    _records.add(
      TranscriptionRecord(
        id: _nextId++,
        finalText: record.finalText,
        nonFinalText: record.nonFinalText,
        createdAt: record.createdAt,
      ),
    );
    _sortNewestFirst();
    _persist();
  }

  @override
  List<TranscriptionRecord> getAll() => List.unmodifiable(_records);

  @override
  void delete(int id) {
    final removed = _records.length;
    _records.removeWhere((record) => record.id == id);
    if (_records.length == removed) return;
    _persist();
  }

  @override
  void deleteOldest(int count) {
    if (count <= 0 || _records.isEmpty) return;
    // A lista está do mais novo para o mais antigo: os antigos ficam no fim.
    final toRemove = count.clamp(0, _records.length);
    _records.removeRange(_records.length - toRemove, _records.length);
    _persist();
  }

  @override
  void deleteAll() {
    _records.clear();
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

  void _persist() {
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
