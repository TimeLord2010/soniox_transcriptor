import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:soniox_transcriptor/repositories/recorder_repository.dart';

/// Plugin cuja captura NUNCA abre — é o que o navegador faz quando a permissão
/// de microfone está travada (o `getUserMedia` não resolve nem rejeita).
class _HangingRecorder extends RecorderRepository {
  var openCalls = 0;

  @override
  Future<bool> hasPluginPermission() async => true;

  @override
  Future<Stream<Uint8List>> openAudioStream() {
    openCalls++;
    return Completer<Stream<Uint8List>>().future;
  }
}

/// Plugin que abre a captura mas não entrega áudio.
class _SilentRecorder extends RecorderRepository {
  @override
  Future<bool> hasPluginPermission() async => true;

  @override
  Future<Stream<Uint8List>> openAudioStream() async => const Stream.empty();
}

class _DeniedRecorder extends RecorderRepository {
  @override
  Future<bool> hasPluginPermission() async => false;

  @override
  Future<Stream<Uint8List>> openAudioStream() async => const Stream.empty();
}

void main() {
  test(
    'captura que nunca abre vira erro com aviso, em vez de travar',
    () async {
      final recorder = _HangingRecorder()
        ..startTimeout = const Duration(milliseconds: 150);
      final errors = <String>[];
      final sub = recorder.errors.listen(errors.add);

      final stopwatch = Stopwatch()..start();
      await recorder.start();
      stopwatch.stop();
      await pumpEventQueue();
      await sub.cancel();

      expect(errors, hasLength(1));
      expect(errors.single, contains('Não foi possível capturar áudio'));
      expect(errors.single, contains('não abriu em'));
      // Sem retry depois do estouro: uma tentativa e sai.
      expect(recorder.openCalls, 1);
      // Tem que voltar rápido, não ficar esperando o plugin.
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 3)));
    },
  );

  test('captura que abre mas fica muda também vira erro', () async {
    final recorder = _SilentRecorder();
    final errors = <String>[];
    final sub = recorder.errors.listen(errors.add);

    await recorder.start();
    // O erro sai num microtask do controller.
    await pumpEventQueue();
    await sub.cancel();

    expect(errors.single, contains('nenhum áudio chegou'));
  });

  test('permissão negada usa a mensagem do sistema', () async {
    final recorder = _DeniedRecorder();
    final errors = <String>[];
    final sub = recorder.errors.listen(errors.add);

    await recorder.start();
    // O erro sai num microtask do controller.
    await pumpEventQueue();
    await sub.cancel();

    expect(errors.single, startsWith('Permissão de microfone negada.'));
  });

  test('permissão que pendura não trava o botão', () async {
    final recorder = _HangingPermissionRecorder()
      ..startTimeout = const Duration(milliseconds: 150);
    final errors = <String>[];
    final sub = recorder.errors.listen(errors.add);

    await recorder.start();
    // O erro sai num microtask do controller.
    await pumpEventQueue();
    await sub.cancel();

    // Sem permissão confirmada, o app avisa em vez de abrir sessão muda.
    expect(errors.single, startsWith('Permissão de microfone negada.'));
  });
}

class _HangingPermissionRecorder extends _SilentRecorder {
  @override
  Future<bool> hasPluginPermission() => Completer<bool>().future;
}
