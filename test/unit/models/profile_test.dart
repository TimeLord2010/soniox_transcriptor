import 'package:flutter_test/flutter_test.dart';
import 'package:soniox_transcriptor/models/profile.dart';

void main() {
  group('Profile', () {
    test('toJson/fromJson fazem round-trip', () {
      const profile = Profile(id: 'trabalho', name: 'Trabalho');
      final json = profile.toJson();

      final restored = Profile.fromJson(json);

      expect(restored.id, 'trabalho');
      expect(restored.name, 'Trabalho');
    });

    test('fromJson aceita nome com acento e aspas', () {
      const profile = Profile(id: 'p', name: 'Reunião "semanal"');

      expect(Profile.fromJson(profile.toJson()).name, 'Reunião "semanal"');
    });

    test('isDefault só vale para o id padrão', () {
      expect(const Profile(id: Profile.defaultId, name: 'x').isDefault, isTrue);
      expect(const Profile(id: 'outro', name: 'x').isDefault, isFalse);
    });

    test('copyWith troca só o nome', () {
      const profile = Profile(id: 'a', name: 'Antigo');

      final renamed = profile.copyWith(name: 'Novo');

      expect(renamed.id, 'a');
      expect(renamed.name, 'Novo');
      expect(profile.name, 'Antigo');
    });

    test('copyWith sem nome mantém o nome atual', () {
      const profile = Profile(id: 'a', name: 'Igual');

      expect(profile.copyWith().name, 'Igual');
    });
  });
}
