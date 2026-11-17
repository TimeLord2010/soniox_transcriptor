import 'dart:async';

import 'device_change_source_stub.dart'
    if (dart.library.js_interop) 'device_change_source_web.dart'
    as impl;

/// Avisos do próprio sistema de que a lista de entradas mudou (plugar ou
/// tirar um microfone). Só o navegador tem esse evento (`devicechange`); nos
/// demais sistemas devolve `null` e quem chama consulta a lista de tempos em
/// tempos.
Stream<void>? deviceChangeEvents() => impl.deviceChangeEvents();
