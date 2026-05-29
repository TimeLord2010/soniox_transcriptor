import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:soniox_transcriptor/components/styles/glass_config.dart';
import 'package:soniox_transcriptor/providers/context_providers.dart';

class TermsPicker extends ConsumerStatefulWidget {
  const TermsPicker({super.key});

  @override
  ConsumerState<TermsPicker> createState() => _TermsPickerState();
}

class _TermsPickerState extends ConsumerState<TermsPicker> {
  final _controller = TextEditingController();
  @override
  Widget build(BuildContext context) {
    List<String> terms = ref.watch(termsProvider);
    return Column(
      spacing: 5,
      crossAxisAlignment: .start,
      children: [
        Text('Termos'),
        GlassTextField(
          controller: _controller,
          useOwnLayer: true,
          textStyle: TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
          onSubmitted: (value) async {
            if (value.isEmpty) return;
            await ref.read(termsProvider.notifier).addTerm(value);
            _controller.clear();
          },
        ),
        Wrap(
          spacing: 10,
          children: [
            for (var term in terms)
              GlassChip(
                label: term,
                labelStyle: TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                settings: glassSettings,
                deleteIcon: Icon(
                  Icons.delete,
                  color: const Color.fromARGB(255, 156, 42, 34),
                ),
                onDeleted: () async {
                  await ref.read(termsProvider.notifier).deleteTerm(term);
                },
              ),
          ],
        ),
      ],
    );
  }
}
