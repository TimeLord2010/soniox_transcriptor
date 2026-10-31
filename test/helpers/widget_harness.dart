import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soniox_transcriptor/repositories/history_store.dart';
import 'package:soniox_transcriptor/repositories/history_store_prefs.dart';
import 'package:soniox_transcriptor/repositories/transcription_repository.dart';

/// Prepara o ambiente que a UI espera do app real: prefs em memória
/// (`setMockInitialValues` é o store em memória do próprio plugin) e o
/// histórico no store de prefs. O store em SQLite fica de fora de propósito —
/// ele puxa `dart:ffi`, e é isso que permite rodar os testes de widget também
/// em Chrome (`flutter test --platform chrome`), como o app roda no browser.
/// Devolve o [SharedPreferences] para os testes conferirem o que foi
/// persistido.
Future<SharedPreferences> setUpAppEnvironment() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final store = PrefsHistoryStore();

  await GetIt.I.reset();
  GetIt.I.registerSingleton<SharedPreferences>(prefs);
  // Depois do GetIt: o load lê o SharedPreferences registrado.
  await store.load();
  GetIt.I.registerSingleton<HistoryStore>(store);
  GetIt.I.registerSingleton<TranscriptionRepository>(
    TranscriptionRepository(store: store),
  );

  addTearDown(() async {
    await GetIt.I.reset();
  });

  return prefs;
}

/// Monta [child] num CupertinoApp com ProviderScope, numa janela de desktop.
Future<void> pumpCupertinoWidget(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      child: CupertinoApp(
        home: CupertinoPageScaffold(
          child: Padding(padding: const EdgeInsets.all(12), child: child),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Abre a aba da sandbox pela barra inferior. O rótulo "Sandbox" só aparece uma
/// vez antes da troca (na barra); depois dela há também o título da seção.
Future<void> openSandboxTab(WidgetTester tester) async {
  await tester.tap(find.text('Sandbox'));
  await tester.pump();
}
