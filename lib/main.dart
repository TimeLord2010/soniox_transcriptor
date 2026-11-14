import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soniox_transcriptor/protocols/setup_ui.dart';

import 'components/pages/main_page.dart';

void main() async {
  await setupUI();

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: CupertinoApp(
        title: 'Soniox Transcriptor',
        theme: const CupertinoThemeData(brightness: .light),
        scrollBehavior: const CupertinoScrollBehavior().copyWith(
          dragDevices: PointerDeviceKind.values.toSet(),
        ),
        home: const MainPage(),
      ),
    );
  }
}
