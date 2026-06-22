import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:soniox_transcriptor/components/mouse_enter_listener.dart';
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
      crossAxisAlignment: .start,
      children: [
        Text('Termos'),
        Gap(5),
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
        Gap(10),
        Wrap(
          spacing: 10,
          children: [
            for (var term in terms)
              MouseEnterListener(
                builder: (context, isMouseInside, child) {
                  return GlassChip(
                    label: term,
                    labelStyle: TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                    settings: glassSettings,
                    deleteIcon: SizedBox(
                      width: 18,
                      child: AnimatedCrossFade(
                        duration: Duration(milliseconds: 300),
                        crossFadeState: isMouseInside
                            ? .showFirst
                            : .showSecond,
                        firstChild: Icon(
                          Icons.delete,
                          color: const Color.fromARGB(255, 156, 42, 34),
                        ),
                        secondChild: SizedBox.shrink(),
                      ),
                    ),
                    onDeleted: () async {
                      await ref.read(termsProvider.notifier).deleteTerm(term);
                    },
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}
