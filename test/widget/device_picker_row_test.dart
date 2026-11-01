import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:soniox_transcriptor/components/device_picker.dart';
import 'package:soniox_transcriptor/models/profile.dart';
import 'package:soniox_transcriptor/modules/local_storage_module.dart';
import 'package:soniox_transcriptor/repositories/recorder_repository.dart';

import '../helpers/widget_harness.dart';

/// Rótulo de microfone real: longo o bastante para não caber numa linha de
/// celular ao lado do rótulo "Dispositivo".
const _longLabel = 'MacBook Pro Microphone (Built-in) — agregado do sistema';

class _FakeRecorder extends RecorderRepository {
  @override
  Future<void> listInputDevices() async {
    devices = const [InputDevice(id: 'builtin', label: _longLabel)];
  }
}

void main() {
  testWidgets(
    'rótulo longo do dispositivo encolhe em vez de estourar a linha',
    (tester) async {
      await setUpAppEnvironment();
      await LocalStorageModule.setSelectedDeviceLabel(
        Profile.defaultId,
        _longLabel,
      );

      // Largura de celular: é onde a linha estourava e o texto aparecia
      // cortado.
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          child: CupertinoApp(
            home: CupertinoPageScaffold(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: DevicePicker(recorder: _FakeRecorder()),
              ),
            ),
          ),
        ),
      );
      // initState enumera em async: um pump para a conclusão, outro para o
      // setState.
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Dispositivo'), findsOneWidget);
      expect(find.text(_longLabel), findsOneWidget);
      expect(tester.widget<Text>(find.text(_longLabel)).maxLines, 1);
    },
  );
}
