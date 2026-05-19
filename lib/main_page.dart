import 'package:flutter/cupertino.dart';
import 'package:gap/gap.dart';
import 'package:soniox_transcriptor/protocols/show_toast.dart';

import 'local_repository.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadApiKey();
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
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Vit transcriptor'),
        backgroundColor: CupertinoColors.systemBackground,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(child: _apiKeyField()),
              Gap(20),
              _saveApiKeyButton(),
            ],
          ),
        ),
      ),
    );
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
