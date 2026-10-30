import 'package:flutter/cupertino.dart';

/// Comando de gravação das plataformas sem atalho global (Android).
///
/// No macOS a sessão é disparada pela tecla global, com painel flutuante e
/// colagem no app em foco. Onde essas capacidades não existem, o usuário abre e
/// fecha a captura tocando aqui, e o texto aparece na sandbox.
class RecordButton extends StatelessWidget {
  const RecordButton({
    super.key,
    required this.isRecording,
    required this.onPressed,
  });

  final bool isRecording;
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
              isRecording ? 'Ouvindo… toque para parar' : 'Toque para gravar',
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
