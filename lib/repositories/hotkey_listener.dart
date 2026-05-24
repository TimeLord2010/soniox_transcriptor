import 'package:flutter/services.dart';

class HotkeyListener {
  static const _hotkeyChannel = MethodChannel('hotkey_plugin');

  void Function() onKeyDown;
  void Function() onKeyUp;

  HotkeyListener({required this.onKeyDown, required this.onKeyUp});

  Future<void> start() async {
    await stop();
    _hotkeyChannel.setMethodCallHandler(_onMethodCall);
    await _hotkeyChannel.invokeMethod('start');
  }

  static Future<void> stop() async {
    await _hotkeyChannel.invokeMethod('stop');
    _hotkeyChannel.setMethodCallHandler(null);
  }

  static Future<void> pasteText(String text) async {
    await _hotkeyChannel.invokeMethod('pasteText', text);
  }

  Future<void> _onMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onHotkeyPressed':
        onKeyDown();
      case 'onHotkeyReleased':
        onKeyUp();
    }
  }
}
