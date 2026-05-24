import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:soniox_transcriptor/components/api_key_setter.dart';
import 'package:soniox_transcriptor/protocols/show_toast.dart';
import 'package:super_hot_key/super_hot_key.dart';

import 'hotkey_config.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  bool _isRecording = false;
  final _focusNode = FocusNode();
  final _hotkeyConfig = GetIt.instance<HotkeyConfig>();
  String? _registeredHotKeyId;
  LogicalKeyboardKey? _transcriptionKey;

  @override
  void initState() {
    super.initState();
    _registerGlobalHotkey();
  }

  @override
  void dispose() {
    _unregisterGlobalHotkey();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        _handleKey(event);
        return KeyEventResult.handled;
      },
      child: CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('Vit transcriptor'),
          backgroundColor: CupertinoColors.systemBackground,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              spacing: 20,
              children: [ApiKeySetter(), _recordButton()],
            ),
          ),
        ),
      ),
    );
  }

  // Button to start recording a key press
  CupertinoButton _recordButton() {
    return CupertinoButton.filled(
      color: CupertinoColors.activeGreen,
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 0),
      onPressed: () {
        _focusNode.requestFocus();
        setState(() {
          _isRecording = true;
        });
        showToast(context, 'Press a key on your keyboard...');
      },
      child: const Text('Record'),
    );
  }

  // MARK: Events

  Future<void> _unregisterGlobalHotkey() async {
    if (_registeredHotKeyId != null) {
      await _hotkeyConfig.unregisterHotkey(_registeredHotKeyId!);
    }
  }

  void _onGlobalHotkeyPressed() {
    if (mounted) {
      showToast(context, 'Global hotkey triggered!');
    }
    print('global key pressed');
  }

  // Listen for keyboard events when recording
  void _handleKey(KeyEvent event) {
    if (!_isRecording) return;
    if (event is KeyDownEvent) {
      LogicalKeyboardKey logicalKey = event.logicalKey;
      final keyLabel = logicalKey.keyLabel;
      if (keyLabel.isNotEmpty) {
        _isRecording = false;
        _transcriptionKey = logicalKey;
        setState(() {});
        showToast(context, 'Key "$keyLabel" recorded.');
      }
    }
  }

  Future<void> _registerGlobalHotkey() async {
    try {
      final definition = HotKeyDefinition(key: PhysicalKeyboardKey.keyR);

      await _hotkeyConfig.registerHotkey(
        id: 'global_record',
        definition: definition,
        onPressed: _onGlobalHotkeyPressed,
      );

      _registeredHotKeyId = 'global_record';
    } catch (e) {
      if (mounted) {
        showToast(context, 'Failed to register global hotkey');
      }
    }
  }
}
