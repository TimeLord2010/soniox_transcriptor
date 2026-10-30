import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soniox_transcriptor/components/pages/main_page.dart';
import 'package:soniox_transcriptor/modules/platform_support.dart';

import '../helpers/widget_harness.dart';

/// A caixa da sandbox ocupa toda a altura que sobra da aba: antes ela tinha
/// 5 linhas fixas e deixava um vazio grande embaixo no desktop.
void main() {
  tearDown(() => PlatformSupport.debugForceSupportsGlobalHotkey(null));

  Future<void> openPage(WidgetTester tester, Size size) async {
    PlatformSupport.debugForceSupportsGlobalHotkey(true);
    await setUpAppEnvironment();
    await pumpCupertinoWidget(tester, const MainPage());
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await tester.pump();
    await openSandboxTab(tester);
  }

  testWidgets('a caixa cresce com a janela em vez de parar em 5 linhas', (
    tester,
  ) async {
    await openPage(tester, const Size(900, 1200));

    final campo = tester.getRect(find.byKey(const ValueKey('sandbox-field')));
    final barra = tester.getRect(find.byType(CupertinoTabBar));
    final botao = tester.getRect(find.byType(CupertinoButton).first);

    // 1200 de janela: a caixa fica com quase toda a sobra da aba.
    expect(campo.height, greaterThan(700));
    // Termina acima da barra inferior — nada fica atrás dela.
    expect(campo.bottom, lessThanOrEqualTo(barra.top));
    // E começa abaixo do botão de gravar.
    expect(campo.top, greaterThan(botao.bottom));
  });

  testWidgets('em tela de celular ocupa a altura e não estoura', (
    tester,
  ) async {
    await openPage(tester, const Size(360, 800));

    expect(tester.takeException(), isNull);
    final campo = tester.getRect(find.byKey(const ValueKey('sandbox-field')));
    final barra = tester.getRect(find.byType(CupertinoTabBar));
    expect(campo.height, greaterThan(400));
    expect(campo.bottom, lessThanOrEqualTo(barra.top));
  });
}
