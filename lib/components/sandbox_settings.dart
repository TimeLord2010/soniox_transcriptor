import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:soniox_transcriptor/components/checkbox_row.dart';
import 'package:soniox_transcriptor/components/styles/ui.dart';
import 'package:soniox_transcriptor/components/translation_settings.dart';
import 'package:soniox_transcriptor/providers/context_providers.dart';

/// Ajustes da captura da sandbox (diarização e tradução) num popup só, aberto
/// pelo ícone de ajustes ao lado do botão de gravar.
///
/// Antes cada opção tinha sua linha na aba e as duas empurravam as caixas de
/// texto para baixo. Os controles continuam os mesmos (mesmos provedores, mesma
/// persistência por perfil) — só mudaram de lugar.
class SandboxSettings extends ConsumerWidget {
  const SandboxSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diarization = ref.watch(diarizationProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text(
            'Ajustes da captura',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckboxRow(
                key: const ValueKey('sandbox-diarization'),
                label: 'Diarização',
                hint: 'separa quem falou no texto',
                value: diarization,
                onChanged: (enabled) => ref
                    .read(diarizationProvider.notifier)
                    .setDiarization(enabled),
              ),
              const Gap(kLabelSpacing),
              TranslationSettings(key: const ValueKey('sandbox-translation')),
              const Gap(12),
              // Mudar aqui reconstrói a conexão com o Soniox: a captura em
              // andamento continua com a configuração com que começou.
              const Text(
                'Vale a partir da próxima captura.',
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.tertiaryLabel,
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 0.5,
            child: ColoredBox(color: CupertinoColors.separator),
          ),
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

/// Abre os ajustes da captura num popup centralizado.
Future<void> showSandboxSettings(BuildContext context) {
  return showCupertinoMenuPopup(context, const SandboxSettings());
}
