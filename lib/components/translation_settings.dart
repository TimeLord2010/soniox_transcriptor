import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:soniox_transcriptor/components/checkbox_row.dart';
import 'package:soniox_transcriptor/models/languages.dart';
import 'package:soniox_transcriptor/providers/context_providers.dart';

import 'styles/ui.dart';

/// Controle da tradução ao vivo: uma caixa de marcar e, quando ligada, a
/// língua alvo. O Soniox só traduz one-way com alvo definido, então os dois
/// andam juntos — o seletor de alvo só existe com a tradução ligada.
///
/// Aparece na aba Início (ajuste de perfil) e na Sandbox (ajuste de sessão),
/// sempre lendo o mesmo provedor: mexer em um lugar reflete no outro.
class TranslationSettings extends ConsumerWidget {
  const TranslationSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(translationProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxRow(
          key: const ValueKey('translation-toggle'),
          label: 'Traduzir',
          hint: 'texto traduzido ao vivo',
          value: target != null,
          onChanged: (enabled) =>
              ref.read(translationProvider.notifier).setEnabled(enabled),
        ),
        if (target != null) ...[
          const Gap(kLabelSpacing),
          MenuTrigger(
            key: const ValueKey('translation-target'),
            onPressed: () =>
                showCupertinoMenuPopup(context, const _TranslationTargetMenu()),
            // Elástico: dentro do popup de ajustes a largura é curta, e um
            // rótulo rígido estouraria a linha em vez de encolher.
            child: Flexible(
              child: Text(
                'Língua alvo: ${target.label}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Lista de línguas alvo. Seleção única: escolher fecha o popup.
class _TranslationTargetMenu extends ConsumerWidget {
  const _TranslationTargetMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(translationProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Text(
            'Traduzir para',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final language in Language.values)
                MenuOptionRow(
                  label: language.label,
                  isSelected: target == language,
                  onTap: () {
                    ref.read(translationProvider.notifier).setTarget(language);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}
