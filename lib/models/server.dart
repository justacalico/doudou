enum ServerType { youtubeMusic, subsonic, jellyfin, plex }

class SettingsServer {
  SettingsServer({
    required this.id,
    required this.name,
    required this.type,
    this.isDefault = false,
    this.isRemote = false,
    this.serverUrl,
    this.username,
    this.password,
  });

  static const int defaultServerId = 0;

  final int id;
  final String name;
  final ServerType type;
  final bool isDefault;

  /// True when this entry comes from the connected sync server instead of
  /// the local server list. Remote entries are read only on the device and
  /// disappear when device sync is turned off.
  final bool isRemote;
  final String? serverUrl;
  final String? username;
  final String? password;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'isDefault': isDefault,
      'isRemote': isRemote,
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
      isRemote: map['isRemote'] as bool? ?? false,
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
    bool? isRemote,
    String? serverUrl,
    String? username,
    String? password,
  }) {
    return SettingsServer(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      isDefault: isDefault ?? this.isDefault,
      isRemote: isRemote ?? this.isRemote,
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }
}
