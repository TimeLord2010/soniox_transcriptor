import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soniox_transcriptor/models/profile.dart';

class ProfileRepository {
  static const _profilesKey = 'profiles.list';
  static const _activeKey = 'profiles.active';
  static const _migratedKey = 'profiles.migrated';

  /// Settings that live inside a profile, with their pre-profiles key names.
  static const settingKeys = [
    'api_key',
    'selected_input_device_label',
    'context_text',
    'terms',
    'languages',
  ];

  SharedPreferences get _sp => GetIt.I.get<SharedPreferences>();

  /// Builds the preferences key for a setting of the given profile.
  static String keyFor(String profileId, String setting) {
    return 'profile.$profileId.$setting';
  }

  /// Moves the legacy, un-namespaced settings into the default profile.
  /// Safe to call on every launch: it only runs once.
  Future<void> migrateLegacySettings() async {
    if (_sp.getBool(_migratedKey) ?? false) return;

    for (final setting in settingKeys) {
      final value = _sp.get(setting);
      if (value == null) continue;
      final target = keyFor(Profile.defaultId, setting);
      // Never overwrite a value the default profile already has.
      if (!_sp.containsKey(target)) {
        // Lists come back from the platform as List<Object?>, never
        // List<String>, so read them through getStringList.
        if (value is String) {
          await _sp.setString(target, value);
        } else if (value is List) {
          await _sp.setStringList(target, _sp.getStringList(setting)!);
        } else {
          // Unknown type: keep the legacy key rather than lose the data.
          continue;
        }
      }
      await _sp.remove(setting);
    }
    await _sp.setBool(_migratedKey, true);
  }

  /// All profiles, with the default profile always present and first.
  List<Profile> getProfiles() {
    final stored = _sp.getStringList(_profilesKey) ?? [];
    final profiles = stored.map(Profile.fromJson).toList();
    if (!profiles.any((p) => p.isDefault)) {
      profiles.insert(
        0,
        const Profile(id: Profile.defaultId, name: Profile.defaultName),
      );
    }
    return profiles;
  }

  Future<void> saveProfiles(List<Profile> profiles) async {
    await _sp.setStringList(
      _profilesKey,
      profiles.map((p) => p.toJson()).toList(),
    );
  }

  /// Id of the active profile, falling back to the default one.
  String getActiveProfileId() {
    final id = _sp.getString(_activeKey);
    if (id != null && getProfiles().any((p) => p.id == id)) return id;
    return Profile.defaultId;
  }

  Future<void> setActiveProfileId(String id) async {
    await _sp.setString(_activeKey, id);
  }

  /// Removes every setting stored for the given profile.
  Future<void> deleteProfileSettings(String profileId) async {
    for (final setting in settingKeys) {
      await _sp.remove(keyFor(profileId, setting));
    }
  }
}
