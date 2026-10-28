import 'package:flutter_test/flutter_test.dart';
import 'package:soniox_transcriptor/modules/local_storage_module.dart';
import 'package:soniox_transcriptor/repositories/profile_repository.dart';

import '../../helpers/prefs.dart';

void main() {
  setUp(setUpPrefs);
  tearDown(tearDownGetIt);

  group('API key', () {
    test('sem nada salvo, devolve null', () {
      expect(LocalStorageModule.getApiKey('default'), isNull);
    });

    test('salva e lê a chave', () async {
      await LocalStorageModule.setApiKey('default', 'chave-123');

      expect(LocalStorageModule.getApiKey('default'), 'chave-123');
    });

    test('passar null remove a chave', () async {
      await LocalStorageModule.setApiKey('default', 'chave-123');

      await LocalStorageModule.setApiKey('default', null);

      expect(LocalStorageModule.getApiKey('default'), isNull);
    });

    test('sobrescreve a chave anterior', () async {
      await LocalStorageModule.setApiKey('default', 'antiga');
      await LocalStorageModule.setApiKey('default', 'nova');

      expect(LocalStorageModule.getApiKey('default'), 'nova');
    });

    test('cada perfil tem a sua chave', () async {
      await LocalStorageModule.setApiKey('default', 'chave-padrao');
      await LocalStorageModule.setApiKey('trabalho', 'chave-trabalho');

      expect(LocalStorageModule.getApiKey('default'), 'chave-padrao');
      expect(LocalStorageModule.getApiKey('trabalho'), 'chave-trabalho');
    });

    test('remove só a chave do perfil pedido', () async {
      await LocalStorageModule.setApiKey('default', 'chave-padrao');
      await LocalStorageModule.setApiKey('trabalho', 'chave-trabalho');

      await LocalStorageModule.setApiKey('trabalho', null);

      expect(LocalStorageModule.getApiKey('default'), 'chave-padrao');
      expect(LocalStorageModule.getApiKey('trabalho'), isNull);
    });

    test('usa a chave por perfil do ProfileRepository', () async {
      await LocalStorageModule.setApiKey('trabalho', 'chave-trabalho');

      final prefs = currentPrefs;

      expect(
        prefs.getString(ProfileRepository.keyFor('trabalho', 'api_key')),
        'chave-trabalho',
      );
    });
  });

  group('dispositivo de entrada', () {
    test('sem nada salvo, devolve null', () {
      expect(LocalStorageModule.getSelectedDeviceLabel('default'), isNull);
    });

    test('salva e lê o label', () async {
      await LocalStorageModule.setSelectedDeviceLabel('default', 'MacBook Mic');

      expect(
        LocalStorageModule.getSelectedDeviceLabel('default'),
        'MacBook Mic',
      );
    });

    test('cada perfil guarda o seu dispositivo', () async {
      await LocalStorageModule.setSelectedDeviceLabel('default', 'Interno');
      await LocalStorageModule.setSelectedDeviceLabel('trabalho', 'Headset');

      expect(LocalStorageModule.getSelectedDeviceLabel('default'), 'Interno');
      expect(LocalStorageModule.getSelectedDeviceLabel('trabalho'), 'Headset');
    });

    test('não mexe na API key ao salvar o dispositivo', () async {
      await LocalStorageModule.setApiKey('default', 'chave');

      await LocalStorageModule.setSelectedDeviceLabel('default', 'Headset');

      expect(LocalStorageModule.getApiKey('default'), 'chave');
    });
  });
}
