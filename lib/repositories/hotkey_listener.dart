import 'package:flutter/services.dart';

class HotkeyListener {
  static const _hotkeyChannel = MethodChannel('hotkey_plugin');

  void Function() onKeyDown;
  void Function() onKeyUp;

  HotkeyListener({required this.onKeyDown, required this.onKeyUp}) {
    _hotkeyChannel.setMethodCallHandler(_onMethodCall);
  }

  Future<void> start() async {
    await _hotkeyChannel.invokeMethod('start');
  }

  static Future<void> stop() async {
    await _hotkeyChannel.invokeMethod('stop');
  }

  static Future<void> pasteText(String text) async {
    await _hotkeyChannel.invokeMethod('pasteText', text);
  }

  static Future<void> showOverlay() async {
    await _hotkeyChannel.invokeMethod('showOverlay');
  }

  static Future<void> hideOverlay() async {
    await _hotkeyChannel.invokeMethod('hideOverlay');
  }

  static Future<void> updateTranscription(String finalText, String nonFinalText) async {
    await _hotkeyChannel.invokeMethod('updateTranscription', {
      'finalText': finalText,
      'nonFinalText': nonFinalText,
    });
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
