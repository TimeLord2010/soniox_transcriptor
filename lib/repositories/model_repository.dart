import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soniox_transcriptor/repositories/profile_repository.dart';

/// Modelo de transcrição escolhido no perfil.
///
/// `null` = nenhum escolhido: o app usa o modelo de tempo real mais novo que o
/// Soniox publicar. Escolher um modelo explicitamente é o que o fixa — assim o
/// app não fica preso a uma versão antiga por causa de um padrão no código.
class ModelRepository {
  ModelRepository(this.profileId);

  final String profileId;

  static const _key = 'model';

  SharedPreferences get _sp => GetIt.I.get<SharedPreferences>();

  String get _storageKey => ProfileRepository.keyFor(profileId, _key);

  String? getModel() {
    final id = _sp.getString(_storageKey);
    if (id == null || id.trim().isEmpty) return null;
    return id;
  }

  Future<void> setModel(String? id) async {
    if (id == null || id.trim().isEmpty) {
      await _sp.remove(_storageKey);
      return;
    }
    await _sp.setString(_storageKey, id.trim());
  }
}
