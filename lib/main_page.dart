import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:soniox_transcriptor/protocols/show_toast.dart';

import 'local_repository.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final _controller = TextEditingController();
  bool _isRecording = false;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _loadApiKey();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadApiKey() async {
    final savedKey = LocalRepository.getApiKey();
    if (savedKey != null) {
      setState(() {
        _controller.text = savedKey;
      });
    }
  }

  Future<void> _saveApiKey() async {
    LocalRepository.setApiKey(
      _controller.text.isEmpty ? null : _controller.text,
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
          _controller.text = keyLabel;
          _isRecording = false;
        });
        showToast(context, 'Key "$keyLabel" recorded.');
      }
    }
  }

  CupertinoTextField _apiKeyField() {
    return CupertinoTextField(
      controller: _controller,
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
