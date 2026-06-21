import 'package:flutter/services.dart';

/// Bridges Flutter to the native macOS hotkey plugin.
///
/// The native side lives in [macos/Runner/HotkeyPlugin.swift]. It uses
/// `NSEvent.addGlobalMonitorForEvents` to watch for the Right Option key
/// (keyCode 61, `.flagsChanged` events) system-wide — which requires macOS
/// Accessibility permission. When granted, the monitor fires regardless of
/// which app is in the foreground.
///
/// Communication goes through a [MethodChannel] named `"hotkey_plugin"`:
/// - Flutter → native: `start`, `stop`, `pasteText`, `showOverlay`,
///   `hideOverlay`, `updateTranscription`.
/// - Native → Flutter: `onHotkeyPressed` / `onHotkeyReleased`, which are
///   forwarded to [onKeyDown] and [onKeyUp].
///
/// The overlay is a frameless, always-on-top `NSPanel` built entirely in Swift
/// that shows a pulsing red dot and the live transcription text. Text pasting
/// is done by writing to `NSPasteboard` and synthesizing a `CGEvent` Cmd+V
/// keystroke directed at whatever app previously had focus.
class HotkeyListener {
  static const _hotkeyChannel = MethodChannel('hotkey_plugin');

  void Function() onKeyDown;
  void Function() onKeyUp;

  /// Called by the native side when the app is in the foreground and the
  /// transcription should be inserted directly into the focused Flutter field
  /// (instead of being pasted via a synthesized Cmd+V).
  void Function(String text)? onInsertText;

  HotkeyListener({
    required this.onKeyDown,
    required this.onKeyUp,
    this.onInsertText,
  }) {
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

  static Future<void> setListening() async {
    await _hotkeyChannel.invokeMethod('setListening');
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
      case 'insertText':
        if (call.arguments is String) {
          onInsertText?.call(call.arguments as String);
        }
    }
  }
}
