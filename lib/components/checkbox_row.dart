import 'package:flutter/cupertino.dart';
import 'package:gap/gap.dart';

/// Linha com uma marca de seleção clicável (o app é só-Cupertino e não tem
/// `Checkbox`; o equivalente nativo seria um switch, mas uma opção de sessão
/// booleana no meio do formulário lê melhor como caixa de marcar).
class CheckboxRow extends StatelessWidget {
  const CheckboxRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final String? hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      pressedOpacity: 0.6,
      onPressed: () => onChanged(!value),
      child: Row(
        children: [
          Icon(
            value
                ? CupertinoIcons.check_mark_circled_solid
                : CupertinoIcons.circle,
            size: 20,
            color: value
                ? CupertinoColors.activeBlue
                : CupertinoColors.secondaryLabel,
          ),
          const Gap(8),
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          if (hint != null) ...[
            const Gap(8),
            // Dica pode ser cortada: quem manda na largura é o rótulo.
            Flexible(
              child: Text(
                hint!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.tertiaryLabel,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
