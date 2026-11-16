import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:soniox_transcriptor/models/transcription_record.dart';
import 'package:soniox_transcriptor/modules/platform_support.dart';
import 'package:soniox_transcriptor/repositories/transcription_repository.dart';

/// Importa para o histórico o que o teclado Android (Kotlin) ditou.
///
/// O teclado não abre o SQLite do app: ele acrescenta uma linha JSON
/// (`{"final_text":..., "created_at":<ms>}`) em `keyboard_history_outbox.jsonl`
/// no `filesDir` (= `getApplicationSupportDirectory()` no Android). Aqui o
/// arquivo é renomeado para `.importing` (o teclado volta a acrescentar num
/// arquivo novo, então nenhuma linha se perde), as linhas viram registros e o
/// `.importing` só é apagado depois que todos os inserts deram certo.
class KeyboardHistoryImporter {
  static const outboxName = 'keyboard_history_outbox.jsonl';
  static const importingName = 'keyboard_history_outbox.importing';

  final Future<Directory> Function() _directory;
  final TranscriptionRepository Function() _repository;
  final bool _enabled;

  Future<int>? _inFlight;

  KeyboardHistoryImporter({
    Future<Directory> Function()? directory,
    TranscriptionRepository Function()? repository,
    bool? enabled,
  }) : _directory = directory ?? getApplicationSupportDirectory,
       _repository = repository ?? GetIt.I.get<TranscriptionRepository>,
       _enabled = enabled ?? PlatformSupport.isAndroid;

  /// Importa o que houver; devolve quantos registros entraram. Chamadas
  /// simultâneas dividem a mesma execução. Nunca lança.
  Future<int> run() {
    if (!_enabled) return Future.value(0);
    return _inFlight ??= _import()
        .catchError((Object e) {
          debugPrint('[KeyboardHistoryImporter] erro: $e');
          return 0;
        })
        .whenComplete(() => _inFlight = null);
  }

  Future<int> _import() async {
    final dir = await _directory();
    final outbox = File('${dir.path}/$outboxName');
    final importing = File('${dir.path}/$importingName');
    var count = 0;

    // Sobra de uma execução interrompida: entra primeiro.
    if (await importing.exists()) {
      count += await _importFile(importing);
    }
    if (await outbox.exists()) {
      await outbox.rename(importing.path);
      count += await _importFile(importing);
    }
    return count;
  }

  Future<int> _importFile(File file) async {
    final lines = await file.readAsLines();
    final repo = _repository();
    var count = 0;
    for (final line in lines) {
      final record = _parse(line);
      if (record == null) continue;
      repo.insert(record);
      count++;
    }
    await file.delete();
    return count;
  }

  TranscriptionRecord? _parse(String line) {
    if (line.trim().isEmpty) return null;
    try {
      final map = jsonDecode(line);
      if (map is! Map) return null;
      final text = map['final_text'];
      final ms = map['created_at'];
      if (text is! String || text.trim().isEmpty || ms is! num) return null;
      return TranscriptionRecord(
        finalText: text,
        nonFinalText: '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(ms.toInt()),
      );
    } catch (_) {
      return null;
    }
  }
}
