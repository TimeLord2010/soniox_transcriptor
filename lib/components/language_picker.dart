import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:soniox_transcriptor/models/languages.dart';
import 'package:soniox_transcriptor/providers/context_providers.dart';

import 'styles/ui.dart';

class LanguagePicker extends ConsumerWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final langs = ref.watch(languagesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Línguas', style: sectionLabelStyle),
        const Gap(kLabelSpacing),
        MenuTrigger(
          onPressed: () =>
              showCupertinoMenuPopup(context, const _LanguagesMenu()),
          child: _currentSelection(langs),
        ),
      ],
    );
  }

  Widget _currentSelection(Set<Language> langs) {
    if (langs.isEmpty) {
      return const Text(
        'Nenhuma língua selecionada',
        style: TextStyle(
          fontStyle: FontStyle.italic,
          fontSize: 14,
          color: CupertinoColors.placeholderText,
        ),
      );
    }
    return Text(
      langs.map((x) => x.label).join(', '),
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
    );
  }
}

/// Línguas de entrada em uso, do jeito que a linha da Início mostra.
String languageValueLabel(Set<Language> langs) {
  if (langs.isEmpty) return 'nenhuma';
  return langs.map((x) => x.label).join(', ');
}

/// Linha do grupo Captura na aba Início: mostra as línguas de entrada e abre a
/// mesma lista de marcar do seletor.
class LanguageRow extends ConsumerWidget {
  const LanguageRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final langs = ref.watch(languagesProvider);
    return SettingsRow(
      key: const ValueKey('home-row-languages'),
      label: 'Línguas',
      value: languageValueLabel(langs),
      valueColor: langs.isEmpty ? CupertinoColors.systemOrange : null,
      onTap: () => showCupertinoMenuPopup(context, const _LanguagesMenu()),
    );
  }
}

/// Lista de línguas no popup. Diferente de um menu comum, marcar uma língua
/// não fecha o popup: a seleção é múltipla.
class _LanguagesMenu extends ConsumerWidget {
  const _LanguagesMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final langs = ref.watch(languagesProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Text(
            'Línguas',
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
                  isSelected: langs.contains(language),
                  onTap: () => ref
                      .read(languagesProvider.notifier)
                      .toggleLanguage(language),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(height: 0.5, color: CupertinoColors.separator),
        ),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(vertical: 12),
          onPressed: () => Navigator.pop(context),
          child: const Text('Pronto'),
        ),
      ],
    );
  }
}
