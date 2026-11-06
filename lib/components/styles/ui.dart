import 'package:flutter/cupertino.dart';
import 'package:gap/gap.dart';

/// Espaçamento entre as seções do formulário principal.
const double kSectionSpacing = 20;

/// Espaçamento entre um rótulo e o controle logo abaixo dele.
const double kLabelSpacing = 6;

/// Rótulo de seção ("Chave soniox", "Termos", ...).
const sectionLabelStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w600,
  color: CupertinoColors.secondaryLabel,
);

/// Fundo de campos, chips e controles: branco sobre o cinza agrupado da página.
BoxDecoration fieldDecoration({double radius = 8}) {
  return BoxDecoration(
    color: CupertinoColors.systemBackground,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: CupertinoColors.separator, width: 0.5),
  );
}

/// Botão com cara de controle de formulário: superfície branca + chevron.
class MenuTrigger extends StatelessWidget {
  const MenuTrigger({super.key, required this.child, required this.onPressed});

  final Widget child;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: fieldDecoration(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            child,
            const Gap(8),
            const Icon(
              CupertinoIcons.chevron_up_chevron_down,
              size: 12,
              color: CupertinoColors.secondaryLabel,
            ),
          ],
        ),
      ),
    );
  }
}

/// Abre [child] num popup centralizado, no estilo dos menus do macOS.
Future<void> showCupertinoMenuPopup(BuildContext context, Widget child) {
  return showCupertinoModalPopup<void>(
    context: context,
    barrierColor: const Color(0x33000000),
    builder: (_) => Center(
      child: CupertinoPopupSurface(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320, maxHeight: 420),
          child: child,
        ),
      ),
    ),
  );
}

/// Linha de opção de menu: rótulo à esquerda e check quando selecionada.
class MenuOptionRow extends StatelessWidget {
  const MenuOptionRow({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      pressedOpacity: 0.6,
      onPressed: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15),
              ),
            ),
            if (isSelected)
              const Icon(
                CupertinoIcons.check_mark,
                size: 16,
                color: CupertinoColors.activeBlue,
              ),
          ],
        ),
      ),
    );
  }
}

// MARK: Agrupamento da aba Início

/// Rótulo de grupo ("Captura", "Reconhecimento"): menor e em caixa alta para
/// não competir com o rótulo de cada linha.
const groupLabelStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.6,
  color: CupertinoColors.secondaryLabel,
);

/// Altura de uma linha de ajuste. Casa com o alvo mínimo de toque do sistema.
const double kRowHeight = 44;

/// Recuo horizontal (e das separadoras internas) das linhas de ajuste.
const double kRowPadding = 14;

/// Superfície do grupo: cartão branco com fio de separação, como os blocos de
/// Ajustes do macOS.
BoxDecoration groupDecoration() => fieldDecoration(radius: 10);

/// Grupo de ajustes: rótulo pequeno em cima e um cartão com as linhas separadas
/// por fio interno.
///
/// Existe porque a aba Início empilhava nove seções com o MESMO peso visual:
/// nada dizia o que era conta, o que era sessão e o que era conteúdo. Agrupar
/// devolve a hierarquia sem esconder nada atrás de navegação.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(
          Container(
            height: 0.5,
            margin: const EdgeInsets.only(left: kRowPadding),
            color: CupertinoColors.separator,
          ),
        );
      }
      rows.add(children[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: kLabelSpacing),
          child: Text(title, style: groupLabelStyle),
        ),
        Container(
          decoration: groupDecoration(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Column(children: rows),
          ),
        ),
      ],
    );
  }
}

/// Linha de ajuste: rótulo à esquerda, valor atual à direita e chevron.
///
/// O valor visível é o ponto: dá para conferir com o que a captura vai rodar
/// sem abrir nada. Tocar abre o controle num painel ([showSettingsPanel]).
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
    this.valueColor,
    this.showChevron = true,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final Color? valueColor;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      pressedOpacity: 0.5,
      onPressed: onTap,
      child: Container(
        height: kRowHeight,
        padding: const EdgeInsets.symmetric(horizontal: kRowPadding),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 14)),
            const Gap(12),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  color: valueColor ?? CupertinoColors.secondaryLabel,
                ),
              ),
            ),
            if (showChevron) ...const [
              Gap(6),
              Icon(
                CupertinoIcons.chevron_forward,
                size: 13,
                color: CupertinoColors.tertiaryLabel,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Painel de ajuste aberto por uma linha da Início: mesmo controle de antes,
/// agora um toque adiante em vez de empilhado na tela.
Future<void> showSettingsPanel(
  BuildContext context, {
  required String title,
  required Widget child,
  double maxWidth = 420,
  double maxHeight = 560,
}) {
  return showCupertinoModalPopup<void>(
    context: context,
    barrierColor: const Color(0x33000000),
    builder: (popupContext) => Center(
      child: CupertinoPopupSurface(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      key: const ValueKey('settings-panel-close'),
                      padding: const EdgeInsets.all(6),
                      onPressed: () => Navigator.pop(popupContext),
                      child: const Icon(
                        CupertinoIcons.xmark,
                        size: 16,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ],
                ),
                const Gap(6),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(right: 8),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
