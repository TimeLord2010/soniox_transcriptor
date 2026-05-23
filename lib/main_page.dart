import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:get_it/get_it.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:soniox_transcriptor/protocols/show_toast.dart';

import 'hotkey_config.dart';
import 'local_repository.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final _apiKeyController = TextEditingController();
  bool _isRecording = false;
  final _focusNode = FocusNode();
  final _hotkeyConfig = GetIt.instance<HotkeyConfig>();
  HotKey? _registeredHotKey;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
    _registerGlobalHotkey();
  }

  @override
  void dispose() {
    _unregisterGlobalHotkey();
    _focusNode.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _registerGlobalHotkey() async {
    if (_apiKeyController.text.isEmpty) return;

    try {
      final hotKey = HotKey(
        key: PhysicalKeyboardKey.keyR,
        modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
        scope: HotKeyScope.system,
      );

      await _hotkeyConfig.registerHotkey(
        id: 'global_record',
        hotKey: hotKey,
        onPressed: _onGlobalHotkeyPressed,
      );

      _registeredHotKey = hotKey;
    } catch (e) {
      if (mounted) {
        showToast(context, 'Failed to register global hotkey');
      }
    }
  }

  Future<void> _unregisterGlobalHotkey() async {
    if (_registeredHotKey != null) {
      await _hotkeyConfig.unregisterHotkey(_registeredHotKey!);
    }
  }

  void _onGlobalHotkeyPressed() {
    if (mounted) {
      showToast(context, 'Global hotkey triggered!');
    }
  }

  Future<void> _loadApiKey() async {
    final savedKey = LocalRepository.getApiKey();
    if (savedKey != null) {
      setState(() {
        _apiKeyController.text = savedKey;
      });
    }
  }

  Future<void> _saveApiKey() async {
    LocalRepository.setApiKey(
      _apiKeyController.text.isEmpty ? null : _apiKeyController.text,
    );
    showToast(context, 'API key saved.');
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
              children: [_apiKeyComponents(), _recordButton()],
            ),
          ),
        ),
      ),
    );
  }

  Row _apiKeyComponents() {
    return Row(
      children: [
        Expanded(child: _apiKeyField()),
        Gap(20),
        _saveApiKeyButton(),
      ],
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

  // Listen for keyboard events when recording
  void _handleKey(KeyEvent event) {
    if (!_isRecording) return;
    if (event is KeyDownEvent) {
      final keyLabel = event.logicalKey.keyLabel;
      if (keyLabel.isNotEmpty) {
        setState(() {
          _apiKeyController.text = keyLabel;
          _isRecording = false;
        });
        showToast(context, 'Key "$keyLabel" recorded.');
      }
    }
  }

  CupertinoTextField _apiKeyField() {
    return CupertinoTextField(
      controller: _apiKeyController,
      placeholder: 'Enter API key',
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
      decoration: const BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.all(Radius.circular(8.0)),
      ),
    );
  }

  CupertinoButton _saveApiKeyButton() {
    return CupertinoButton.filled(
      color: CupertinoColors.activeBlue,
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 0),
      onPressed: _saveApiKey,
      child: const Text('Save'),
    );
  }
}
