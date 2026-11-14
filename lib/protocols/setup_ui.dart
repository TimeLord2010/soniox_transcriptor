import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soniox_transcriptor/repositories/history_store_factory.dart';

import '../repositories/history_store.dart';
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
  GetIt.instance.registerSingleton<TranscriptionRepository>(transcriptionRep);
}
