import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../providers/api_key_provider.dart';
import '../protocols/show_toast.dart';
import 'styles/ui.dart';

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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Chave soniox', style: sectionLabelStyle),
        const Gap(kLabelSpacing),
        Row(
          children: [
            Expanded(child: _apiKeyField()),
            const Gap(12),
            _iconButton(CupertinoIcons.doc_on_doc, _copyApiKey),
            const Gap(6),
            _iconButton(CupertinoIcons.check_mark_circled, _saveApiKey),
          ],
        ),
      ],
    );
  }

  Widget _apiKeyField() {
    return CupertinoTextField(
      controller: _apiKeyController,
      placeholder: 'Enter API key',
      obscureText: true,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: fieldDecoration(),
      style: const TextStyle(fontSize: 14),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return CupertinoButton(
      padding: const EdgeInsets.all(10),
      color: CupertinoColors.systemBackground,
      borderRadius: BorderRadius.circular(8),
      onPressed: onTap,
      child: Icon(icon, size: 18, color: CupertinoColors.label),
    );
  }

  // The field is obscured, and Flutter disables copying from obscured fields,
  // so this is the only way to get the key out of the app.
  Future<void> _copyApiKey() async {
    final apiKey = _apiKeyController.text;
    if (apiKey.isEmpty) {
      showToast(context, 'No API key to copy.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: apiKey));
    if (mounted) showToast(context, 'API key copied.');
  }

  Future<void> _saveApiKey() async {
    await ref.read(apiKeyProvider.notifier).setApiKey(_apiKeyController.text);
    if (mounted) showToast(context, 'API key saved.');
  }
}
