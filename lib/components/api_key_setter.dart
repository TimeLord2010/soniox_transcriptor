import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../local_repository.dart';
import '../protocols/show_toast.dart';

class ApiKeySetter extends ConsumerStatefulWidget {
  const ApiKeySetter({super.key});

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
}
