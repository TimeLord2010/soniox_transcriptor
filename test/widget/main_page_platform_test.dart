import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soniox_transcriptor/components/pages/main_page.dart';
import 'package:soniox_transcriptor/modules/platform_support.dart';

import '../helpers/widget_harness.dart';

/// O Android é plataforma suportada mas não tem tecla global: a captura é
/// comandada por toque e o texto fica na sandbox. Estes testes fixam essa
/// diferença (rodam no host macOS, por isso a capacidade é forçada).
void main() {
  tearDown(() => PlatformSupport.debugForceSupportsGlobalHotkey(null));

  testWidgets('sem atalho global a tela mostra o botão de gravar', (
    tester,
  ) async {
    PlatformSupport.debugForceSupportsGlobalHotkey(false);
    await setUpAppEnvironment();
    await pumpCupertinoWidget(tester, const MainPage());

    expect(find.text('Toque para gravar'), findsOneWidget);
    expect(find.text('Sandbox'), findsOneWidget);
  });

  testWidgets('com atalho global (macOS) não existe botão de gravar', (
    tester,
  ) async {
    PlatformSupport.debugForceSupportsGlobalHotkey(true);
    await setUpAppEnvironment();
    await pumpCupertinoWidget(tester, const MainPage());

    expect(find.text('Toque para gravar'), findsNothing);
    expect(find.text('Ouvindo… toque para parar'), findsNothing);
  });

  testWidgets('gravar sem chave no perfil avisa em vez de abrir sessão', (
    tester,
  ) async {
    PlatformSupport.debugForceSupportsGlobalHotkey(false);
    await setUpAppEnvironment();
    await pumpCupertinoWidget(tester, const MainPage());

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
