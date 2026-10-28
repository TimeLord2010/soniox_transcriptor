import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soniox_transcriptor/models/profile.dart';
import 'package:soniox_transcriptor/providers/profile_providers.dart';
import 'package:soniox_transcriptor/repositories/profile_repository.dart';

import '../../helpers/prefs.dart';

void main() {
  late ProviderContainer container;
  late ProfileRepository repo;

  setUp(() async {
    await setUpPrefs();
    repo = ProfileRepository();
    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    await tearDownGetIt();
  });

  group('estado inicial', () {
    test('perfil ativo é o padrão', () {
      expect(container.read(activeProfileIdProvider), Profile.defaultId);
    });

    test('lista de perfis tem só o padrão', () {
      final profiles = container.read(profilesProvider);

      expect(profiles, hasLength(1));
      expect(profiles.single.id, Profile.defaultId);
    });

    test('activeProfileProvider devolve o perfil do id ativo', () {
      expect(
        container.read(activeProfileProvider).id,
        container.read(activeProfileIdProvider),
      );
    });
  });

  group('ProfilesNotifier.create', () {
    test('adiciona o perfil no fim da lista', () async {
      final created = await container
          .read(profilesProvider.notifier)
          .create('Trabalho');

      final profiles = container.read(profilesProvider);
      expect(profiles.map((p) => p.name), [Profile.defaultName, 'Trabalho']);
      expect(profiles.last.id, created.id);
    });

    test('persiste o perfil no storage', () async {
      final created = await container
          .read(profilesProvider.notifier)
          .create('Trabalho');

      expect(repo.getProfiles().map((p) => p.id), contains(created.id));
    });

    test('não troca o perfil ativo', () async {
      await container.read(profilesProvider.notifier).create('Trabalho');

      expect(container.read(activeProfileIdProvider), Profile.defaultId);
    });
  });

  group('ProfilesNotifier.rename', () {
    test('troca o nome e persiste', () async {
      final created = await container
          .read(profilesProvider.notifier)
          .create('Antigo');

      await container
          .read(profilesProvider.notifier)
          .rename(created.id, 'Novo');

      final renamed = container
          .read(profilesProvider)
          .firstWhere((p) => p.id == created.id);
      expect(renamed.name, 'Novo');
      expect(
        repo.getProfiles().firstWhere((p) => p.id == created.id).name,
        'Novo',
      );
    });

    test('renomeia o perfil padrão sem trocar o id', () async {
      await container
          .read(profilesProvider.notifier)
          .rename(Profile.defaultId, 'Pessoal');

      final profiles = container.read(profilesProvider);
      expect(profiles.single.id, Profile.defaultId);
      expect(profiles.single.name, 'Pessoal');
    });
  });

  group('ProfilesNotifier.delete', () {
    test('o perfil padrão não pode ser apagado', () async {
      await container.read(profilesProvider.notifier).delete(Profile.defaultId);

      expect(container.read(profilesProvider), hasLength(1));
      expect(container.read(activeProfileIdProvider), Profile.defaultId);
    });

    test('apaga um perfil que não está ativo', () async {
      final created = await container
          .read(profilesProvider.notifier)
          .create('Trabalho');

      await container.read(profilesProvider.notifier).delete(created.id);

      expect(container.read(profilesProvider), hasLength(1));
      expect(repo.getProfiles(), hasLength(1));
      expect(container.read(activeProfileIdProvider), Profile.defaultId);
    });

    test('apagar o perfil ativo volta para o padrão', () async {
      final created = await container
          .read(profilesProvider.notifier)
          .create('Trabalho');
      await container.read(activeProfileIdProvider.notifier).select(created.id);

      await container.read(profilesProvider.notifier).delete(created.id);

      expect(container.read(activeProfileIdProvider), Profile.defaultId);
      expect(repo.getActiveProfileId(), Profile.defaultId);
    });

    test('apaga também os settings do perfil', () async {
      final created = await container
          .read(profilesProvider.notifier)
          .create('Trabalho');
      await currentPrefs.setString(
        ProfileRepository.keyFor(created.id, 'api_key'),
        'chave',
      );

      await container.read(profilesProvider.notifier).delete(created.id);

      expect(
        currentPrefs.getString(ProfileRepository.keyFor(created.id, 'api_key')),
        isNull,
      );
    });
  });

  group('ActiveProfileNotifier.select', () {
    test('troca o perfil ativo e persiste', () async {
      final created = await container
          .read(profilesProvider.notifier)
          .create('Trabalho');

      await container.read(activeProfileIdProvider.notifier).select(created.id);

      expect(container.read(activeProfileIdProvider), created.id);
      expect(repo.getActiveProfileId(), created.id);
    });

    test('activeProfileProvider acompanha a troca', () async {
      final created = await container
          .read(profilesProvider.notifier)
          .create('Trabalho');

      await container.read(activeProfileIdProvider.notifier).select(created.id);

      expect(container.read(activeProfileProvider).name, 'Trabalho');
    });

    test('escolher o mesmo perfil mantém o estado', () async {
      await container
          .read(activeProfileIdProvider.notifier)
          .select(Profile.defaultId);

      expect(container.read(activeProfileIdProvider), Profile.defaultId);
    });
  });
}
