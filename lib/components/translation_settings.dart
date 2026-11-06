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
    final spoken = ref.watch(languagesProvider);
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
                  label: _labelFor(language, spoken),
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

  /// Alvo igual à única língua de entrada não traduz nada: o Soniox devolve a
  /// fala com `translation_status: "none"` e nenhuma tradução. O rótulo avisa
  /// antes da escolha (com mais de uma língua de entrada, o par faz sentido).
  static String _labelFor(Language language, Set<Language> spoken) {
    final useless = spoken.length == 1 && spoken.contains(language);
    return useless
        ? '${language.label} (já é a língua de entrada)'
        : language.label;
  }
}

/// Linha do grupo Captura na aba Início: mostra se a tradução está ligada (e
/// para qual língua) e abre o controle num painel.
class TranslationRow extends ConsumerWidget {
  const TranslationRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(translationProvider);
    return SettingsRow(
      key: const ValueKey('home-row-translation'),
      label: 'Tradução',
      value: target == null ? 'desligada' : 'para ${target.label}',
      onTap: () => showSettingsPanel(
        context,
        title: 'Tradução',
        child: const _TranslationPanel(),
      ),
    );
  }
}

/// Conteúdo do painel da tradução: a mesma caixa de marcar e o mesmo seletor
/// de alvo das configurações, com o aviso de quando a escolha passa a valer.
class _TranslationPanel extends ConsumerWidget {
  const _TranslationPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: const [
        TranslationSettings(),
        Gap(10),
        Text(
          'Vale a partir da próxima captura.',
          style: TextStyle(fontSize: 12, color: CupertinoColors.tertiaryLabel),
        ),
      ],
    );
  }
}
