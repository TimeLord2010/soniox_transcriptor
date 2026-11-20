import 'dart:math' as math;

/// Histórico de barras da onda: o modelo que a tela desenha, sem Flutter.
///
/// A barra mais nova é a amostra atual do volume e cada barra entra pela
/// direita empurrando as antigas. Fica fora do widget para poder ser exercitado
/// com números — o desenho em si é a única parte que precisa de tela.
class WaveformHistory {
  WaveformHistory({
    this.sampleInterval = const Duration(milliseconds: 70),
    this.halfLifeSeconds = 4.0,
  });

  /// Uma barra nova a cada [sampleInterval] (≈14 por segundo): passo legível de
  /// onda de voz numa faixa de 300 px, sem virar borrão.
  final Duration sampleInterval;

  /// Queda de cada barra: meia-vida de 4 s, mais longa que a faixa inteira
  /// (~3,5 s), para a história toda continuar reagindo ao volume.
  ///
  /// Tem que ser LENTA. Com queda curta (a primeira versão usava 230 ms) cada
  /// barra morria antes de ser desenhada e só as últimas reagiam à voz, com o
  /// resto da faixa parecendo morto — foi o defeito relatado pelo dono.
  final double halfLifeSeconds;

  /// Altura desenhada de cada barra (0..1), da mais antiga para a mais nova.
  final List<double> heights = [];

  /// Nível amostrado de cada barra, decaindo devagar até zero.
  final List<double> _targets = [];

  double _secondsSinceSample = 0;

  int get length => heights.length;

  /// Ajusta o número de barras à largura disponível (mudança reinicia a onda).
  void resize(int capacity) {
    if (capacity == heights.length) return;
    heights
      ..clear()
      ..addAll(List<double>.filled(capacity, 0));
    _targets
      ..clear()
      ..addAll(List<double>.filled(capacity, 0));
    _secondsSinceSample = 0;
  }

  /// Avança [dt] segundos com [level] (0..1) sendo o volume atual.
  void advance(double dt, double level) {
    if (dt <= 0 || heights.isEmpty) return;

    _secondsSinceSample += dt;
    if (_secondsSinceSample * 1000 >= sampleInterval.inMilliseconds) {
      _secondsSinceSample = 0;
      _push(level);
    }

    final decay = math.pow(0.5, dt / halfLifeSeconds).toDouble();
    final ease = math.min(1.0, dt * 20);
    for (var i = 0; i < heights.length; i++) {
      _targets[i] *= decay;
      heights[i] += (_targets[i] - heights[i]) * ease;
    }
  }

  void _push(double level) {
    _targets
      ..removeAt(0)
      ..add(level.clamp(0.0, 1.0));
    // A barra nova nasce do zero e sobe na suavização: evita degrau na borda.
    heights
      ..removeAt(0)
      ..add(0);
  }
}
