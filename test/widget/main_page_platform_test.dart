import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soniox_transcriptor/components/pages/main_page.dart';
import 'package:soniox_transcriptor/modules/platform_support.dart';

import '../helpers/widget_harness.dart';

/// A captura por botão existe nas duas plataformas: no Android é o único
/// transporte; no macOS convive com a tecla global (que continua colando no app
/// em foco). Estes testes rodam no host macOS, por isso a capacidade é forçada.
void main() {
  tearDown(() => PlatformSupport.debugForceSupportsGlobalHotkey(null));

  for (final hasHotkey in [false, true]) {
    final onde = hasHotkey
        ? 'macOS (com atalho global)'
        : 'Android (sem atalho)';
    final rotulo = hasHotkey ? 'Clique para gravar' : 'Toque para gravar';

    testWidgets('aba Sandbox tem o botão de gravar em $onde', (tester) async {
      PlatformSupport.debugForceSupportsGlobalHotkey(hasHotkey);
      await setUpAppEnvironment();
      await pumpCupertinoWidget(tester, const MainPage());

      // A tela inicial é de ajustes: o botão vive na aba da sandbox.
      expect(find.textContaining('para gravar'), findsNothing);

      await openSandboxTab(tester);

      expect(find.text(rotulo), findsOneWidget);
      expect(find.byKey(const ValueKey('sandbox-field')), findsOneWidget);
    });
  }

  testWidgets('gravar sem chave no perfil avisa em vez de abrir sessão', (
    tester,
  ) async {
    PlatformSupport.debugForceSupportsGlobalHotkey(false);
    await setUpAppEnvironment();
    await pumpCupertinoWidget(tester, const MainPage());
    await openSandboxTab(tester);

    await tester.tap(find.text('Toque para gravar'));
    await tester.pump();

    expect(
      find.text('Salve a chave Soniox do perfil para gravar.'),
      findsOneWidget,
    );
    // Continua no estado inicial: nada de sessão aberta.
    expect(find.text('Toque para gravar'), findsOneWidget);
    expect(find.byType(CupertinoTextField), findsWidgets);

    // O toast se remove sozinho depois de 3 s.
    await tester.pump(const Duration(seconds: 4));
  });
}
