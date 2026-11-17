import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = EventChannel('com.vit.soniox/input_devices_changed');

/// macOS (CoreAudio) e Android (`AudioDeviceCallback`) avisam, por código
/// nativo do próprio app, quando uma entrada é plugada, removida ou muda o
/// padrão do sistema. O evento não traz a lista: só manda reler.
Stream<void>? deviceChangeEvents() {
  if (defaultTargetPlatform != TargetPlatform.macOS &&
      defaultTargetPlatform != TargetPlatform.android) {
    return null;
  }
  return _channel.receiveBroadcastStream().map((_) {});
}
