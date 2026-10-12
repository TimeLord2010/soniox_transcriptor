import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../providers/api_key_provider.dart';
import '../protocols/show_toast.dart';

class ApiKeySetter extends ConsumerStatefulWidget {
  const ApiKeySetter({super.key});

  @override
  ConsumerState<ApiKeySetter> createState() => _ApiKeySetterState();
}

class _ApiKeySetterState extends ConsumerState<ApiKeySetter> {
  // Seeded once; the parent re-keys this widget per profile so the field
  // shows the new profile's key after a switch.
  late final _apiKeyController = TextEditingController(
    text: ref.read(apiKeyProvider),
  );

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
      obscureText: true,
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

  Future<void> _saveApiKey() async {
    await ref.read(apiKeyProvider.notifier).setApiKey(_apiKeyController.text);
    if (mounted) showToast(context, 'API key saved.');
  }
}
