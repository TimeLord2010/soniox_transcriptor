import 'package:flutter_test/flutter_test.dart';
import 'package:soniox_transcriptor/components/language_picker.dart';
import 'package:soniox_transcriptor/components/styles/ui.dart';

import '../helpers/widget_harness.dart';

void main() {
  testWidgets('mostra o português como língua inicial', (tester) async {
    await setUpAppEnvironment();
    await pumpCupertinoWidget(tester, const LanguagePicker());

    expect(find.text('Línguas'), findsOneWidget);
    expect(find.text('Português'), findsOneWidget);
  });

  testWidgets('marcar outra língua não fecha o popup', (tester) async {
    final prefs = await setUpAppEnvironment();
    await pumpCupertinoWidget(tester, const LanguagePicker());

    await tester.tap(find.byType(MenuTrigger));
    await tester.pumpAndSettle();
    expect(find.byType(MenuOptionRow), findsNWidgets(2));

    await tester.tap(find.widgetWithText(MenuOptionRow, 'Inglês'));
    await tester.pumpAndSettle();

    // Popup continua aberto depois do toggle: seleção é múltipla.
    expect(find.text('Pronto'), findsOneWidget);
    expect(prefs.getStringList('profile.default.languages')?.toSet(), {
      'pt',
      'en',
    });
  });

  testWidgets('trigger mostra as línguas escolhidas depois de fechar', (
    tester,
  ) async {
    await setUpAppEnvironment();
    await pumpCupertinoWidget(tester, const LanguagePicker());

    await tester.tap(find.byType(MenuTrigger));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuOptionRow, 'Inglês'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pronto'));
    await tester.pumpAndSettle();

    expect(find.text('Português, Inglês'), findsOneWidget);
    expect(find.text('Pronto'), findsNothing);
  });

  testWidgets('desmarcar todas as línguas mostra o estado vazio', (
    tester,
  ) async {
    await setUpAppEnvironment();
    await pumpCupertinoWidget(tester, const LanguagePicker());

    await tester.tap(find.byType(MenuTrigger));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuOptionRow, 'Português'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pronto'));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma língua selecionada'), findsOneWidget);
  });
}
