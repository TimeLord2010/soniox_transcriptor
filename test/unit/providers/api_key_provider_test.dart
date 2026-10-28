import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soniox_transcriptor/models/profile.dart';
import 'package:soniox_transcriptor/modules/local_storage_module.dart';
import 'package:soniox_transcriptor/providers/api_key_provider.dart';
import 'package:soniox_transcriptor/providers/profile_providers.dart';
import 'package:soniox_transcriptor/repositories/profile_repository.dart';

import '../../helpers/prefs.dart';

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

  test('sem chave salva o estado começa vazio', () {
    expect(container.read(apiKeyProvider), '');
  });

  test('estado inicial vem da chave salva do perfil ativo', () async {
    await LocalStorageModule.setApiKey(Profile.defaultId, 'chave-salva');

    expect(container.read(apiKeyProvider), 'chave-salva');
  });

  test('setApiKey atualiza o estado', () async {
    await container.read(apiKeyProvider.notifier).setApiKey('nova-chave');

    expect(container.read(apiKeyProvider), 'nova-chave');
  });

  test('setApiKey persiste no storage', () async {
    await container.read(apiKeyProvider.notifier).setApiKey('nova-chave');

    expect(LocalStorageModule.getApiKey(Profile.defaultId), 'nova-chave');
  });

  test('chave vazia limpa o que estava salvo', () async {
    await LocalStorageModule.setApiKey(Profile.defaultId, 'antiga');

    await container.read(apiKeyProvider.notifier).setApiKey('');

    expect(container.read(apiKeyProvider), '');
    expect(LocalStorageModule.getApiKey(Profile.defaultId), isNull);
  });

  test('trocar de perfil troca a chave em uso', () async {
    await ProfileRepository().saveProfiles([
      const Profile(id: Profile.defaultId, name: Profile.defaultName),
      const Profile(id: 'trabalho', name: 'Trabalho'),
    ]);
    await LocalStorageModule.setApiKey(Profile.defaultId, 'chave-padrao');
    await LocalStorageModule.setApiKey('trabalho', 'chave-trabalho');
    expect(container.read(apiKeyProvider), 'chave-padrao');

    await container.read(activeProfileIdProvider.notifier).select('trabalho');

    expect(container.read(apiKeyProvider), 'chave-trabalho');
  });

  test('perfil sem chave salva fica com estado vazio ao trocar', () async {
    await ProfileRepository().saveProfiles([
      const Profile(id: Profile.defaultId, name: Profile.defaultName),
      const Profile(id: 'trabalho', name: 'Trabalho'),
    ]);
    await LocalStorageModule.setApiKey(Profile.defaultId, 'chave-padrao');

    await container.read(activeProfileIdProvider.notifier).select('trabalho');

    expect(container.read(apiKeyProvider), '');
  });

  test('salvar chave num perfil não afeta o outro', () async {
    await ProfileRepository().saveProfiles([
      const Profile(id: Profile.defaultId, name: Profile.defaultName),
      const Profile(id: 'trabalho', name: 'Trabalho'),
    ]);
    await container.read(activeProfileIdProvider.notifier).select('trabalho');

    await container.read(apiKeyProvider.notifier).setApiKey('chave-trabalho');

    expect(LocalStorageModule.getApiKey(Profile.defaultId), isNull);
    expect(
      currentPrefs.getString(ProfileRepository.keyFor('trabalho', 'api_key')),
      'chave-trabalho',
    );
  });
}
