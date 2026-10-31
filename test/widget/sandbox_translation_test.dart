import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soniox_transcriptor/components/pages/main_page.dart';
import 'package:soniox_transcriptor/components/styles/ui.dart';
import 'package:soniox_transcriptor/models/languages.dart';
import 'package:soniox_transcriptor/modules/platform_support.dart';
import 'package:soniox_transcriptor/repositories/translation_repository.dart';

import '../helpers/widget_harness.dart';

/// Tradução ao vivo é opção de sessão: liga pela caixa de marcar, exige língua
/// alvo e aparece nos dois lugares (Início e Sandbox) — sempre a mesma
/// preferência do perfil.
void main() {
  tearDown(() => PlatformSupport.debugForceSupportsGlobalHotkey(null));

  Future<void> openPage(WidgetTester tester) async {
    PlatformSupport.debugForceSupportsGlobalHotkey(true);
    await setUpAppEnvironment();
    await pumpCupertinoWidget(tester, const MainPage());
  }

  IconData toggleIcon(WidgetTester tester) {
    return tester
        .widget<Icon>(
          find.descendant(
            of: find.byKey(const ValueKey('translation-toggle')),
            matching: find.byType(Icon),
          ),
        )
        .icon!;
  }

  testWidgets('a sandbox começa sem tradução e sem caixa de tradução', (
    tester,
  ) async {
    await openPage(tester);
    await openSandboxTab(tester);

    expect(find.text('Traduzir'), findsOneWidget);
    expect(toggleIcon(tester), CupertinoIcons.circle);
    expect(find.text('Língua alvo: Inglês'), findsNothing);
    expect(
      find.byKey(const ValueKey('sandbox-translation-field')),
      findsNothing,
    );
  });

  testWidgets('ligar a tradução escolhe alvo e abre a caixa da tradução', (
    tester,
  ) async {
    await openPage(tester);
    await openSandboxTab(tester);

    await tester.tap(find.text('Traduzir'));
    await tester.pump();

    expect(toggleIcon(tester), CupertinoIcons.check_mark_circled_solid);
    // Hints padrão = {pt}, então o alvo útil é inglês.
    expect(find.text('Língua alvo: Inglês'), findsOneWidget);
    expect(TranslationRepository('default').getTarget(), Language.en);

    final campo = tester.widget<CupertinoTextField>(
      find.byKey(const ValueKey('sandbox-translation-field')),
    );
    // Quem escreve é o Soniox: a caixa não aceita digitação.
    expect(campo.readOnly, isTrue);
    expect(find.text('Tradução — Inglês'), findsOneWidget);
  });

  testWidgets('o seletor de alvo troca a língua e fecha o popup', (
    tester,
  ) async {
    await openPage(tester);
    await openSandboxTab(tester);
    await tester.tap(find.text('Traduzir'));
    await tester.pump();

    await tester.tap(find.text('Língua alvo: Inglês'));
    await tester.pumpAndSettle();
    expect(find.byType(MenuOptionRow), findsNWidgets(2));

    await tester.tap(find.widgetWithText(MenuOptionRow, 'Português'));
    await tester.pumpAndSettle();

    expect(find.text('Pronto'), findsNothing);
    expect(find.text('Tradução — Português'), findsOneWidget);
    expect(TranslationRepository('default').getTarget(), Language.pt);
  });

  testWidgets('desligar a tradução tira a caixa e apaga o alvo', (
    tester,
  ) async {
    await openPage(tester);
    await openSandboxTab(tester);
    await tester.tap(find.text('Traduzir'));
    await tester.pump();

    await tester.tap(find.text('Traduzir'));
    await tester.pump();

    expect(toggleIcon(tester), CupertinoIcons.circle);
    expect(
      find.byKey(const ValueKey('sandbox-translation-field')),
      findsNothing,
    );
    expect(TranslationRepository('default').getTarget(), isNull);
  });

  testWidgets('a aba Início mostra o mesmo controle e a sandbox acompanha', (
    tester,
  ) async {
    await openPage(tester);

    // Início já vem aberto: o controle fica junto das línguas de entrada.
    expect(find.text('Traduzir'), findsOneWidget);
    await tester.tap(find.text('Traduzir'));
    await tester.pump();
    expect(find.text('Língua alvo: Inglês'), findsOneWidget);

    await openSandboxTab(tester);

    expect(toggleIcon(tester), CupertinoIcons.check_mark_circled_solid);
    expect(
      find.byKey(const ValueKey('sandbox-translation-field')),
      findsOneWidget,
    );
  });

  testWidgets('tradução salva no perfil nasce ligada', (tester) async {
    PlatformSupport.debugForceSupportsGlobalHotkey(true);
    await setUpAppEnvironment();
    await TranslationRepository('default').setTarget(Language.en);
    await pumpCupertinoWidget(tester, const MainPage());
    await openSandboxTab(tester);

    expect(toggleIcon(tester), CupertinoIcons.check_mark_circled_solid);
    expect(find.text('Tradução — Inglês'), findsOneWidget);
  });
}
