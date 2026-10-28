import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soniox_transcriptor/components/profile_selector.dart';
import 'package:soniox_transcriptor/components/styles/ui.dart';

import '../helpers/widget_harness.dart';

void main() {
  testWidgets('mostra o perfil padrão e não deixa excluí-lo', (tester) async {
    await setUpAppEnvironment();
    await pumpCupertinoWidget(tester, const ProfileSelector());

    expect(find.text('Padrão'), findsOneWidget);

    final deleteButton = tester.widget<CupertinoButton>(
      find.widgetWithIcon(CupertinoButton, CupertinoIcons.trash),
    );
    expect(deleteButton.onPressed, isNull);
  });

  testWidgets('cria perfil pelo diálogo e passa a ser o ativo', (tester) async {
    final prefs = await setUpAppEnvironment();
    await pumpCupertinoWidget(tester, const ProfileSelector());

    await tester.tap(find.byIcon(CupertinoIcons.add));
    await tester.pumpAndSettle();
    expect(find.text('Novo perfil'), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byType(CupertinoAlertDialog),
        matching: find.byType(CupertinoTextField),
      ),
      'Trabalho',
    );
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Trabalho'), findsOneWidget);
    // O perfil recém-criado virou o ativo.
    expect(prefs.getString('profiles.active'), isNot('default'));

    final deleteButton = tester.widget<CupertinoButton>(
      find.widgetWithIcon(CupertinoButton, CupertinoIcons.trash),
    );
    expect(deleteButton.onPressed, isNotNull);
  });

  testWidgets('cancelar o diálogo não cria perfil', (tester) async {
    await setUpAppEnvironment();
    await pumpCupertinoWidget(tester, const ProfileSelector());

    await tester.tap(find.byIcon(CupertinoIcons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Padrão'), findsOneWidget);

    await tester.tap(find.byType(MenuTrigger));
    await tester.pumpAndSettle();
    expect(find.byType(MenuOptionRow), findsOneWidget);
  });

  testWidgets('renomeia o perfil ativo', (tester) async {
    await setUpAppEnvironment();
    await pumpCupertinoWidget(tester, const ProfileSelector());

    await tester.tap(find.byIcon(CupertinoIcons.pencil));
    await tester.pumpAndSettle();
    expect(find.text('Renomear perfil'), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byType(CupertinoAlertDialog),
        matching: find.byType(CupertinoTextField),
      ),
      'Pessoal',
    );
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Pessoal'), findsOneWidget);
    expect(find.text('Padrão'), findsNothing);
  });
}
