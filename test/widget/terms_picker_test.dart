import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soniox_transcriptor/components/terms_picker.dart';

import '../helpers/widget_harness.dart';

void main() {
  testWidgets('Enter adiciona o termo como chip', (tester) async {
    final prefs = await setUpAppEnvironment();
    await pumpCupertinoWidget(tester, const TermsPicker());

    await tester.enterText(find.byType(CupertinoTextField), 'Soniox');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Soniox'), findsOneWidget);
    expect(prefs.getStringList('profile.default.terms'), ['Soniox']);
  });

  testWidgets('campo é limpo depois de adicionar', (tester) async {
    await setUpAppEnvironment();
    await pumpCupertinoWidget(tester, const TermsPicker());

    await tester.enterText(find.byType(CupertinoTextField), 'GRAV');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final field = tester.widget<CupertinoTextField>(
      find.byType(CupertinoTextField),
    );
    expect(field.controller?.text, isEmpty);
  });

  testWidgets('botão de excluir só aparece com o mouse em cima', (
    tester,
  ) async {
    await setUpAppEnvironment();
    await pumpCupertinoWidget(tester, const TermsPicker());

    await tester.enterText(find.byType(CupertinoTextField), 'LiveKit');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    AnimatedCrossFade chipFade() =>
        tester.widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade));

    expect(chipFade().crossFadeState, CrossFadeState.showSecond);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('LiveKit')));
    await tester.pumpAndSettle();

    expect(chipFade().crossFadeState, CrossFadeState.showFirst);
  });

  testWidgets('excluir o termo remove o chip e a persistência', (tester) async {
    final prefs = await setUpAppEnvironment();
    await prefs.setStringList('profile.default.terms', ['LiveKit']);
    await pumpCupertinoWidget(tester, const TermsPicker());

    expect(find.text('LiveKit'), findsOneWidget);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('LiveKit')));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.xmark_circle_fill));
    await tester.pumpAndSettle();

    expect(find.text('LiveKit'), findsNothing);
    expect(prefs.getStringList('profile.default.terms'), isEmpty);
  });
}
