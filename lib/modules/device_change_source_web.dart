import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// `navigator.mediaDevices` dispara `devicechange` ao plugar/tirar um
/// microfone.
Stream<void>? deviceChangeEvents() {
  final devices = web.window.navigator.mediaDevices;
  late final StreamController<void> controller;
  final listener = ((web.Event _) {
    if (!controller.isClosed) controller.add(null);
  }).toJS;
  controller = StreamController<void>.broadcast(
    onListen: () => devices.addEventListener('devicechange', listener),
    onCancel: () => devices.removeEventListener('devicechange', listener),
  );
  return controller.stream;
}
