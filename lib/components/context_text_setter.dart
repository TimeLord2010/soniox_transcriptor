import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:soniox_transcriptor/providers/context_providers.dart';

import 'styles/ui.dart';

class ContextTextSetter extends ConsumerStatefulWidget {
  const ContextTextSetter({super.key, this.showLabel = true});

  /// Rótulo de seção. Falso dentro de um painel, onde o título já o diz.
  final bool showLabel;

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
        if (widget.showLabel) ...const [
          Text('Contexto', style: sectionLabelStyle),
          Gap(kLabelSpacing),
        ],
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

/// Linha do grupo Reconhecimento na aba Início: o contexto é parâmetro da
/// conexão com o Soniox (conteúdo do perfil), mostrado pelo que está
/// preenchido e editado num painel.
class ContextRow extends ConsumerWidget {
  const ContextRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contextText = ref.watch(contextProvider).trim();
    return SettingsRow(
      key: const ValueKey('home-row-context'),
      label: 'Contexto',
      value: contextText.isEmpty ? 'vazio' : contextText.replaceAll('\n', ' '),
      onTap: () => showSettingsPanel(
        context,
        title: 'Contexto',
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ContextTextSetter(showLabel: false),
            Gap(10),
            Text(
              'Texto de apoio para o Soniox reconhecer nomes e termos do '
              'assunto. Vale a partir da próxima captura.',
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.tertiaryLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
