import 'package:flutter/foundation.dart';
import 'package:super_hot_key/super_hot_key.dart';

class HotkeyConfig {
  static final HotkeyConfig _instance = HotkeyConfig._internal();
  final Map<String, HotKey> _hotKeys = {};

  factory HotkeyConfig() {
    return _instance;
  }

  HotkeyConfig._internal();

  Future<void> initialize() async {
    await unregisterAll();
  }

  Future<void> registerHotkey({
    required String id,
    required HotKeyDefinition definition,
    required VoidCallback onPressed,
  }) async {
    await unregisterHotkey(id);

    final hotKey = await HotKey.create(
      definition: definition,
      onPressed: onPressed,
    );

    if (hotKey != null) {
      _hotKeys[id] = hotKey;
      print('Hotkey "$id" registered successfully');
    } else {
      print('Hotkey "$id" registration failed (key not found in layout or platform unsupported)');
    }
  }

  Future<void> unregisterHotkey(String id) async {
    final hotKey = _hotKeys.remove(id);
    if (hotKey != null) {
      await hotKey.dispose();
    }
  }

  HotKey? getHotKey(String id) => _hotKeys[id];

  Future<void> unregisterAll() async {
    for (final hotKey in _hotKeys.values) {
      await hotKey.dispose();
    }
    _hotKeys.clear();
  }
}
