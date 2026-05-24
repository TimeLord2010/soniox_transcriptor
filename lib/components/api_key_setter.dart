import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../modules/local_storage_module.dart';
import '../protocols/show_toast.dart';

class ApiKeySetter extends ConsumerStatefulWidget {
  const ApiKeySetter({super.key, required this.onApiKeyChanged});

  final void Function(String? value) onApiKeyChanged;

  @override
  ConsumerState<ApiKeySetter> createState() => _ApiKeySetterState();
}

class _ApiKeySetterState extends ConsumerState<ApiKeySetter> {
  final _apiKeyController = TextEditingController();

  @override
  void initState() {
    _loadApiKey();
    super.initState();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _apiKeyField()),
        Gap(20),
        _saveApiKeyButton(),
      ],
    );
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

  // MARK: Events

  Future<void> _loadApiKey() async {
    final savedKey = LocalStorageModule.getApiKey();
    if (savedKey != null) {
      setState(() {
        _apiKeyController.text = savedKey;
      });
    }
    widget.onApiKeyChanged(savedKey);
  }

  Future<void> _saveApiKey() async {
    var key = _apiKeyController.text.isEmpty ? null : _apiKeyController.text;
    widget.onApiKeyChanged(key);
    await LocalStorageModule.setApiKey(key);
    if (mounted) showToast(context, 'API key saved.');
  }
}
