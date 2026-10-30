import 'package:flutter/services.dart';

import 'package:soniox_transcriptor/modules/platform_support.dart';

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
/// Fora do macOS não existe handler nativo para o canal: toda chamada daqui é
/// ignorada em vez de virar `MissingPluginException` no log (o Android comanda a
/// sessão pelo botão de gravar).
class HotkeyListener {
  static const _hotkeyChannel = MethodChannel('hotkey_plugin');

  /// O plugin nativo só é registrado no runner do macOS.
  static bool get isSupported => PlatformSupport.supportsGlobalHotkey;

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
    if (isSupported) _hotkeyChannel.setMethodCallHandler(_onMethodCall);
  }

  Future<void> start() async {
    if (!isSupported) return;
    await _hotkeyChannel.invokeMethod('start');
  }

  static Future<void> stop() async {
    if (!isSupported) return;
    await _hotkeyChannel.invokeMethod('stop');
  }

  static Future<void> pasteText(String text) async {
    if (!isSupported) return;
    await _hotkeyChannel.invokeMethod('pasteText', text);
  }

  static Future<void> showOverlay() async {
    if (!isSupported) return;
    await _hotkeyChannel.invokeMethod('showOverlay');
  }

  /// Hides the overlay, optionally after [delay] so a message stays readable.
  static Future<void> hideOverlay({Duration? delay}) async {
    if (!isSupported) return;
    await _hotkeyChannel.invokeMethod(
      'hideOverlay',
      delay == null ? null : delay.inMilliseconds / 1000,
    );
  }

  /// Puts the overlay in an error state showing [message].
  static Future<void> showError(String message) async {
    if (!isSupported) return;
    await _hotkeyChannel.invokeMethod('showError', message);
  }

  static Future<void> setListening() async {
    if (!isSupported) return;
    await _hotkeyChannel.invokeMethod('setListening');
  }

  static Future<void> updateTranscription(
    String finalText,
    String nonFinalText,
  ) async {
    if (!isSupported) return;
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
