import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soniox_transcriptor/components/device_picker.dart';
import 'package:soniox_transcriptor/repositories/recorder_repository.dart';

import '../helpers/widget_harness.dart';

/// Gravador com enumeração pendente: é o que acontece no navegador, onde
/// `enumerateDevices` só devolve rótulos depois da permissão de microfone.
class _SlowRecorder extends RecorderRepository {
  final completer = Completer<void>();

  @override
  Future<void> listInputDevices() => completer.future;
}

void main() {
  testWidgets(
    'sair da tela antes da enumeração não chama setState após dispose',
    (tester) async {
      await setUpAppEnvironment();
      final recorder = _SlowRecorder();

      await pumpCupertinoWidget(tester, DevicePicker(recorder: recorder));

      // A aba é trocada com a enumeração ainda pendente.
      await tester.pumpWidget(const SizedBox.shrink());

      recorder.completer.complete();
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );
}
