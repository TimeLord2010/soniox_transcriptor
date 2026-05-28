import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

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
    return Column(
      crossAxisAlignment: .start,
      children: [
        Text('Chave soniox'),
        Row(
          children: [
            Expanded(child: _apiKeyField()),
            Gap(20),
            _saveApiKeyButton(),
          ],
        ),
      ],
    );
  }

  Widget _apiKeyField() {
    return GlassTextField(
      controller: _apiKeyController,
      useOwnLayer: true,
      placeholder: 'Enter API key',
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
      textStyle: TextStyle(color: Colors.black),
    );
  }

  Widget _saveApiKeyButton() {
    return GlassButton(
      onTap: _saveApiKey,
      useOwnLayer: true,
      icon: Icon(Icons.save, color: Colors.black),
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
