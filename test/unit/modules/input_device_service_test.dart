import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
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

  group('sondeio', () {
    const tick = Duration(milliseconds: 20);
    const wait = Duration(milliseconds: 90);

    test('lista em dia a cada intervalo e para ao soltar', () async {
      final hw = _FakeHardware();
      final service = InputDeviceService(
        fetch: hw.fetch,
        pollInterval: tick,
        observeLifecycle: false,
        changeEvents: () => null,
      );
      service.watch();
      await Future<void>.delayed(wait);
      expect(service.devices.map((d) => d.id), ['a']);

      hw.devices = [dev('a'), dev('b')];
      await Future<void>.delayed(wait);
      expect(service.devices.map((d) => d.id), ['a', 'b']);

      service.unwatch();
      final calls = hw.calls;
      await Future<void>.delayed(wait);
      expect(hw.calls, calls);
      service.dispose();
    });

    test('evento do sistema (web) atualiza sem sondar', () async {
      final hw = _FakeHardware();
      final events = StreamController<void>.broadcast();
      final service = InputDeviceService(
        fetch: hw.fetch,
        pollInterval: tick,
        observeLifecycle: false,
        changeEvents: () => events.stream,
      );
      service.watch();
      await Future<void>.delayed(wait);
      expect(hw.calls, 0);

      events.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(service.devices.map((d) => d.id), ['a']);
      service.unwatch();
      service.dispose();
      await events.close();
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
