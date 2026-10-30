import 'package:flutter_test/flutter_test.dart';
import 'package:soniox_transcriptor/repositories/diarization_repository.dart';

import '../../helpers/prefs.dart';

void main() {
  setUp(setUpPrefs);
  tearDown(tearDownGetIt);

  test('sem nada salvo, diarização vem desligada', () {
    expect(DiarizationRepository('default').getSpeakerDiarization(), isFalse);
  });

  test('salva e lê a diarização ligada', () async {
    await DiarizationRepository('default').setSpeakerDiarization(true);

    expect(DiarizationRepository('default').getSpeakerDiarization(), isTrue);
  });

  test('volta a desligar quando o usuário desmarca', () async {
    final repo = DiarizationRepository('default');
    await repo.setSpeakerDiarization(true);

    await repo.setSpeakerDiarization(false);

    expect(repo.getSpeakerDiarization(), isFalse);
  });

  test('isola a diarização por perfil', () async {
    await DiarizationRepository('trabalho').setSpeakerDiarization(true);

    expect(DiarizationRepository('default').getSpeakerDiarization(), isFalse);
    expect(DiarizationRepository('trabalho').getSpeakerDiarization(), isTrue);
  });
}
