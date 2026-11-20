import 'dart:math' as math;
import 'dart:typed_data';

/// Nível de volume de um bloco de áudio PCM16 (mono, 16 kHz) em 0..1.
///
/// A onda da Sandbox precisa de um número por bloco, não de decibéis exatos: o
/// RMS vira 0..1 numa escala logarítmica (dBFS) com piso de ruído, e a resposta
/// é alisada — ataque rápido para a barra subir junto com a fala, soltura mais
/// lenta para ela não piscar a cada bloco.
class AudioLevelMeter {
  AudioLevelMeter({
    this.floorDb = -55,
    this.ceilingDb = -6,
    this.attack = 0.55,
    this.release = 0.18,
  });

  /// Abaixo disto é silêncio/ruído de fundo: nível zero.
  final double floorDb;

  /// Fala normal encosta aqui: nível 1.
  final double ceilingDb;

  /// Fração da distância percorrida por bloco quando o volume SOBE.
  final double attack;

  /// Idem quando o volume DESCE.
  final double release;

  double _level = 0;

  /// Último nível calculado, em 0..1.
  double get level => _level;

  void reset() => _level = 0;

  /// Consome um bloco PCM16 little-endian e devolve o nível alisado (0..1).
  ///
  /// Bloco com número ímpar de bytes perde o último byte (é meia amostra
  /// cortada na fronteira entre dois blocos do plugin).
  double consume(Uint8List pcm16le) {
    final samples = ByteData.sublistView(pcm16le);
    final count = samples.lengthInBytes ~/ 2;
    if (count == 0) return _level;

    var sum = 0.0;
    for (var i = 0; i < count; i++) {
      final sample = samples.getInt16(i * 2, Endian.little) / 32768.0;
      sum += sample * sample;
    }
    final target = _normalizeDb(math.sqrt(sum / count));
    _level += (target - _level) * (target > _level ? attack : release);
    return _level;
  }

  /// RMS (0..1) → nível 0..1 em escala de dB, com piso e teto.
  double _normalizeDb(double rms) {
    if (rms <= 0) return 0;
    final db = 20 * math.log(rms) / math.ln10;
    final normalized = (db - floorDb) / (ceilingDb - floorDb);
    return normalized.clamp(0.0, 1.0);
  }
}
