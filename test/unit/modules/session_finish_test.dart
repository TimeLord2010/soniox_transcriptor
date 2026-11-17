import 'package:flutter_test/flutter_test.dart';
import 'package:soniox_transcriptor/modules/session_config.dart';
import 'package:soniox_transcriptor/modules/session_controller.dart';
import 'package:vit_soniox/vit_soniox.dart';

import '../../helpers/fake_session.dart';

class _Host implements SessionHost {
  final completed = <String>[];
  final emptySessions = <String>[];
  String? completedRef;
  int closed = 0;

  @override
  void onCompleted(
    String finalText,
    String nonFinal,
    String sandboxBaseText, {
    Duration? audioDuration,
    String? clientReferenceId,
  }) {
    completed.add(finalText + nonFinal);
    completedRef = clientReferenceId;
  }

  @override
  void onSessionWithoutText(String id, {Duration? audioDuration}) =>
      emptySessions.add(id);

  @override
  void onClosed() => closed++;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late FakeServer server;
  late FakeRecorder recorder;
  late _Host host;
  late SessionController controller;

  Future<void> startAndFlush() async {
    controller.startSession(fromButton: true);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() {
    server = FakeServer();
    recorder = FakeRecorder();
    host = _Host();
    controller = SessionController(
      host: host,
      recorder: recorder,
      supportsOverlay: false,
      diarizationEnabled: () => false,
      translationTarget: () => null,
      finishTimeout: const Duration(milliseconds: 50),
    );
    controller.rebuild(
      SonioxWebsocket(
        buildSessionConfig(
          apiKey: 'k',
          model: 'stt-rt-v5',
          languages: const [],
          speakerDiarization: false,
          translationTarget: null,
          contextText: '',
          terms: const [],
          clientReferenceId: 'ref-1',
        ),
        websocket: server,
      ),
    );
  });

  test(
    'manda o frame vazio, espera o finished e só então entrega o texto',
    () async {
      await startAndFlush();
      expect(server.sentConfig!['client_reference_id'], 'ref-1');

      final finishing = controller.finishSession();
      await Future<void>.delayed(Duration.zero);
      // O FakeServer responde `finished` ao frame vazio, como o Soniox.
      await finishing;

      expect(server.sentText.last, '');
      expect(host.completedRef, null, reason: 'sem texto não entrega');
      expect(host.emptySessions, ['ref-1']);
      expect(host.closed, 1);
    },
  );

  test('texto que chega antes do finished entra no resultado', () async {
    await startAndFlush();
    server.push({
      'tokens': [
        {'text': 'olá', 'is_final': true, 'start_ms': 0, 'end_ms': 1},
      ],
    });
    await Future<void>.delayed(Duration.zero);
    await controller.finishSession();

    expect(host.completed, ['olá']);
    expect(host.completedRef, 'ref-1');
    expect(host.emptySessions, isEmpty);
  });

  test('sem finished fecha mesmo assim depois do prazo', () async {
    server = FakeServer(autoFinish: false);
    controller.rebuild(
      SonioxWebsocket(
        buildSessionConfig(
          apiKey: 'k',
          model: 'stt-rt-v5',
          languages: const [],
          speakerDiarization: false,
          translationTarget: null,
          contextText: '',
          terms: const [],
          clientReferenceId: 'ref-2',
        ),
        websocket: server,
      ),
    );
    await startAndFlush();
    await controller.finishSession();

    expect(server.sentText.last, '');
    expect(host.emptySessions, ['ref-2']);
    expect(host.closed, 1);
  });

  test('referência é um UUID v4', () {
    expect(
      newClientReferenceId(),
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });
}
