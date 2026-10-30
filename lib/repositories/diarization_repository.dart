import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soniox_transcriptor/repositories/profile_repository.dart';

/// Preferência de sessão: quando ligada, o Soniox identifica quem falou e o
/// texto recebe o rótulo do falante.
class DiarizationRepository {
  DiarizationRepository(this.profileId);

  final String profileId;

  static const _key = 'speaker_diarization';

  SharedPreferences get _sp => GetIt.I.get<SharedPreferences>();

  String get _storageKey => ProfileRepository.keyFor(profileId, _key);

  bool getSpeakerDiarization() {
    return _sp.getBool(_storageKey) ?? false;
  }

  Future<void> setSpeakerDiarization(bool enabled) async {
    await _sp.setBool(_storageKey, enabled);
  }
}
