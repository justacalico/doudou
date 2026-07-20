import 'dart:convert';

/// One entry in the music server list mirrored between doudou and doudou-server.
/// Only url + display metadata. No credentials ever travel through this.
class MusicServerDto {
  MusicServerDto({
    required this.id,
    required this.name,
    required this.type,
    required this.url,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final String type;
  final String url;
  final bool isDefault;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'url': url,
        'isDefault': isDefault,
      };

  factory MusicServerDto.fromJson(Map<String, dynamic> json) => MusicServerDto(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
        url: json['url'] as String,
        isDefault: json['isDefault'] as bool? ?? false,
      );
}

/// Kinds of libraries we sync. Mirrors doudou's LibraryKind enum so the
/// client can map back and forth without extra translation.
const libraryKinds = ['songs', 'playlists', 'albums', 'artists'];

class SnapshotDto {
  SnapshotDto({
    required this.musicServerId,
    required this.kind,
    required this.version,
    required this.updatedAtMs,
    required this.payload,
  });

  final String musicServerId;
  final String kind;
  final int version;
  final int updatedAtMs;
  final String payload;

  Map<String, dynamic> toJson() => {
        'musicServerId': musicServerId,
        'kind': kind,
        'version': version,
        'updatedAtMs': updatedAtMs,
        'payload': payload,
      };

  factory SnapshotDto.fromJson(Map<String, dynamic> json) => SnapshotDto(
        musicServerId: json['musicServerId'] as String,
        kind: json['kind'] as String,
        version: json['version'] as int? ?? 0,
        updatedAtMs: json['updatedAtMs'] as int? ?? 0,
        payload: json['payload'] as String? ?? '[]',
      );
}

class ClientDto {
  ClientDto({
    required this.id,
    required this.name,
    required this.firstSeenMs,
    required this.lastSeenMs,
  });

  final String id;
  final String name;
  final int firstSeenMs;
  final int lastSeenMs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'firstSeenMs': firstSeenMs,
        'lastSeenMs': lastSeenMs,
      };
}

String encodeJson(Object? value) => jsonEncode(value);

Map<String, dynamic> decodeJson(String body) =>
    jsonDecode(body) as Map<String, dynamic>;
