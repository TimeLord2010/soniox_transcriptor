import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:soniox_transcriptor/modules/waveform_history.dart';

/// Largura da barra, espaço entre barras e altura mínima de uma barra (o piso
/// em silêncio: a onda nunca vira um vazio).
const double _barWidth = 3.0;
const double _gap = 3.0;
const double _minimumBar = 2.0;

/// Onda do volume capturado: cada barra é uma amostra do nível do microfone.
///
/// Só existe enquanto a captura está aberta — a aba troca o botão de gravar por
/// ela —, então o ticker roda apenas com a onda na tela. Repinta sem
/// `setState`: o nível chega várias vezes por segundo e reconstruir a aba a
/// cada bloco custaria o campo de texto inteiro.
class AudioWaveform extends StatefulWidget {
  const AudioWaveform({super.key, required this.level, this.height = 36});

  /// Volume atual em 0..1, publicado pela sessão de captura.
  final ValueListenable<double> level;

  final double height;

  @override
  State<AudioWaveform> createState() => _AudioWaveformState();
}

class _AudioWaveformState extends State<AudioWaveform>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final _repaint = ValueNotifier<int>(0);

  /// Alturas das barras. O modelo mora em [WaveformHistory] (sem Flutter) e
  /// este estado só o alimenta a cada quadro.
  final _history = WaveformHistory();

  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = _lastTick == Duration.zero
        ? 0.0
        : (elapsed - _lastTick).inMicroseconds / 1000000;
    _lastTick = elapsed;
    if (dt <= 0) return;
    _history.advance(dt, widget.level.value);
    _repaint.value++;
  }

  @override
  Widget build(BuildContext context) {
    final color = CupertinoColors.systemRed.resolveFrom(context);
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Quantas barras cabem na largura atual.
          _history.resize(
            ((constraints.maxWidth + _gap) / (_barWidth + _gap))
                .floor()
                .clamp(0, 512),
          );
          return CustomPaint(
            key: const ValueKey('sandbox-waveform'),
            painter: _WaveformPainter(
              heights: _history.heights,
              color: color,
              repaint: _repaint,
            ),
          );
        },
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.heights,
    required this.color,
    required Listenable repaint,
  }) : super(repaint: repaint);

  /// Lida ao vivo: o modelo muda a lista no lugar e pede repaint pelo ticker.
  final List<double> heights;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final count = heights.length;
    if (count == 0) return;

    final total = count * _barWidth + (count - 1) * _gap;
    final centerY = size.height / 2;
    final paint = Paint()..style = PaintingStyle.fill;

    var x = (size.width - total) / 2;
    for (var i = 0; i < count; i++) {
      final level = heights[i].clamp(0.0, 1.0);
      final barHeight = _minimumBar + (size.height - _minimumBar) * level;
      paint.color = color.withValues(alpha: 0.3 + 0.7 * level);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, centerY - barHeight / 2, _barWidth, barHeight),
          const Radius.circular(_barWidth / 2),
        ),
        paint,
      );
      x += _barWidth + _gap;
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.heights.length != heights.length;
}
