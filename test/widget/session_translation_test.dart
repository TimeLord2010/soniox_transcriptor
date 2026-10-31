import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:soniox_transcriptor/components/pages/main_page.dart';
import 'package:soniox_transcriptor/modules/platform_support.dart';
import 'package:soniox_transcriptor/repositories/recorder_repository.dart';
import 'package:soniox_transcriptor/repositories/soniox_websocket_impl.dart';

import '../helpers/fake_session.dart';
import '../helpers/widget_harness.dart';

/// Sessão de ponta a ponta, com servidor e microfone falsos: o que o app manda
/// no `start`, os eventos chegando e os dois textos na tela.
///
/// Existe porque o caminho da sessão só rodava no app real — e uma tradução
/// vazia (config sem `translation`, ou assinatura errada) passava despercebida.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeServer server;
  late FakeRecorder recorder;
  late SharedPreferences prefs;

  setUp(() async {
    PlatformSupport.debugForceSupportsGlobalHotkey(true);
    prefs = await setUpAppEnvironment();
    await prefs.setString('profile.default.api_key', 'chave-de-teste');

    server = FakeServer();
    recorder = FakeRecorder();
    GetIt.I.registerSingleton<RecorderRepository>(recorder);
    GetIt.I.registerSingleton<WebsocketFactory>(() => server);
    addTearDown(server.dispose);

    // O listener da tecla global fala com o nativo: no teste é no-op.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel('hotkey_plugin'), (call) async {
          return null;
        });
  });

  tearDown(() => PlatformSupport.debugForceSupportsGlobalHotkey(null));

  Future<void> pumpApp(WidgetTester tester) async {
    await pumpCupertinoWidget(tester, const MainPage());
    await openSandboxTab(tester);
  }

  /// Abre a sessão pelo botão e deixa o connect assentar.
  Future<void> startSession(WidgetTester tester) async {
    await tester.tap(find.text('Clique para gravar'));
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  String textOf(WidgetTester tester, String key) {
    final field = tester.widget<CupertinoTextField>(find.byKey(ValueKey(key)));
    return field.controller!.text;
  }

  // Recortes de eventos reais do Soniox (stt-rt-v5) com tradução one-way.
  Map<String, dynamic> spoken(String text) => {
    'tokens': [
      {
        'text': text,
        'start_ms': 0,
        'end_ms': 100,
        'confidence': 0.9,
        'is_final': true,
        'language': 'pt',
        'translation_status': 'original',
      },
    ],
  };

  /// Fala que o Soniox transcreve mas NÃO traduz: já está no idioma alvo.
  Map<String, dynamic> untranslated(String text) => {
    'tokens': [
      {
        'text': text,
        'start_ms': 0,
        'end_ms': 100,
        'confidence': 0.9,
        'is_final': true,
        'language': 'pt',
        'translation_status': 'none',
      },
    ],
  };

  Map<String, dynamic> translated(String text) => {
    'tokens': [
      {
        'text': text,
        'confidence': 1,
        'is_final': true,
        'language': 'en',
        'translation_status': 'translation',
        'source_language': 'pt',
      },
    ],
  };

  testWidgets('com tradução ligada, a sessão pede one_way e mostra os dois '
      'textos', (tester) async {
    await pumpApp(tester);
    // Liga a tradução pelo mesmo caminho da UI: os ajustes da captura.
    await tester.tap(find.byKey(const ValueKey('sandbox-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Traduzir'));
    await tester.pump();
    await tester.tap(find.text('Pronto'));
    await tester.pumpAndSettle();

    await startSession(tester);

    expect(recorder.starts, 1);
    expect(server.sentConfig, isNotNull);
    expect(server.sentConfig!['translation'], {
      'type': 'one_way',
      'target_language': 'en',
    });

    server.push(spoken('Bom dia a todos.'));
    server.push(translated('Good morning everyone.'));
    await tester.pump();

    expect(textOf(tester, 'sandbox-field'), 'Bom dia a todos.');
    expect(
      textOf(tester, 'sandbox-translation-field'),
      'Good morning everyone.',
    );
  });

  testWidgets('sem tradução, a sessão não manda bloco translation', (
    tester,
  ) async {
    await pumpApp(tester);
    await startSession(tester);

    expect(server.sentConfig!.containsKey('translation'), isFalse);
  });

  testWidgets('fala já no idioma alvo avisa em vez de deixar a caixa vazia', (
    tester,
  ) async {
    // Alvo = português falando português: o Soniox não traduz nada.
    await prefs.setString('profile.default.translation_target', 'pt');
    await pumpApp(tester);

    await startSession(tester);
    server.push(untranslated('Bom dia a todos.'));
    await tester.pump();

    // A fala entra na transcrição (status "none" não é tradução)...
    expect(textOf(tester, 'sandbox-field'), 'Bom dia a todos.');
    // ...e a caixa da tradução explica por que está vazia.
    expect(textOf(tester, 'sandbox-translation-field'), '');
    expect(
      find.text('Nada para traduzir: a fala já está em Português.'),
      findsOneWidget,
    );
  });

  testWidgets('quando a tradução começa, o aviso sai', (tester) async {
    await prefs.setString('profile.default.translation_target', 'pt');
    await pumpApp(tester);

    await startSession(tester);
    server.push(untranslated('Bom dia.'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('sandbox-translation-empty')),
      findsOneWidget,
    );

    server.push(spoken('Good morning.'));
    server.push(translated('Bom dia.'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('sandbox-translation-empty')),
      findsNothing,
    );
    expect(textOf(tester, 'sandbox-translation-field'), 'Bom dia.');
  });

  testWidgets('parar a sessão guarda a tradução na tela', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('sandbox-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Traduzir'));
    await tester.pump();
    await tester.tap(find.text('Pronto'));
    await tester.pumpAndSettle();
    await startSession(tester);

    server.push(spoken('Bom dia.'));
    server.push(translated('Good morning.'));
    await tester.pump();

    await tester.tap(find.textContaining('para parar'));
    await tester.pumpAndSettle();

    expect(textOf(tester, 'sandbox-translation-field'), 'Good morning.');
    expect(recorder.stops, greaterThan(0));
    // O toast da entrega usa Timer: deixa ele vencer antes de fechar o teste.
    await tester.pump(const Duration(seconds: 5));
  });
}
