import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:soniox_transcriptor/models/soniox_model.dart';
import 'package:soniox_transcriptor/providers/models_providers.dart';

import 'styles/ui.dart';

/// Seletor do modelo de transcrição, dentro dos ajustes da captura.
///
/// A lista vem do Soniox (`GET /v1/models`), não do código: quando o Soniox
/// publica um modelo novo ele aparece aqui sem precisar de build. A escolha é
/// salva no perfil; sem escolha, vale o modelo de tempo real mais novo.
class ModelPicker extends ConsumerWidget {
  const ModelPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Modelo', style: sectionLabelStyle),
        const Gap(kLabelSpacing),
        MenuTrigger(
          key: const ValueKey('model-trigger'),
          onPressed: () => showCupertinoMenuPopup(context, const _ModelsMenu()),
          // Elástico: dentro do popup de ajustes a largura é curta.
          child: Flexible(
            child: Text(
              modelValueLabel(ref),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}

/// Nome do modelo em uso; aponta o automático quando a escolha é `null`.
String modelValueLabel(WidgetRef ref) {
  final models = ref.watch(sonioxModelsProvider).models;
  final selected = ref.watch(selectedModelProvider);
  final id = ref.watch(resolvedModelIdProvider);
  final name = _modelById(models, id)?.name ?? id;
  return selected == null ? '$name (automático)' : name;
}

/// Linha do grupo Captura na aba Início: mostra o modelo em uso e abre a mesma
/// lista do seletor no popup.
class ModelRow extends ConsumerWidget {
  const ModelRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsRow(
      key: const ValueKey('home-row-model'),
      label: 'Modelo',
      value: modelValueLabel(ref),
      onTap: () => showCupertinoMenuPopup(context, const _ModelsMenu()),
    );
  }
}

SonioxModel? _modelById(List<SonioxModel> models, String id) {
  for (final model in models) {
    if (model.id == id) return model;
  }
  return null;
}

/// Lista de modelos de tempo real. Seleção única: escolher fecha o popup.
class _ModelsMenu extends ConsumerWidget {
  const _ModelsMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sonioxModelsProvider);
    final selected = ref.watch(selectedModelProvider);
    final resolved = ref.watch(resolvedModelIdProvider);
    final automatic = _modelById(state.models, resolved);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 6, 4),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Modelo',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              CupertinoButton(
                key: const ValueKey('models-refresh'),
                padding: const EdgeInsets.all(6),
                onPressed: state.isLoading
                    ? null
                    : () => ref.read(sonioxModelsProvider.notifier).refresh(),
                child: state.isLoading
                    ? const CupertinoActivityIndicator(radius: 7)
                    : const Icon(
                        CupertinoIcons.arrow_clockwise,
                        size: 16,
                        color: CupertinoColors.secondaryLabel,
                      ),
              ),
            ],
          ),
        ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              state.error!,
              style: const TextStyle(
                fontSize: 12,
                color: CupertinoColors.systemRed,
              ),
            ),
          ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              // Automático = modelo estável mais novo que o Soniox publicar.
              // Continua sendo o padrão de quem nunca escolheu.
              MenuOptionRow(
                key: const ValueKey('model-auto'),
                label: automatic == null
                    ? 'Automático (mais novo)'
                    : 'Automático — ${automatic.name}',
                isSelected: selected == null,
                onTap: () {
                  ref.read(selectedModelProvider.notifier).select(null);
                  Navigator.pop(context);
                },
              ),
              for (final model in state.models)
                MenuOptionRow(
                  key: ValueKey('model-${model.id}'),
                  label: model.isAlias
                      ? '${model.name} (alias de ${model.aliasTarget})'
                      : model.name,
                  isSelected: selected == model.id,
                  onTap: () {
                    ref.read(selectedModelProvider.notifier).select(model.id);
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
