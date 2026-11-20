import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Largura da barra, espaço entre barras e altura mínima (a linha reta de
/// quando não há captura).
const double _barWidth = 3.0;
const double _gap = 3.0;
const double _minimumBar = 2.0;

/// Onda do volume capturado, mostrada na aba Sandbox.
///
/// Cada barra é uma amostra do volume do microfone: entra pela direita, anda
/// para a esquerda e cai sozinha quando a pessoa cala. Parada (fora da captura)
/// a onda fica reta, então o layout não muda ao começar/terminar de gravar.
///
/// Repinta por ticker, sem `setState`: o nível chega várias vezes por segundo e
/// reconstruir a aba a cada bloco de áudio custaria o campo de texto inteiro.
class AudioWaveform extends StatefulWidget {
  const AudioWaveform({
    super.key,
    required this.level,
    required this.active,
    this.height = 26,
  });

  /// Volume atual em 0..1, publicado pela sessão de captura.
  final ValueListenable<double> level;

  /// Captura em andamento: a onda se move. Parada, ela fica reta.
  final bool active;

  final double height;

  @override
  State<AudioWaveform> createState() => _AudioWaveformState();
}

class _AudioWaveformState extends State<AudioWaveform>
    with SingleTickerProviderStateMixin {
  /// Uma barra nova a cada 70 ms (≈14 por segundo): passo legível de onda de
  /// voz numa faixa de 300 px, sem virar borrão.
  static const sampleInterval = Duration(milliseconds: 70);

  /// Queda da barra por segundo — metade em ~230 ms, o ritmo da fala.
  static const _decayPerSecond = 0.05;

  late final Ticker _ticker = createTicker(_onTick);
  final _repaint = ValueNotifier<int>(0);

  /// Altura desenhada de cada barra (0..1), da mais antiga para a mais nova.
  final List<double> _heights = [];

  /// Alvo de cada barra: a amostra de volume, decaindo até zero.
  final List<double> _targets = [];

  Duration _lastTick = Duration.zero;
  Duration _sinceSample = Duration.zero;
  int _capacity = 0;

  @override
  void initState() {
    super.initState();
    if (widget.active) _startTicker();
  }

  @override
  void didUpdateWidget(AudioWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      // Ao parar, o ticker continua até a onda cair sozinha (o `_onTick`
      // desliga quando ela chega ao zero).
      _sinceSample = Duration.zero;
      _startTicker();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  void _startTicker() {
    if (_ticker.isActive) return;
    _lastTick = Duration.zero;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final dt = _lastTick == Duration.zero
        ? 0.0
        : (elapsed - _lastTick).inMicroseconds / 1000000;
    _lastTick = elapsed;
    final count = _heights.length;
    if (count == 0) return;

    if (widget.active) {
      _sinceSample += Duration(microseconds: (dt * 1000000).round());
      if (_sinceSample >= sampleInterval) {
        _sinceSample = Duration.zero;
        _pushSample(widget.level.value);
      }
    }

    final decay = math.pow(_decayPerSecond, dt).toDouble();
    final ease = math.min(1.0, dt * 18);
    var peak = 0.0;
    for (var i = 0; i < count; i++) {
      _targets[i] *= decay;
      _heights[i] += (_targets[i] - _heights[i]) * ease;
      if (_heights[i] > peak) peak = _heights[i];
    }
    _repaint.value++;

    // Captura encerrada e onda já caiu: para o ticker em vez de animar zero.
    if (!widget.active && peak < 0.01) {
      _heights.fillRange(0, count, 0);
      _targets.fillRange(0, count, 0);
      _repaint.value++;
      _ticker.stop();
    }
  }

  void _pushSample(double level) {
    if (_heights.isEmpty) return;
    _targets
      ..removeAt(0)
      ..add(level.clamp(0.0, 1.0));
    // A barra nova nasce do zero e sobe na suavização: evita degrau na borda.
    _heights
      ..removeAt(0)
      ..add(0);
  }

  /// Quantas barras cabem na largura atual; mudança de largura reinicia a onda.
  void _syncCapacity(double width) {
    final capacity = ((width + _gap) / (_barWidth + _gap)).floor().clamp(0, 512);
    if (capacity == _capacity) return;
    _capacity = capacity;
    _heights
      ..clear()
      ..addAll(List<double>.filled(capacity, 0));
    _targets
      ..clear()
      ..addAll(List<double>.filled(capacity, 0));
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.active
        ? CupertinoColors.systemRed.resolveFrom(context)
        : CupertinoColors.tertiaryLabel.resolveFrom(context);
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _syncCapacity(constraints.maxWidth);
          return CustomPaint(
            key: const ValueKey('sandbox-waveform'),
            painter: _WaveformPainter(
              heights: _heights,
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

  /// Lida ao vivo: o estado muda a lista no lugar e pede repaint pelo ticker.
  final List<double> heights;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final count = heights.length;
    if (count == 0) return;

    final total = count * _barWidth +
        (count - 1) * _gap;
    final centerY = size.height / 2;
    final paint = Paint()..style = PaintingStyle.fill;

    var x = (size.width - total) / 2;
    for (var i = 0; i < count; i++) {
      final level = heights[i].clamp(0.0, 1.0);
      final barHeight = _minimumBar +
          (size.height - _minimumBar) * level;
      paint.color = color.withValues(alpha: 0.3 + 0.7 * level);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x,
            centerY - barHeight / 2,
            _barWidth,
            barHeight,
          ),
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