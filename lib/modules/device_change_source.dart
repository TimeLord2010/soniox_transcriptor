import 'dart:async';

import 'device_change_source_stub.dart'
    if (dart.library.js_interop) 'device_change_source_web.dart'
    if (dart.library.io) 'device_change_source_native.dart'
    as impl;

/// Avisos do próprio sistema de que a lista de entradas mudou (plugar ou
/// tirar um microfone): `devicechange` no navegador e canal nativo do app no
/// macOS/Android. Nos demais sistemas devolve `null` (a lista só é relida ao
/// voltar ao primeiro plano e antes de gravar).
Stream<void>? deviceChangeEvents() => impl.deviceChangeEvents();
