import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soniox_transcriptor/components/pages/main_page.dart';
import 'package:soniox_transcriptor/modules/platform_support.dart';

import '../helpers/widget_harness.dart';

/// Ações do header da sandbox: copiar o conteúdo e limpar o campo.
void main() {
  late List<MethodCall> platformCalls;

  setUp(() {
    platformCalls = <MethodCall>[];
  });

  Future<void> pumpPage(WidgetTester tester) async {
    PlatformSupport.debugForceSupportsGlobalHotkey(true);
    await setUpAppEnvironment();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpCupertinoWidget(tester, const MainPage());
  }

  CupertinoButton action(WidgetTester tester, String key) {
    return tester.widget<CupertinoButton>(find.byKey(ValueKey(key)));
  }

  String sandboxText(WidgetTester tester) {
    return tester
        .widget<CupertinoTextField>(find.byKey(const ValueKey('sandbox-field')))
        .controller!
        .text;
  }

  tearDown(() => PlatformSupport.debugForceSupportsGlobalHotkey(null));

  testWidgets('header começa com copiar e limpar desabilitados', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(action(tester, 'sandbox-copy').onPressed, isNull);
    expect(action(tester, 'sandbox-clear').onPressed, isNull);
  });

  testWidgets('copiar manda o conteúdo para a área de transferência', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.enterText(
      find.byKey(const ValueKey('sandbox-field')),
      'texto da sandbox',
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('sandbox-copy')));
    await tester.pump();

    final clipboard = platformCalls.lastWhere(
      (call) => call.method == 'Clipboard.setData',
    );
    expect(clipboard.arguments, {'text': 'texto da sandbox'});

    // O toast se remove sozinho depois de 3 s.
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('em tela estreita (Android 360) o header não estoura', (
    tester,
  ) async {
    await pumpPage(tester);

    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('limpar esvazia o campo e desabilita as duas ações', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.enterText(
      find.byKey(const ValueKey('sandbox-field')),
      'texto da sandbox',
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('sandbox-clear')));
    await tester.pump();

    expect(sandboxText(tester), isEmpty);
    expect(action(tester, 'sandbox-copy').onPressed, isNull);
    expect(action(tester, 'sandbox-clear').onPressed, isNull);
  });
}
