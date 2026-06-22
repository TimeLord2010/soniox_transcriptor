import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:soniox_transcriptor/providers/context_providers.dart';

class ContextTextSetter extends ConsumerWidget {
  const ContextTextSetter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      spacing: 5,
      crossAxisAlignment: .start,
      children: [
        Text('Contexto'),
        GlassTextArea(
          maxLines: 3,
          onChanged: (value) {
            ref.read(contextText.notifier).state = value;
          },
          textStyle: TextStyle(color: Colors.black),
        ),
      ],
    );
  }
}
