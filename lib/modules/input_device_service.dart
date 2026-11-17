import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:record/record.dart';

import 'device_change_source.dart';

/// Fonte única da lista de microfones e da escolha do usuário.
///
/// A lista antes era lida uma vez, ao abrir a tela: plugar um microfone não
/// aparecia, e um microfone escolhido e depois desplugado era aberto mesmo
/// assim na próxima gravação (a captura falhava). Agora:
///  - [refresh] relê a lista e só avisa os ouvintes se ela mudou (por id);
///  - [watch] mantém a lista em dia por avisos do sistema (CoreAudio no macOS,
///    `AudioDeviceCallback` no Android, `devicechange` no navegador), sem
///    sondar; ao voltar para o primeiro plano relê uma vez, de garantia;
///  - a preferência do usuário (rótulo) fica guardada; [selected] é o
///    dispositivo EFETIVO — a preferência se estiver conectada, senão
///    `null` (= padrão do sistema). Se o microfone volta, volta a valer.
class InputDeviceService extends ChangeNotifier {
  InputDeviceService({
    required this.fetch,
    Stream<void>? Function()? changeEvents,
    this.observeLifecycle = true,
  }) : _changeEvents = changeEvents ?? deviceChangeEvents;

  /// Enumera as entradas (plugin `record`).
  final Future<List<InputDevice>> Function() fetch;
  final Stream<void>? Function() _changeEvents;
  final bool observeLifecycle;

  List<InputDevice> _devices = const [];
  String? _preferredLabel;

  int _watchers = 0;
  StreamSubscription<void>? _eventsSubscription;
  AppLifecycleListener? _lifecycle;
  bool _refreshing = false;
  bool _disposed = false;

  List<InputDevice> get devices => _devices;

  /// Preferência guardada (rótulo), conectada ou não.
  String? get preferredLabel => _preferredLabel;

  /// Dispositivo efetivo: a preferência se estiver conectada; `null` = padrão.
  InputDevice? get selected {
    final label = _preferredLabel;
    if (label == null) return null;
    for (final device in _devices) {
      if (device.label == label) return device;
    }
    return null;
  }

  /// Define a preferência (rótulo guardado no perfil). `null` = padrão.
  void setPreferredLabel(String? label) {
    if (_preferredLabel == label) return;
    _preferredLabel = label;
    _notify();
  }

  void select(InputDevice? device) => setPreferredLabel(device?.label);

  /// Relê a lista. Devolve `true` se ela mudou. Falha na enumeração mantém a
  /// lista anterior (não derruba a seleção por um erro passageiro).
  Future<bool> refresh() async {
    if (_refreshing || _disposed) return false;
    _refreshing = true;
    try {
      List<InputDevice> fresh;
      try {
        fresh = await fetch();
      } catch (error) {
        debugPrint('[devices] listInputDevices falhou: $error');
        return false;
      }
      if (_disposed) return false;
      final changed = !sameDevices(_devices, fresh);
      if (changed) {
        _devices = List.unmodifiable(fresh);
        debugPrint('[devices] lista: ${fresh.map((d) => d.label).join(',')}');
        _notify();
      }
      return changed;
    } finally {
      _refreshing = false;
    }
  }

  /// Dois conjuntos são iguais se têm os mesmos ids (e rótulos, que no web só
  /// aparecem depois da permissão).
  @visibleForTesting
  static bool sameDevices(List<InputDevice> a, List<InputDevice> b) {
    if (a.length != b.length) return false;
    final labels = {for (final d in a) d.id: d.label};
    for (final d in b) {
      if (!labels.containsKey(d.id) || labels[d.id] != d.label) return false;
    }
    return true;
  }

  /// Começa a manter a lista em dia. Contado: cada `watch` precisa de um
  /// [unwatch].
  void watch() {
    _watchers++;
    if (_watchers > 1) return;
    _eventsSubscription = _changeEvents()?.listen((_) => refresh());
    if (observeLifecycle) {
      _lifecycle = AppLifecycleListener(
        onStateChange: (state) {
          if (state == AppLifecycleState.resumed) refresh();
        },
      );
    }
  }

  void unwatch() {
    if (_watchers == 0) return;
    _watchers--;
    if (_watchers > 0) return;
    _eventsSubscription?.cancel();
    _eventsSubscription = null;
    _lifecycle?.dispose();
    _lifecycle = null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _eventsSubscription?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }
}
