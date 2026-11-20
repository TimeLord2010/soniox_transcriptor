import 'package:flutter/cupertino.dart';

/// Comando de gravação por toque/clique, disponível nas duas plataformas.
///
/// No Android é o único jeito de abrir a captura. No macOS convive com a tecla
/// global: a tecla cola o resultado no app em foco, enquanto a sessão aberta
/// aqui entrega o texto na sandbox.
///
/// Existe apenas FORA da captura: com a sessão aberta a aba troca este botão
/// pela onda do microfone, que é o comando de parar.
class RecordButton extends StatelessWidget {
  const RecordButton({
    super.key,
    required this.pointerVerb,
    required this.onPressed,
  });

  /// Verbo do gesto: `Clique` no desktop, `Toque` no celular.
  final String pointerVerb;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const color = CupertinoColors.activeBlue;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      pressedOpacity: 0.6,
      onPressed: onPressed,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.mic_fill, color: color, size: 22),
            const SizedBox(width: 8),
            // Rótulo elástico: a linha também carrega o ícone de ajustes, e em
            // tela estreita o texto precisa ceder em vez de estourar.
            Flexible(
              child: Text(
                '$pointerVerb para gravar',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
