import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:soniox_transcriptor/providers/context_providers.dart';

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
      spacing: 5,
      crossAxisAlignment: .start,
      children: [
        Text('Contexto'),
        GlassTextArea(
          controller: _controller,
          maxLines: 3,
          useOwnLayer: true,
          onChanged: (value) {
            ref.read(contextProvider.notifier).setContext(value);
          },
          textStyle: TextStyle(color: Colors.black),
        ),
      ],
    );
  }
}
