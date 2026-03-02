enum ServerType { youtubeMusic, subsonic, jellyfin, plex }

class SettingsServer {
  SettingsServer({
    required this.id,
    required this.name,
    required this.type,
    this.isDefault = false,
    this.serverUrl,
    this.username,
    this.password,
  });

  static const int defaultServerId = 0;

  final int id;
  final String name;
  final ServerType type;
  final bool isDefault;
  final String? serverUrl;
  final String? username;
  final String? password;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'isDefault': isDefault,
      'serverUrl': serverUrl,
      'username': username,
      'password': password,
    };
  }

  factory SettingsServer.fromMap(Map<String, dynamic> map) {
    final typeName = map['type'] as String? ?? ServerType.youtubeMusic.name;
    final type = ServerType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => ServerType.youtubeMusic,
    );
    return SettingsServer(
      id: map['id'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      name: map['name'] as String? ?? 'Server',
      type: type,
      isDefault: map['isDefault'] as bool? ?? false,
      serverUrl: map['serverUrl'] as String?,
      username: map['username'] as String?,
      password: map['password'] as String?,
    );
  }

  SettingsServer copyWith({
    int? id,
    String? name,
    ServerType? type,
    bool? isDefault,
    String? serverUrl,
    String? username,
    String? password,
  }) {
    return SettingsServer(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      isDefault: isDefault ?? this.isDefault,
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }
}
