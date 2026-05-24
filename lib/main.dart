import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import 'components/pages/main_page.dart';
import 'modules/database_module.dart';
import 'repositories/transcription_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  GetIt.instance.registerSingleton<SharedPreferences>(prefs);

  final db = await DatabaseModule.open();
  GetIt.instance.registerSingleton<Database>(db);
  GetIt.instance.registerSingleton<TranscriptionRepository>(
    TranscriptionRepository(),
  );

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: CupertinoApp(
        theme: const CupertinoThemeData(brightness: Brightness.light),
        scrollBehavior: CupertinoScrollBehavior().copyWith(
          dragDevices: PointerDeviceKind.values.toSet(),
        ),
        home: const MainPage(),
      ),
    );
  }
}
