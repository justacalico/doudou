import '../models/server.dart';

/// A backend hosted on the sync server and handed out to every connected
/// client. The wire map mirrors [SettingsServer.toMap] so entries move
/// between the server database, `/api/backends` and client storage without
/// reformatting.
class HostedBackend {
  HostedBackend({
    required this.id,
    required this.name,
    required this.type,
    this.serverUrl,
    this.username,
    this.password,
  });

  final int id;
  final String name;
  final String type;
  final String? serverUrl;
  final String? username;
  final String? password;

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        if (serverUrl != null) 'serverUrl': serverUrl,
        if (username != null) 'username': username,
        if (password != null) 'password': password,
      };

  static HostedBackend? fromMap(Map<dynamic, dynamic> map) {
    final id = map['id'];
    final name = map['name'];
    final type = map['type'];
    if (id is! num || name is! String || type is! String) return null;
    return HostedBackend(
      id: id.toInt(),
      name: name,
      type: type,
      serverUrl: map['serverUrl'] as String?,
      username: map['username'] as String?,
      password: map['password'] as String?,
    );
  }
}

/// The id a client uses for a hosted backend. Local server ids are always
/// zero or positive (the default server is 0, added servers are epoch
/// milliseconds), so negating the hosted id can never collide while staying
/// identical on every client, which keeps the synced library box names
/// (`LIBFAV_s_-3` and friends) shared between devices.
int remoteServerId(int hostedId) => -hostedId;

/// Converts a hosted backend wire map into the [SettingsServer] a client
/// shows. Returns null when the entry does not validate.
SettingsServer? hostedBackendToSettingsServer(Map<dynamic, dynamic> map) {
  final hosted = HostedBackend.fromMap(map);
  if (hosted == null || hosted.id <= 0) return null;
  ServerType? type;
  for (final t in ServerType.values) {
    if (t.name == hosted.type) type = t;
  }
  if (type == null) return null;
  return SettingsServer(
    id: remoteServerId(hosted.id),
    name: hosted.name,
    type: type,
    serverUrl: hosted.serverUrl,
    username: hosted.username,
    password: hosted.password,
    isRemote: true,
  );
}

/// Validates a backend create/update payload from the web UI or a client.
/// Returns an error message, or null when the entry is usable.
String? validateHostedBackend(Map<dynamic, dynamic> map) {
  final name = map['name'];
  if (name is! String || name.trim().isEmpty) return 'name is required';
  final type = map['type'];
  if (type is! String ||
      !ServerType.values.any((t) => t.name == type)) {
    return 'unknown server type';
  }
  if (type != ServerType.youtubeMusic.name) {
    final url = map['serverUrl'];
    if (url is! String || url.trim().isEmpty) {
      return 'serverUrl is required for $type';
    }
  }
  for (final key in ['serverUrl', 'username', 'password']) {
    final value = map[key];
    if (value != null && value is! String) return '$key must be a string';
  }
  return null;
}
