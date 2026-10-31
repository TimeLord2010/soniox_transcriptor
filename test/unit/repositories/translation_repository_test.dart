import 'package:flutter_test/flutter_test.dart';
import 'package:soniox_transcriptor/models/languages.dart';
import 'package:soniox_transcriptor/repositories/translation_repository.dart';

import '../../helpers/prefs.dart';

void main() {
  setUp(setUpPrefs);
  tearDown(tearDownGetIt);

  test('sem nada salvo, tradução vem desligada', () {
    expect(TranslationRepository('default').getTarget(), isNull);
  });

  test('salva e lê a língua alvo', () async {
    await TranslationRepository('default').setTarget(Language.en);

    expect(TranslationRepository('default').getTarget(), Language.en);
  });

  test('clear desliga a tradução', () async {
    final repo = TranslationRepository('default');
    await repo.setTarget(Language.en);

    await repo.clear();

    expect(repo.getTarget(), isNull);
  });

  test('valor desconhecido no storage conta como desligado', () async {
    await currentPrefs.setString(
      'profile.default.translation_target',
      'klingon',
    );

    expect(TranslationRepository('default').getTarget(), isNull);
  });

  test('isola o alvo por perfil', () async {
    await TranslationRepository('trabalho').setTarget(Language.en);

    expect(TranslationRepository('default').getTarget(), isNull);
    expect(TranslationRepository('trabalho').getTarget(), Language.en);
  });
}
