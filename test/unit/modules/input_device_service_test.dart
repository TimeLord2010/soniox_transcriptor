import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:soniox_transcriptor/modules/input_device_service.dart';
import 'package:soniox_transcriptor/repositories/recorder_repository.dart';

InputDevice dev(String id, [String? label]) =>
    InputDevice(id: id, label: label ?? 'Mic $id');

/// Fonte falsa: a lista "do hardware" é trocada à mão pelo teste.
class _FakeHardware {
  List<InputDevice> devices = [dev('a')];
  bool failing = false;
  int calls = 0;

  Future<List<InputDevice>> fetch() async {
    calls++;
    if (failing) throw StateError('sem enumerador');
    return List.of(devices);
  }
}

class _FakeRecorder extends RecorderRepository {
  _FakeRecorder(this.hardware);
  final _FakeHardware hardware;
  final opened = <String?>[];

  @override
  Future<List<InputDevice>> fetchInputDevices() => hardware.fetch();

  @override
  Future<bool> hasPluginPermission() async => true;

  @override
  Future<Stream<Uint8List>> openAudioStream() async {
    opened.add(selectedDevice?.id);
    return Stream.value(Uint8List(2));
  }
}

void main() {
  group('refresh', () {
    test('só notifica quando a lista muda (por id)', () async {
      final hw = _FakeHardware();
      final service = InputDeviceService(
        fetch: hw.fetch,
        observeLifecycle: false,
      );
      var notifications = 0;
      service.addListener(() => notifications++);

      expect(await service.refresh(), isTrue);
      expect(notifications, 1);

      // Mesma lista, outra ordem/instâncias: nada muda.
      hw.devices = [dev('a')];
      expect(await service.refresh(), isFalse);
      expect(notifications, 1);

      hw.devices = [dev('a'), dev('b')];
      expect(await service.refresh(), isTrue);
      expect(notifications, 2);
      expect(service.devices.map((d) => d.id), ['a', 'b']);
    });

    test('falha na enumeração mantém a lista anterior', () async {
      final hw = _FakeHardware();
      final service = InputDeviceService(
        fetch: hw.fetch,
        observeLifecycle: false,
      );
      await service.refresh();
      hw.failing = true;
      expect(await service.refresh(), isFalse);
      expect(service.devices.map((d) => d.id), ['a']);
    });
  });

  group('seleção', () {
    test(
      'some o microfone escolhido: cai para o padrão e volta quando reaparece',
      () async {
        final hw = _FakeHardware()..devices = [dev('a'), dev('b')];
        final service = InputDeviceService(
          fetch: hw.fetch,
          observeLifecycle: false,
        );
        await service.refresh();
        service.select(service.devices.last);
        expect(service.selected?.id, 'b');

        hw.devices = [dev('a')];
        await service.refresh();
        expect(service.selected, isNull); // padrão do sistema
        expect(service.preferredLabel, 'Mic b'); // preferência guardada

        hw.devices = [dev('a'), dev('b')];
        await service.refresh();
        expect(service.selected?.id, 'b');
      },
    );

    test('mudança de seleção por desplugar notifica os ouvintes', () async {
      final hw = _FakeHardware()..devices = [dev('a'), dev('b')];
      final service = InputDeviceService(
        fetch: hw.fetch,
        observeLifecycle: false,
      );
      await service.refresh();
      service.setPreferredLabel('Mic b');
      var notifications = 0;
      service.addListener(() => notifications++);

      hw.devices = [dev('a')];
      await service.refresh();
      expect(notifications, 1);
    });
  });

  group('avisos do sistema', () {
    test('evento nativo/web relê a lista; sem sondeio nenhum', () async {
      final hw = _FakeHardware();
      final events = StreamController<void>.broadcast();
      final service = InputDeviceService(
        fetch: hw.fetch,
        observeLifecycle: false,
        changeEvents: () => events.stream,
      );
      service.watch();
      // Sem timer: nada é consultado enquanto não houver evento.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(hw.calls, 0);

      events.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(hw.calls, 1);
      expect(service.devices.map((d) => d.id), ['a']);

      hw.devices = [dev('a'), dev('b')];
      events.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(service.devices.map((d) => d.id), ['a', 'b']);

      service.unwatch();
      expect(events.hasListener, isFalse);
      events.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(hw.calls, 2);
      service.dispose();
      await events.close();
    });

    test('sem fonte de eventos (outros sistemas) também não sonda', () async {
      final hw = _FakeHardware();
      final service = InputDeviceService(
        fetch: hw.fetch,
        observeLifecycle: false,
        changeEvents: () => null,
      );
      service.watch();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(hw.calls, 0);
      service.unwatch();
      service.dispose();
    });

    testWidgets('voltar ao primeiro plano relê uma vez', (tester) async {
      final hw = _FakeHardware();
      final service = InputDeviceService(
        fetch: hw.fetch,
        changeEvents: () => null,
      );
      service.watch();
      expect(hw.calls, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(hw.calls, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(hw.calls, 1);
      expect(service.devices.map((d) => d.id), ['a']);

      service.unwatch();
      service.dispose();
    });
  });

  group('gravador', () {
    test('antes de gravar revalida: microfone sumido usa o padrão', () async {
      final hw = _FakeHardware()..devices = [dev('a'), dev('b')];
      final recorder = _FakeRecorder(hw);
      await recorder.listInputDevices();
      recorder.deviceService.setPreferredLabel('Mic b');
      expect(recorder.selectedDevice?.id, 'b');

      // Desplugado sem ninguém observando: a lista do app está velha.
      hw.devices = [dev('a')];
      await recorder.start();

      expect(recorder.opened, [null]);
      await recorder.stop();
    });

    test('microfone ainda conectado é usado', () async {
      final hw = _FakeHardware()..devices = [dev('a'), dev('b')];
      final recorder = _FakeRecorder(hw);
      recorder.deviceService.setPreferredLabel('Mic b');

      await recorder.start();

      expect(recorder.opened, ['b']);
      await recorder.stop();
    });
  });
}
