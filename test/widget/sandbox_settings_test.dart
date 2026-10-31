import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soniox_transcriptor/components/pages/main_page.dart';
import 'package:soniox_transcriptor/modules/platform_support.dart';

import '../helpers/widget_harness.dart';

/// A aba da sandbox guarda as caixas de texto e um único acesso aos ajustes da
/// captura: diarização e tradução saíram das linhas da aba para o popup do
/// ícone de ajustes, ao lado do botão de gravar.
void main() {
  tearDown(() => PlatformSupport.debugForceSupportsGlobalHotkey(null));

  Future<void> openPage(WidgetTester tester) async {
    PlatformSupport.debugForceSupportsGlobalHotkey(true);
    await setUpAppEnvironment();
    await pumpCupertinoWidget(tester, const MainPage());
    await openSandboxTab(tester);
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('sandbox-settings')));
    await tester.pumpAndSettle();
  }

  testWidgets('a aba não mostra as opções soltas, só o ícone de ajustes', (
    tester,
  ) async {
    await openPage(tester);

    expect(find.byKey(const ValueKey('sandbox-settings')), findsOneWidget);
    expect(find.text('Diarização'), findsNothing);
    expect(find.text('Traduzir'), findsNothing);
  });

  testWidgets('o ícone de ajustes abre diarização e tradução juntas', (
    tester,
  ) async {
    await openPage(tester);

    await openSettings(tester);

    expect(find.text('Ajustes da captura'), findsOneWidget);
    expect(find.byKey(const ValueKey('sandbox-diarization')), findsOneWidget);
    expect(find.byKey(const ValueKey('translation-toggle')), findsOneWidget);
    // Mudança de opção só vale na próxima conexão com o Soniox.
    expect(find.text('Vale a partir da próxima captura.'), findsOneWidget);
  });

  testWidgets('Pronto fecha o popup', (tester) async {
    await openPage(tester);
    await openSettings(tester);

    await tester.tap(find.text('Pronto'));
    await tester.pumpAndSettle();

    expect(find.text('Ajustes da captura'), findsNothing);
    expect(find.byKey(const ValueKey('sandbox-settings')), findsOneWidget);
  });

  testWidgets('o botão de gravar divide a linha com o ícone de ajustes', (
    tester,
  ) async {
    await openPage(tester);

    final botao = tester.getRect(find.text('Clique para gravar'));
    final ajustes = tester.getRect(
      find.byKey(const ValueKey('sandbox-settings')),
    );

    // Mesma linha: mesma faixa vertical, ajustes à direita do botão.
    expect(ajustes.left, greaterThan(botao.right));
    expect(ajustes.center.dy, closeTo(botao.center.dy, 2));
  });
}
