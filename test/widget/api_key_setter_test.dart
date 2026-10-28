import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soniox_transcriptor/components/api_key_setter.dart';

import '../helpers/widget_harness.dart';

void main() {
  testWidgets('salva a chave digitada no perfil ativo', (tester) async {
    final prefs = await setUpAppEnvironment();
    await pumpCupertinoWidget(tester, const ApiKeySetter());

    expect(find.text('Chave soniox'), findsOneWidget);
    expect(find.text('Enter API key'), findsOneWidget);

    await tester.enterText(find.byType(CupertinoTextField), 'chave-de-teste');
    await tester.tap(find.byIcon(CupertinoIcons.check_mark_circled));
    await tester.pumpAndSettle();

    expect(prefs.getString('profile.default.api_key'), 'chave-de-teste');
  });

  testWidgets('campo da chave fica oculto', (tester) async {
    await setUpAppEnvironment();
    await pumpCupertinoWidget(tester, const ApiKeySetter());

    final field = tester.widget<CupertinoTextField>(
      find.byType(CupertinoTextField),
    );
    expect(field.obscureText, isTrue);
  });
}
