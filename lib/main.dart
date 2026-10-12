import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soniox_transcriptor/components/styles/glass_config.dart';
import 'package:sqlite3/sqlite3.dart';

import 'components/pages/main_page.dart';
import 'modules/database_module.dart';
import 'repositories/transcription_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();

  final prefs = await SharedPreferences.getInstance();
  GetIt.instance.registerSingleton<SharedPreferences>(prefs);

  final db = await DatabaseModule.open();
  GetIt.instance.registerSingleton<Database>(db);
  GetIt.instance.registerSingleton<TranscriptionRepository>(
    TranscriptionRepository(),
  );

  runApp(
    LiquidGlassWidgets.wrap(
      child: const MainApp(),
      theme: GlassThemeData(
        light: GlassThemeVariant(quality: .premium, settings: glassConfig),
      ),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        scrollBehavior: MaterialScrollBehavior().copyWith(
          dragDevices: PointerDeviceKind.values.toSet(),
        ),
        home: LiquidGlassLayer(child: const MainPage()),
      ),
    );
  }
}
