import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soniox_transcriptor/models/profile.dart';
import 'package:soniox_transcriptor/repositories/profile_repository.dart';

import '../../helpers/prefs.dart';

void main() {
  late ProfileRepository repo;
  late SharedPreferences prefs;

  setUp(() async {
    prefs = await setUpPrefs();
    repo = ProfileRepository();
  });

  tearDown(tearDownGetIt);

  group('getProfiles', () {
    test('sem nada salvo, devolve só o perfil padrão', () {
      final profiles = repo.getProfiles();

      expect(profiles, hasLength(1));
      expect(profiles.first.id, Profile.defaultId);
      expect(profiles.first.name, Profile.defaultName);
    });

    test('injecta o padrão na frente quando ele não foi salvo', () async {
      await repo.saveProfiles([
        const Profile(id: 'trabalho', name: 'Trabalho'),
      ]);

      final profiles = repo.getProfiles();

      expect(profiles.map((p) => p.id), [Profile.defaultId, 'trabalho']);
    });

    test('não duplica o padrão quando ele já está salvo', () async {
      await repo.saveProfiles([
        const Profile(id: Profile.defaultId, name: Profile.defaultName),
        const Profile(id: 'trabalho', name: 'Trabalho'),
      ]);

      expect(repo.getProfiles(), hasLength(2));
    });

    test('mantém o padrão renomeado', () async {
      await repo.saveProfiles([
        const Profile(id: Profile.defaultId, name: 'Pessoal'),
      ]);

      final profiles = repo.getProfiles();

      expect(profiles, hasLength(1));
      expect(profiles.first.name, 'Pessoal');
    });
  });

  test('saveProfiles preserva a ordem gravada', () async {
    await repo.saveProfiles([
      const Profile(id: Profile.defaultId, name: Profile.defaultName),
      const Profile(id: 'a', name: 'A'),
      const Profile(id: 'b', name: 'B'),
    ]);

    expect(repo.getProfiles().map((p) => p.name), ['Padrão', 'A', 'B']);
  });

  group('perfil ativo', () {
    test('cai no padrão quando nunca foi escolhido', () {
      expect(repo.getActiveProfileId(), Profile.defaultId);
    });

    test('devolve o id salvo quando o perfil existe', () async {
      await repo.saveProfiles([
        const Profile(id: Profile.defaultId, name: Profile.defaultName),
        const Profile(id: 'trabalho', name: 'Trabalho'),
      ]);
      await repo.setActiveProfileId('trabalho');

      expect(repo.getActiveProfileId(), 'trabalho');
    });

    test('cai no padrão quando o id salvo não existe mais', () async {
      await repo.setActiveProfileId('sumiu');

      expect(repo.getActiveProfileId(), Profile.defaultId);
    });

    test('o id escolhido sobrevive numa instância nova', () async {
      await repo.saveProfiles([
        const Profile(id: 'trabalho', name: 'Trabalho'),
      ]);
      await repo.setActiveProfileId('trabalho');

      expect(ProfileRepository().getActiveProfileId(), 'trabalho');
    });
  });

  group('keyFor', () {
    test('monta profile.<id>.<setting>', () {
      expect(
        ProfileRepository.keyFor('trabalho', 'api_key'),
        'profile.trabalho.api_key',
      );
    });

    test('cobre as chaves de settings declaradas', () {
      expect(
        ProfileRepository.settingKeys,
        containsAll(['api_key', 'context_text', 'terms', 'languages']),
      );
    });
  });

  group('deleteProfileSettings', () {
    test('apaga os settings do perfil e mantém os dos outros', () async {
      await prefs.setString(
        ProfileRepository.keyFor('a', 'api_key'),
        'chave-a',
      );
      await prefs.setStringList(ProfileRepository.keyFor('a', 'terms'), ['um']);
      await prefs.setString(
        ProfileRepository.keyFor('b', 'api_key'),
        'chave-b',
      );

      await repo.deleteProfileSettings('a');

      expect(prefs.getString(ProfileRepository.keyFor('a', 'api_key')), isNull);
      expect(
        prefs.getStringList(ProfileRepository.keyFor('a', 'terms')),
        isNull,
      );
      expect(
        prefs.getString(ProfileRepository.keyFor('b', 'api_key')),
        'chave-b',
      );
    });

    test('não apaga a lista de perfis nem o perfil ativo', () async {
      await repo.saveProfiles([const Profile(id: 'a', name: 'A')]);
      await repo.setActiveProfileId('a');

      await repo.deleteProfileSettings('a');

      expect(prefs.getStringList('profiles.list'), isNotNull);
      expect(prefs.getString('profiles.active'), 'a');
    });

    test('limpa todos os settings declarados do perfil', () async {
      for (final setting in ProfileRepository.settingKeys) {
        await prefs.setString(ProfileRepository.keyFor('a', setting), 'x');
      }

      await repo.deleteProfileSettings('a');

      for (final setting in ProfileRepository.settingKeys) {
        expect(
          prefs.getString(ProfileRepository.keyFor('a', setting)),
          isNull,
          reason: 'setting $setting deveria ter sido removido',
        );
      }
    });
  });
}
