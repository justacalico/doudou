class ServerState {
  ServerState({required this.setupRequired});

  factory ServerState.fromJson(Map<String, Object?> json) =>
      ServerState(setupRequired: json['setupRequired'] == true);

  final bool setupRequired;
}

/// One backend hosted on the server and shared with every client. Types
/// match the app's ServerType names.
class HostedBackend {
  HostedBackend({
    this.id,
    required this.name,
    required this.type,
    this.serverUrl,
    this.username,
    this.password,
  });

  factory HostedBackend.fromJson(Map<String, Object?> json) => HostedBackend(
        id: (json['id'] as num?)?.toInt(),
        name: json['name'] as String? ?? '',
        type: json['type'] as String? ?? '',
        serverUrl: json['serverUrl'] as String?,
        username: json['username'] as String?,
        password: json['password'] as String?,
      );

  final int? id;
  final String name;
  final String type;
  final String? serverUrl;
  final String? username;
  final String? password;

  static const types = ['youtubeMusic', 'subsonic', 'jellyfin', 'plex'];

  static String typeLabel(String type) => switch (type) {
        'youtubeMusic' => 'YouTube Music',
        'subsonic' => 'Subsonic / Navidrome',
        'jellyfin' => 'Jellyfin',
        'plex' => 'Plex',
        _ => type,
      };

  bool get needsUrl => type != 'youtubeMusic';

  Map<String, Object?> toJson() => {
        'name': name,
        'type': type,
        'serverUrl': serverUrl,
        'username': username,
        'password': password,
      };
}

class SyncBox {
  SyncBox({required this.name, required this.rev, required this.keys});

  factory SyncBox.fromJson(Map<String, Object?> json) => SyncBox(
        name: json['name'] as String? ?? '',
        rev: (json['rev'] as num?)?.toInt() ?? 0,
        keys: (json['keys'] as num?)?.toInt() ?? 0,
      );

  final String name;
  final int rev;
  final int keys;
}

class LogEntry {
  LogEntry(
      {required this.seq,
      required this.ts,
      required this.level,
      required this.message});

  factory LogEntry.fromJson(Map<String, Object?> json) => LogEntry(
        seq: (json['seq'] as num?)?.toInt() ?? 0,
        ts: (json['ts'] as num?)?.toInt() ?? 0,
        level: json['level'] as String? ?? 'info',
        message: json['msg'] as String? ?? '',
      );

  final int seq;
  final int ts;
  final String level;
  final String message;
}

class LogPage {
  LogPage({required this.entries, required this.latest});

  final List<LogEntry> entries;
  final int latest;
}

class ImportResult {
  ImportResult({required this.imported, required this.skipped});

  final List<String> imported;
  final List<String> skipped;
}
