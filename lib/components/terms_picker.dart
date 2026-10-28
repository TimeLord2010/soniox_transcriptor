import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:soniox_transcriptor/components/mouse_enter_listener.dart';
import 'package:soniox_transcriptor/providers/context_providers.dart';

import 'styles/ui.dart';

class TermsPicker extends ConsumerStatefulWidget {
  const TermsPicker({super.key});

  @override
  ConsumerState<TermsPicker> createState() => _TermsPickerState();
}

class _TermsPickerState extends ConsumerState<TermsPicker> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final terms = ref.watch(termsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Termos', style: sectionLabelStyle),
        const Gap(kLabelSpacing),
        CupertinoTextField(
          controller: _controller,
          placeholder: 'Adicionar termo e pressionar Enter',
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: fieldDecoration(),
          style: const TextStyle(fontSize: 14),
          onSubmitted: (value) async {
            if (value.isEmpty) return;
            await ref.read(termsProvider.notifier).addTerm(value);
            _controller.clear();
          },
        ),
        if (terms.isNotEmpty) const Gap(10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final term in terms)
              MouseEnterListener(
                builder: (context, isMouseInside, child) {
                  return _TermChip(
                    label: term,
                    showDelete: isMouseInside,
                    onDelete: () async {
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

/// Termo salvo. O botão de excluir só aparece com o mouse em cima, como antes.
class _TermChip extends StatelessWidget {
  const _TermChip({
    required this.label,
    required this.showDelete,
    required this.onDelete,
  });

  final String label;
  final bool showDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 6, top: 6, bottom: 6),
      decoration: fieldDecoration(radius: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: showDelete
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: GestureDetector(
              onTap: onDelete,
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(
                  CupertinoIcons.xmark_circle_fill,
                  size: 14,
                  color: CupertinoColors.systemRed,
                ),
              ),
            ),
            secondChild: const SizedBox(width: 0, height: 14),
          ),
        ],
      ),
    );
  }
}
