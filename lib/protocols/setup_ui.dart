import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soniox_transcriptor/repositories/history_store_factory.dart';

import '../modules/cost_sync.dart';
import '../modules/local_storage_module.dart';
import '../repositories/history_store.dart';
import '../repositories/profile_repository.dart';
import '../repositories/usage_logs_repository.dart';
import '../repositories/transcription_repository.dart';

Future<void> setupUI() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  GetIt.instance.registerSingleton<SharedPreferences>(prefs);

  await _setupStorage();
}

/// Escolhe o armazenamento da plataforma: SQLite no macOS/Android, prefs no
/// web (onde não existe dart:ffi/path_provider).
Future<void> _setupStorage() async {
  final historyStore = await openHistoryStore();
  GetIt.instance.registerSingleton<HistoryStore>(historyStore);
  var transcriptionRep = TranscriptionRepository(store: historyStore);
  // Retenção de 3 meses: poda o que venceu enquanto o app esteve fechado.
  transcriptionRep.pruneExpired();
  GetIt.instance.registerSingleton<TranscriptionRepository>(transcriptionRep);
  GetIt.instance.registerSingleton<CostSync>(
    CostSync(
      store: historyStore,
      repository: UsageLogsRepository(),
      // O log de uso é por projeto (chave): consulta a de todos os perfis.
      apiKeys: () => [
        for (final profile in ProfileRepository().getProfiles())
          ?LocalStorageModule.getApiKey(profile.id)?.trim(),
      ].where((key) => key.isNotEmpty).toList(),
    ),
  );
}
