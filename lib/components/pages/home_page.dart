import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:soniox_transcriptor/components/android_keyboard_setter.dart';
import 'package:soniox_transcriptor/components/api_key_setter.dart';
import 'package:soniox_transcriptor/components/context_text_setter.dart';
import 'package:soniox_transcriptor/components/device_picker.dart';
import 'package:soniox_transcriptor/components/language_picker.dart';
import 'package:soniox_transcriptor/components/model_picker.dart';
import 'package:soniox_transcriptor/components/profile_selector.dart';
import 'package:soniox_transcriptor/components/styles/ui.dart';
import 'package:soniox_transcriptor/components/terms_picker.dart';
import 'package:soniox_transcriptor/components/translation_settings.dart';
import 'package:soniox_transcriptor/modules/platform_support.dart';
import 'package:soniox_transcriptor/providers/api_key_provider.dart';
import 'package:soniox_transcriptor/providers/profile_providers.dart';
import 'package:soniox_transcriptor/repositories/recorder_repository.dart';

/// Aba Início: o que a captura vai usar, por grupo, com o valor atual à vista.
///
/// Antes esta tela era uma coluna única de nove blocos com o mesmo peso visual
/// (perfil, chave, modelo, dispositivo, termos, línguas, tradução, contexto e
/// teclado) — nada dizia o que era conta, o que era escolha de sessão e o que
/// era conteúdo do trabalho, e o usuário rolava a tela para achar o ajuste.
/// Agora a hierarquia é explícita:
///
/// - cabeçalho: perfil ativo e estado da chave (a conta, mexida uma vez);
/// - Captura: modelo, microfone, línguas e tradução (escolha de sessão);
/// - Reconhecimento: termos e contexto (conteúdo que muda a cada trabalho);
/// - Sistema: teclado de ditado, só no Android.
///
/// Cada linha mostra o valor em uso e abre o MESMO controle de antes num
/// painel — nenhuma opção nova, nenhum estado novo.
class HomePage extends ConsumerWidget {
  const HomePage({super.key, required this.recorder});

  final RecorderRepository recorder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileId = ref.watch(activeProfileIdProvider);
    final hasApiKey = ref.watch(apiKeyProvider).isNotEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 18,
        children: [
          _header(context, hasApiKey),
          SettingsGroup(
            title: 'CAPTURA',
            children: [
              const ModelRow(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kRowPadding),
                child: SizedBox(
                  height: kRowHeight,
                  child: DevicePicker(
                    key: ValueKey('device-$profileId'),
                    recorder: recorder,
                  ),
                ),
              ),
              const LanguageRow(),
              const TranslationRow(),
            ],
          ),
          SettingsGroup(
            title: 'RECONHECIMENTO',
            children: [
              TermsRow(key: ValueKey('terms-$profileId')),
              ContextRow(key: ValueKey('context-$profileId')),
            ],
          ),
          if (PlatformSupport.isAndroid)
            const SettingsGroup(
              title: 'SISTEMA',
              children: [AndroidKeyboardRow()],
            ),
        ],
      ),
    );
  }

  /// Perfil ativo à esquerda e estado da chave à direita. O aviso de "sem
  /// chave" deixou de ser um bloco laranja: ele É o estado nesta linha, e o
  /// campo para colar a chave abre no painel.
  Widget _header(BuildContext context, bool hasApiKey) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: ProfileSelector(compact: true),
              ),
            ),
            const Gap(12),
            const ApiKeyStatusButton(),
          ],
        ),
        if (!hasApiKey) ...[
          const Gap(6),
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text(
              'Sem chave Soniox neste perfil: a captura não abre sessão.',
              key: ValueKey('home-missing-key'),
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.systemOrange,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
