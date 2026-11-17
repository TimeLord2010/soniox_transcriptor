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
/// O teclado não abre o SQLite do app: grava UM arquivo
/// `<createdAtMs>-<uuid>.json` (`{"final_text":..., "created_at":<ms>}`) em
/// `keyboard_history/` no `filesDir` (= `getApplicationSupportDirectory()` no
/// Android), escrito em `.tmp` e renomeado. Aqui só se lê `*.json` (nunca
/// `.tmp`), na ordem do nome: lê, insere, apaga. Se um insert falha, para e
/// deixa aquele arquivo e os seguintes para a próxima vez, então nada se perde
/// nem se duplica.
class KeyboardHistoryImporter {
  static const dirName = 'keyboard_history';

  final Future<Directory> Function() _directory;
  final TranscriptionRepository Function() _repository;
  final bool _enabled;

  /// Chamado quando entraram registros com `client_reference_id`: o custo deles
  /// está pendente e deve ser buscado (mesmo fluxo das sessões do app).
  final VoidCallback? onReferencesImported;

  Future<int>? _inFlight;

  KeyboardHistoryImporter({
    this.onReferencesImported,
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
    final base = await _directory();
    final dir = Directory('${base.path}/$dirName');
    if (!await dir.exists()) return 0;

    final files = <File>[
      for (final e in await dir.list().toList())
        if (e is File && e.path.endsWith('.json')) e,
    ]..sort((a, b) => a.path.compareTo(b.path));

    var count = 0;
    var hasReferences = false;
    for (final file in files) {
      try {
        final record = _parse(await file.readAsString());
        if (record != null) {
          _repository().insert(record);
          count++;
          if (record.clientReferenceId != null) hasReferences = true;
        }
        await file.delete();
      } catch (e) {
        debugPrint('[KeyboardHistoryImporter] parando em ${file.path}: $e');
        break;
      }
    }
    if (hasReferences) onReferencesImported?.call();
    return count;
  }

  /// `null` para arquivo malformado (é apagado sem inserir).
  TranscriptionRecord? _parse(String content) {
    try {
      final map = jsonDecode(content);
      if (map is! Map) return null;
      final text = map['final_text'];
      final ms = map['created_at'];
      if (text is! String || ms is! num) return null;
      // Entradas antigas não têm `client_reference_id`: ficam "sem custo".
      final rawId = map['client_reference_id'];
      final referenceId = rawId is String && rawId.isNotEmpty ? rawId : null;
      // Sem texto só vale com referência: é a sessão que o Soniox cobrou sem
      // produzir texto (o registro fica oculto e soma o custo real, como no app).
      if (text.trim().isEmpty && referenceId == null) return null;
      return TranscriptionRecord(
        finalText: text,
        nonFinalText: '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(ms.toInt()),
        clientReferenceId: referenceId,
      );
    } catch (_) {
      return null;
    }
  }
}
