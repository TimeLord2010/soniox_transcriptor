import 'package:flutter/cupertino.dart';
import 'package:soniox_transcriptor/components/record_button.dart';
import 'package:soniox_transcriptor/components/sandbox_settings.dart';
import 'package:soniox_transcriptor/components/sandbox_text_field.dart';
import 'package:soniox_transcriptor/components/styles/ui.dart';
import 'package:soniox_transcriptor/models/languages.dart';

/// Aba Sandbox: captura comandada pelo botão (sempre visível, nas duas
/// plataformas), o acesso aos ajustes da captura e as caixas onde o texto ao
/// vivo aparece.
///
/// Sem rolagem na página: as caixas ocupam toda a altura que sobra da aba (a
/// barra inferior flutua sobre o conteúdo, daí o recuo de 58 px no rodapé).
///
/// Widget de desenho apenas: nada de provider, sessão ou toast aqui — o estado
/// vem por parâmetro e as ações saem por callback.
class SandboxTab extends StatelessWidget {
  const SandboxTab({
    super.key,
    required this.sandboxController,
    required this.sandboxFocusNode,
    required this.translationController,
    required this.translationTarget,
    required this.showNothingToTranslate,
    required this.isRecording,
    required this.pointerVerb,
    required this.onToggleRecording,
    required this.onCopySandbox,
    required this.onClearSandbox,
    required this.onCopyTranslation,
  });

  final TextEditingController sandboxController;
  final FocusNode sandboxFocusNode;
  final TextEditingController translationController;

  /// Língua alvo da tradução; `null` = tradução desligada.
  final Language? translationTarget;

  /// A fala veio na língua alvo: a caixa da tradução avisa em vez de ficar
  /// vazia sem explicação.
  final bool showNothingToTranslate;

  final bool isRecording;

  /// Verbo do gesto: `Clique` no desktop, `Toque` no celular.
  final String pointerVerb;

  final VoidCallback onToggleRecording;
  final VoidCallback onCopySandbox;
  final VoidCallback onClearSandbox;
  final VoidCallback onCopyTranslation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 58),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _recordControl(),
          const SizedBox(height: kSectionSpacing),
          Expanded(child: _textAreas()),
        ],
      ),
    );
  }

  /// As caixas de texto: a transcrição e, com a tradução ligada, a tradução
  /// embaixo dela. A tradução divide a altura com a transcrição em vez de virar
  /// uma terceira aba — as duas são lidas juntas.
  Widget _textAreas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: translationTarget == null ? 1 : 3, child: _sandbox()),
        if (translationTarget != null) ...[
          const SizedBox(height: kSectionSpacing),
          Expanded(flex: 2, child: _translation(translationTarget!)),
        ],
      ],
    );
  }

  /// Caixa da tradução: só leitura (quem escreve é o Soniox), com a língua alvo
  /// no cabeçalho e a mesma ação de copiar da sandbox.
  Widget _translation(Language target) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 32,
          child: Row(
            children: [
              Text('Tradução — ${target.label}', style: sectionLabelStyle),
              const Spacer(),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: translationController,
                builder: (context, value, _) {
                  return _sandboxAction(
                    key: const ValueKey('sandbox-translation-copy'),
                    label: 'Copiar',
                    icon: CupertinoIcons.doc_on_doc,
                    onPressed: value.text.isEmpty ? null : onCopyTranslation,
                  );
                },
              ),
            ],
          ),
        ),
        if (showNothingToTranslate) ...[
          const SizedBox(height: 2),
          Text(
            'Nada para traduzir: a fala já está em ${target.label}.',
            key: const ValueKey('sandbox-translation-empty'),
            style: const TextStyle(
              fontSize: 12,
              color: CupertinoColors.tertiaryLabel,
            ),
          ),
        ],
        const SizedBox(height: kLabelSpacing),
        Expanded(
          child: SandboxTextField(
            key: const ValueKey('sandbox-translation-field'),
            controller: translationController,
            readOnly: true,
            placeholder: 'A tradução aparece aqui durante a captura.',
          ),
        ),
      ],
    );
  }

  /// Comando de captura por toque/clique, com o acesso aos ajustes da captura
  /// no fim da mesma linha. Fica logo acima da sandbox porque é ali que o texto
  /// desta sessão vai aparecer (e no Android é o único jeito de abrir uma
  /// sessão).
  Widget _recordControl() {
    return Row(
      children: [
        Expanded(
          child: RecordButton(
            isRecording: isRecording,
            pointerVerb: pointerVerb,
            onPressed: onToggleRecording,
          ),
        ),
        const SizedBox(width: 8),
        _captureSettingsButton(),
      ],
    );
  }

  /// Ajustes da captura (diarização e tradução) num popup: na aba, cada opção
  /// virava uma linha e as duas empurravam a caixa de texto para baixo.
  Widget _captureSettingsButton() {
    return Builder(
      builder: (context) => CupertinoButton(
        key: const ValueKey('sandbox-settings'),
        padding: EdgeInsets.zero,
        pressedOpacity: 0.6,
        onPressed: () => showSandboxSettings(context),
        child: Container(
          height: 52,
          width: 52,
          alignment: Alignment.center,
          decoration: fieldDecoration(radius: 12),
          child: const Icon(
            CupertinoIcons.settings,
            size: 20,
            color: CupertinoColors.secondaryLabel,
          ),
        ),
      ),
    );
  }

  Widget _sandbox() {
    // O header com as ações acompanha o conteúdo: os botões ficam desabilitados
    // enquanto a sandbox está vazia, e para isso a UI precisa saber do texto.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 32,
          child: Row(
            children: [
              const Text('Sandbox', style: sectionLabelStyle),
              const Spacer(),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: sandboxController,
                builder: (context, value, _) {
                  final isEmpty = value.text.isEmpty;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _sandboxAction(
                        key: const ValueKey('sandbox-copy'),
                        label: 'Copiar',
                        icon: CupertinoIcons.doc_on_doc,
                        onPressed: isEmpty ? null : onCopySandbox,
                      ),
                      const SizedBox(width: 4),
                      _sandboxAction(
                        key: const ValueKey('sandbox-clear'),
                        label: 'Limpar',
                        icon: CupertinoIcons.trash,
                        onPressed: isEmpty ? null : onClearSandbox,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: kLabelSpacing),
        Expanded(
          child: SandboxTextField(
            key: const ValueKey('sandbox-field'),
            controller: sandboxController,
            focusNode: sandboxFocusNode,
          ),
        ),
      ],
    );
  }

  /// Ação do header da sandbox. `onPressed: null` desabilita (CupertinoButton
  /// cuida da cor apagada) — a ação só existe quando há o que copiar/apagar.
  Widget _sandboxAction({
    required Key key,
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return CupertinoButton(
      key: key,
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      pressedOpacity: 0.5,
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
