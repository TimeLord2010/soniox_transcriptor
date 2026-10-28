import 'package:flutter_test/flutter_test.dart';
import 'package:soniox_transcriptor/models/languages.dart';
import 'package:soniox_transcriptor/repositories/context_repository.dart';
import 'package:soniox_transcriptor/repositories/languages_repository.dart';
import 'package:soniox_transcriptor/repositories/terms_repository.dart';

import '../../helpers/prefs.dart';

void main() {
  setUp(setUpPrefs);
  tearDown(tearDownGetIt);

  group('ContextRepository', () {
    test('sem nada salvo devolve string vazia', () {
      expect(ContextRepository('default').getContext(), '');
    });

    test('salva e lê o contexto', () async {
      final repo = ContextRepository('default');

      await repo.setContext('reunião sobre contratos');

      expect(
        ContextRepository('default').getContext(),
        'reunião sobre contratos',
      );
    });

    test('sobrescreve o contexto anterior', () async {
      final repo = ContextRepository('default');
      await repo.setContext('antigo');

      await repo.setContext('novo');

      expect(repo.getContext(), 'novo');
    });

    test('isola o contexto por perfil', () async {
      await ContextRepository('default').setContext('do padrão');

      expect(ContextRepository('trabalho').getContext(), '');
      expect(ContextRepository('default').getContext(), 'do padrão');
    });
  });

  group('LanguagesRepository', () {
    test('sem nada salvo devolve só português', () {
      expect(LanguagesRepository('default').getLanguages(), {Language.pt});
    });

    test('salva e lê o conjunto escolhido', () async {
      final repo = LanguagesRepository('default');

      await repo.setLanguages({Language.pt, Language.en});

      expect(repo.getLanguages(), {Language.pt, Language.en});
    });

    test('conjunto vazio é preservado como vazio', () async {
      final repo = LanguagesRepository('default');

      await repo.setLanguages({});

      expect(repo.getLanguages(), isEmpty);
    });

    test('isola os idiomas por perfil', () async {
      await LanguagesRepository('trabalho').setLanguages({Language.en});

      expect(LanguagesRepository('default').getLanguages(), {Language.pt});
      expect(LanguagesRepository('trabalho').getLanguages(), {Language.en});
    });
  });

  group('TermsRepository', () {
    test('sem nada salvo devolve lista vazia', () {
      expect(TermsRepository('default').getAllTerms(), isEmpty);
    });

    test('addTerm coloca o termo novo na frente', () async {
      final repo = TermsRepository('default');

      await repo.addTerm('primeiro');
      await repo.addTerm('segundo');

      expect(repo.getAllTerms(), ['segundo', 'primeiro']);
    });

    test('addTerm ignora termo repetido', () async {
      final repo = TermsRepository('default');
      await repo.addTerm('soniox');

      await repo.addTerm('soniox');

      expect(repo.getAllTerms(), ['soniox']);
    });

    test('deleteTerm remove só o termo pedido', () async {
      final repo = TermsRepository('default');
      await repo.addTerm('a');
      await repo.addTerm('b');

      await repo.deleteTerm('a');

      expect(repo.getAllTerms(), ['b']);
    });

    test('deleteTerm de termo inexistente mantém a lista', () async {
      final repo = TermsRepository('default');
      await repo.addTerm('a');

      await repo.deleteTerm('nao-existe');

      expect(repo.getAllTerms(), ['a']);
    });

    test('isola os termos por perfil', () async {
      await TermsRepository('trabalho').addTerm('contrato');

      expect(TermsRepository('default').getAllTerms(), isEmpty);
      expect(TermsRepository('trabalho').getAllTerms(), ['contrato']);
    });
  });
}
