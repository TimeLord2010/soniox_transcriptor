import 'package:flutter/cupertino.dart';

/// Comando de gravação por toque/clique, disponível nas duas plataformas.
///
/// No Android é o único jeito de abrir a captura. No macOS convive com a tecla
/// global: a tecla cola o resultado no app em foco, enquanto a sessão aberta
/// aqui entrega o texto na sandbox.
class RecordButton extends StatelessWidget {
  const RecordButton({
    super.key,
    required this.isRecording,
    required this.pointerVerb,
    required this.onPressed,
  });

  final bool isRecording;

  /// Verbo do gesto: `Clique` no desktop, `Toque` no celular.
  final String pointerVerb;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = isRecording
        ? CupertinoColors.systemRed
        : CupertinoColors.activeBlue;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      pressedOpacity: 0.6,
      onPressed: onPressed,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: isRecording ? 0.16 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isRecording
                  ? CupertinoIcons.stop_circle_fill
                  : CupertinoIcons.mic_fill,
              color: color,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              isRecording
                  ? 'Ouvindo… ${pointerVerb.toLowerCase()} para parar'
                  : '$pointerVerb para gravar',
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
