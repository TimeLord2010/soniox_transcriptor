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
  final VoidCallback onPressed;

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
