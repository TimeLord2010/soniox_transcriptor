import 'package:flutter_test/flutter_test.dart';
import 'package:soniox_transcriptor/models/soniox_model.dart';

/// A lista do Soniox é a fonte da verdade do modelo: o app só precisa saber
/// separar tempo real de async e ordenar para o automático escolher o mais novo.
void main() {
  SonioxModel model(
    String id, {
    String mode = SonioxModel.realTimeMode,
    String? alias,
  }) {
    return SonioxModel.fromJson({
      'id': id,
      'name': 'Modelo $id',
      'transcription_mode': mode,
      'aliased_model_id': alias,
    });
  }

  test('descarta os modelos async', () {
    final realTime = SonioxModel.realTimeOnly([
      model('stt-rt-v6'),
      model('stt-async-v6', mode: 'async'),
    ]);

    expect(realTime.map((m) => m.id), ['stt-rt-v6']);
  });

  test('estáveis primeiro, mais novos antes dos apelidos', () {
    final realTime = SonioxModel.realTimeOnly([
      model('stt-rt-v3', alias: 'stt-rt-v5'),
      model('stt-rt-v5'),
      model('stt-rt-preview'),
      model('stt-rt-v6'),
    ]);

    expect(realTime.map((m) => m.id), [
      'stt-rt-v6',
      'stt-rt-v5',
      'stt-rt-v3',
      'stt-rt-preview',
    ]);
    // O automático é o primeiro da lista.
    expect(realTime.first.id, 'stt-rt-v6');
  });

  test('nome ausente cai no id', () {
    final parsed = SonioxModel.fromJson({
      'id': 'stt-rt-v6',
      'transcription_mode': SonioxModel.realTimeMode,
    });

    expect(parsed.name, 'stt-rt-v6');
    expect(parsed.isAlias, isFalse);
  });
}
