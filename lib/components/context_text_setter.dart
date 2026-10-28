import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:soniox_transcriptor/providers/context_providers.dart';

import 'styles/ui.dart';

class ContextTextSetter extends ConsumerStatefulWidget {
  const ContextTextSetter({super.key});

  @override
  ConsumerState<ContextTextSetter> createState() => _ContextTextSetterState();
}

class _ContextTextSetterState extends ConsumerState<ContextTextSetter> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final initialContext = ref.read(contextProvider);
    _controller = TextEditingController(text: initialContext);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Contexto', style: sectionLabelStyle),
        const Gap(kLabelSpacing),
        CupertinoTextField(
          controller: _controller,
          minLines: 3,
          maxLines: 3,
          padding: const EdgeInsets.all(12),
          decoration: fieldDecoration(),
          style: const TextStyle(fontSize: 14),
          onChanged: (value) {
            ref.read(contextProvider.notifier).setContext(value);
          },
        ),
      ],
    );
  }
}
