import 'dart:convert';

class Profile {
  /// Id of the built-in profile. It can be renamed but never deleted.
  static const defaultId = 'default';
  static const defaultName = 'Padrão';

  final String id;
  final String name;

  const Profile({required this.id, required this.name});

  bool get isDefault => id == defaultId;

  Profile copyWith({String? name}) => Profile(id: id, name: name ?? this.name);

  String toJson() => jsonEncode({'id': id, 'name': name});

  factory Profile.fromJson(String source) {
    final map = jsonDecode(source) as Map<String, dynamic>;
    return Profile(id: map['id'] as String, name: map['name'] as String);
  }
}
