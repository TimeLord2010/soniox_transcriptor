import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soniox_transcriptor/models/languages.dart';
import 'package:soniox_transcriptor/models/profile.dart';
import 'package:soniox_transcriptor/providers/context_providers.dart';
import 'package:soniox_transcriptor/providers/profile_providers.dart';
import 'package:soniox_transcriptor/repositories/context_repository.dart';
import 'package:soniox_transcriptor/repositories/languages_repository.dart';
import 'package:soniox_transcriptor/repositories/profile_repository.dart';
import 'package:soniox_transcriptor/repositories/terms_repository.dart';

import '../../helpers/prefs.dart';

/// Cria o perfil no storage para que ele exista ao ser ativado.
Future<void> saveProfile(String id) {
  return ProfileRepository().saveProfiles([
    const Profile(id: Profile.defaultId, name: Profile.defaultName),
    Profile(id: id, name: id),
  ]);
}

void main() {
  late ProviderContainer container;

  setUp(() async {
    await setUpPrefs();
    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    await tearDownGetIt();
  });

  Future<void> selectProfile(String id) async {
    await saveProfile(id);
    await container.read(activeProfileIdProvider.notifier).select(id);
  }

  group('contextProvider', () {
    test('sem contexto salvo começa vazio', () {
      expect(container.read(contextProvider), '');
    });

    test('estado inicial vem do contexto salvo', () async {
      await ContextRepository(Profile.defaultId).setContext('contexto salvo');

      expect(container.read(contextProvider), 'contexto salvo');
    });

    test('setContext atualiza o estado e persiste', () async {
      await container.read(contextProvider.notifier).setContext('novo texto');

      expect(container.read(contextProvider), 'novo texto');
      expect(ContextRepository(Profile.defaultId).getContext(), 'novo texto');
    });

    test('o contexto acompanha a troca de perfil', () async {
      await ContextRepository(Profile.defaultId).setContext('do padrão');
      await ContextRepository('trabalho').setContext('do trabalho');

      await selectProfile('trabalho');

      expect(container.read(contextProvider), 'do trabalho');
    });
  });

  group('languagesProvider', () {
    test('sem escolha começa com português', () {
      expect(container.read(languagesProvider), {Language.pt});
    });

    test('toggleLanguage adiciona idioma ausente', () async {
      await container
          .read(languagesProvider.notifier)
          .toggleLanguage(Language.en);

      expect(container.read(languagesProvider), {Language.pt, Language.en});
      expect(LanguagesRepository(Profile.defaultId).getLanguages(), {
        Language.pt,
        Language.en,
      });
    });

    test('toggleLanguage remove idioma presente', () async {
      await LanguagesRepository(
        Profile.defaultId,
      ).setLanguages({Language.pt, Language.en});
      expect(container.read(languagesProvider), {Language.pt, Language.en});

      await container
          .read(languagesProvider.notifier)
          .toggleLanguage(Language.en);

      expect(container.read(languagesProvider), {Language.pt});
    });

    test('desmarcar o último idioma deixa o conjunto vazio', () async {
      await container
          .read(languagesProvider.notifier)
          .toggleLanguage(Language.pt);

      expect(container.read(languagesProvider), isEmpty);
      expect(LanguagesRepository(Profile.defaultId).getLanguages(), isEmpty);
    });

    test('os idiomas acompanham a troca de perfil', () async {
      await LanguagesRepository('trabalho').setLanguages({Language.en});

      await selectProfile('trabalho');

      expect(container.read(languagesProvider), {Language.en});
    });
  });

  group('termsProvider', () {
    test('sem termos começa vazio', () {
      expect(container.read(termsProvider), isEmpty);
    });

    test('addTerm atualiza o estado com o termo novo na frente', () async {
      await container.read(termsProvider.notifier).addTerm('soniox');

      expect(container.read(termsProvider), ['soniox']);
      expect(TermsRepository(Profile.defaultId).getAllTerms(), ['soniox']);
    });

    test('deleteTerm remove do estado e do storage', () async {
      await container.read(termsProvider.notifier).addTerm('a');
      await container.read(termsProvider.notifier).addTerm('b');

      await container.read(termsProvider.notifier).deleteTerm('a');

      expect(container.read(termsProvider), ['b']);
      expect(TermsRepository(Profile.defaultId).getAllTerms(), ['b']);
    });

    test('os termos acompanham a troca de perfil', () async {
      await TermsRepository(Profile.defaultId).addTerm('padrao');
      await TermsRepository('trabalho').addTerm('trabalho');

      await selectProfile('trabalho');

      expect(container.read(termsProvider), ['trabalho']);
    });
  });
}

/// Atalho para criar um perfil persistido antes de trocar o perfil ativo.
class ProfileRepositoryHelper {
  static Future<void> save(String id) async {
    final profiles = [
      const Profile(id: Profile.defaultId, name: Profile.defaultName),
      Profile(id: id, name: id),
    ];
    await ProfileRepository().saveProfiles(profiles);
  }
}
