import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soniox_transcriptor/components/pages/main_page.dart';
import 'package:soniox_transcriptor/modules/platform_support.dart';
import 'package:soniox_transcriptor/repositories/diarization_repository.dart';

import '../helpers/widget_harness.dart';

/// A diarização é uma opção de sessão da aba da sandbox: liga/desliga pelo
/// checkbox e fica salva por perfil.
void main() {
  tearDown(() => PlatformSupport.debugForceSupportsGlobalHotkey(null));

  Future<void> openPage(WidgetTester tester) async {
    PlatformSupport.debugForceSupportsGlobalHotkey(true);
    await setUpAppEnvironment();
    await pumpCupertinoWidget(tester, const MainPage());
    await openSandboxTab(tester);
  }

  IconData checkboxIcon(WidgetTester tester) {
    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const ValueKey('sandbox-diarization')),
        matching: find.byType(Icon),
      ),
    );
    return icon.icon!;
  }

  testWidgets('a aba da sandbox começa com diarização desligada', (
    tester,
  ) async {
    await openPage(tester);

    expect(find.text('Diarização'), findsOneWidget);
    expect(checkboxIcon(tester), CupertinoIcons.circle);
    expect(DiarizationRepository('default').getSpeakerDiarization(), isFalse);
  });

  testWidgets('marcar a diarização salva a preferência e troca o ícone', (
    tester,
  ) async {
    await openPage(tester);

    await tester.tap(find.text('Diarização'));
    await tester.pump();

    expect(checkboxIcon(tester), CupertinoIcons.check_mark_circled_solid);
    expect(DiarizationRepository('default').getSpeakerDiarization(), isTrue);

    // Desmarcar volta ao estado inicial e persiste.
    await tester.tap(find.text('Diarização'));
    await tester.pump();

    expect(checkboxIcon(tester), CupertinoIcons.circle);
    expect(DiarizationRepository('default').getSpeakerDiarization(), isFalse);
  });

  testWidgets('o checkbox nasce marcado quando a preferência já existe', (
    tester,
  ) async {
    PlatformSupport.debugForceSupportsGlobalHotkey(true);
    await setUpAppEnvironment();
    await DiarizationRepository('default').setSpeakerDiarization(true);
    await pumpCupertinoWidget(tester, const MainPage());
    await openSandboxTab(tester);

    expect(checkboxIcon(tester), CupertinoIcons.check_mark_circled_solid);
  });
}
