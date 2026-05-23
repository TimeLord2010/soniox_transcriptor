import 'package:flutter/foundation.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

class HotkeyConfig {
  static final HotkeyConfig _instance = HotkeyConfig._internal();

  factory HotkeyConfig() {
    return _instance;
  }

  HotkeyConfig._internal();

  Future<void> initialize() async {
    await hotKeyManager.unregisterAll();
  }

  Future<void> registerHotkey({
    required String id,
    required HotKey hotKey,
    required VoidCallback onPressed,
  }) async {
    await hotKeyManager.register(
      hotKey,
      keyDownHandler: (hotKey) {
        onPressed();
      },
    );
  }

  Future<void> unregisterHotkey(HotKey hotKey) async {
    await hotKeyManager.unregister(hotKey);
  }

  Future<void> unregisterAll() async {
    await hotKeyManager.unregisterAll();
  }
}
