import 'package:doudou/models/server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ServerType', () {
    test('has all expected values', () {
      expect(ServerType.values, contains(ServerType.youtubeMusic));
      expect(ServerType.values, contains(ServerType.subsonic));
      expect(ServerType.values, contains(ServerType.jellyfin));
      expect(ServerType.values, contains(ServerType.plex));
    });

    test('name property matches enum identifier', () {
      expect(ServerType.youtubeMusic.name, 'youtubeMusic');
      expect(ServerType.subsonic.name, 'subsonic');
      expect(ServerType.jellyfin.name, 'jellyfin');
      expect(ServerType.plex.name, 'plex');
    });
  });

  group('SettingsServer', () {
    test('defaultServerId is zero', () {
      expect(SettingsServer.defaultServerId, 0);
    });

    test('toMap serializes all fields', () {
      final server = SettingsServer(
        id: 3,
        name: 'My Server',
        type: ServerType.jellyfin,
        isDefault: true,
        serverUrl: 'https://demo.jellyfin.org',
        username: 'alice',
        password: 's3cret',
      );

      final map = server.toMap();

      expect(map['id'], 3);
      expect(map['name'], 'My Server');
      expect(map['type'], 'jellyfin');
      expect(map['isDefault'], true);
      expect(map['serverUrl'], 'https://demo.jellyfin.org');
      expect(map['username'], 'alice');
      expect(map['password'], 's3cret');
    });

    test('toMap serializes nullable fields as null', () {
      final server = SettingsServer(
        id: 1,
        name: 'Bare',
        type: ServerType.youtubeMusic,
      );

      final map = server.toMap();

      expect(map['serverUrl'], isNull);
      expect(map['username'], isNull);
      expect(map['password'], isNull);
      expect(map['isDefault'], false);
    });

    test('fromMap round-trips a full server', () {
      final original = SettingsServer(
        id: 7,
        name: 'Plex',
        type: ServerType.plex,
        isDefault: true,
        serverUrl: 'https://plex.example',
        username: 'bob',
        password: 'pw',
      );

      final restored = SettingsServer.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.type, original.type);
      expect(restored.isDefault, original.isDefault);
      expect(restored.serverUrl, original.serverUrl);
      expect(restored.username, original.username);
      expect(restored.password, original.password);
    });

    test('fromMap falls back to youtubeMusic for unknown type', () {
      final server = SettingsServer.fromMap(const {
        'id': 1,
        'name': 'Unknown',
        'type': 'totally-bogus',
      });

      expect(server.type, ServerType.youtubeMusic);
    });

    test('fromMap falls back to youtubeMusic when type missing', () {
      final server = SettingsServer.fromMap(const {
        'id': 1,
        'name': 'NoType',
      });

      expect(server.type, ServerType.youtubeMusic);
    });

    test('fromMap supplies defaults for missing optional fields', () {
      final server = SettingsServer.fromMap(const {});

      expect(server.name, 'Server');
      expect(server.type, ServerType.youtubeMusic);
      expect(server.isDefault, false);
      expect(server.serverUrl, isNull);
      expect(server.username, isNull);
      expect(server.password, isNull);
    });

    test('fromMap generates id from clock when id missing', () {
      final server = SettingsServer.fromMap(const {'name': 'AutoId'});

      expect(server.id, isPositive);
    });

    test('copyWith overrides only provided fields', () {
      final server = SettingsServer(
        id: 1,
        name: 'Original',
        type: ServerType.subsonic,
        serverUrl: 'https://old',
        username: 'u',
        password: 'p',
      );

      final updated = server.copyWith(name: 'Renamed', serverUrl: 'https://new');

      expect(updated.id, 1);
      expect(updated.name, 'Renamed');
      expect(updated.type, ServerType.subsonic);
      expect(updated.serverUrl, 'https://new');
      expect(updated.username, 'u');
      expect(updated.password, 'p');
    });

    test('copyWith with no args returns equal copy', () {
      final server = SettingsServer(
        id: 2,
        name: 'Keep',
        type: ServerType.jellyfin,
        isDefault: true,
        serverUrl: 'https://j',
        username: 'u',
        password: 'p',
      );

      final copy = server.copyWith();

      expect(copy.id, server.id);
      expect(copy.name, server.name);
      expect(copy.type, server.type);
      expect(copy.isDefault, server.isDefault);
      expect(copy.serverUrl, server.serverUrl);
      expect(copy.username, server.username);
      expect(copy.password, server.password);
    });
  });
}
