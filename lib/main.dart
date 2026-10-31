import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'components/pages/main_page.dart';
import 'repositories/history_store.dart';
import 'repositories/history_store_factory.dart';
import 'repositories/transcription_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  GetIt.instance.registerSingleton<SharedPreferences>(prefs);

  // Escolhe o armazenamento da plataforma: SQLite no macOS/Android, prefs no
  // web (onde não existe dart:ffi/path_provider).
  final historyStore = await openHistoryStore();
  GetIt.instance.registerSingleton<HistoryStore>(historyStore);
  GetIt.instance.registerSingleton<TranscriptionRepository>(
    TranscriptionRepository(store: historyStore),
  );

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: CupertinoApp(
        title: 'Soniox',
        theme: const CupertinoThemeData(brightness: Brightness.light),
        // O app é desktop: arrastar com qualquer dispositivo, inclusive o mouse.
        scrollBehavior: const CupertinoScrollBehavior().copyWith(
          dragDevices: PointerDeviceKind.values.toSet(),
        ),
        home: const MainPage(),
      ),
    );
  }
}
