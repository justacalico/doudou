import 'package:doudou/models/server.dart';
import 'package:doudou/server/hosted_backends.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('remoteServerId negates hosted ids so they never collide', () {
    expect(remoteServerId(1), -1);
    expect(remoteServerId(42), -42);
    // local ids are 0 (default) or positive epoch millis, so a negative
    // id can only come from a hosted backend
    expect(remoteServerId(1), isNot(SettingsServer.defaultServerId));
  });

  test('hostedBackendToSettingsServer maps a valid entry', () {
    final server = hostedBackendToSettingsServer({
      'id': 3,
      'name': 'Home Jellyfin',
      'type': 'jellyfin',
      'serverUrl': 'http://jf.local:8096',
      'username': 'cal',
      'password': 'pw',
    });
    expect(server, isNotNull);
    expect(server!.id, -3);
    expect(server.isRemote, isTrue);
    expect(server.isDefault, isFalse);
    expect(server.type, ServerType.jellyfin);
    expect(server.serverUrl, 'http://jf.local:8096');
    expect(server.username, 'cal');
    expect(server.password, 'pw');
  });

  test('hostedBackendToSettingsServer rejects bad entries', () {
    expect(hostedBackendToSettingsServer({'id': 1, 'name': 'x'}), isNull);
    expect(
        hostedBackendToSettingsServer(
            {'id': 1, 'name': 'x', 'type': 'napster'}),
        isNull);
    expect(
        hostedBackendToSettingsServer(
            {'id': 0, 'name': 'x', 'type': 'youtubeMusic'}),
        isNull);
    expect(
        hostedBackendToSettingsServer(
            {'id': -2, 'name': 'x', 'type': 'youtubeMusic'}),
        isNull);
  });

  test('validateHostedBackend checks name, type and url', () {
    expect(validateHostedBackend({'type': 'jellyfin'}), isNotNull);
    expect(validateHostedBackend({'name': '', 'type': 'jellyfin'}), isNotNull);
    expect(validateHostedBackend({'name': 'x', 'type': 'napster'}), isNotNull);
    expect(validateHostedBackend({'name': 'x', 'type': 'jellyfin'}), isNotNull);
    expect(
        validateHostedBackend({
          'name': 'x',
          'type': 'jellyfin',
          'serverUrl': 'http://jf.local',
        }),
        isNull);
    expect(
        validateHostedBackend({'name': 'x', 'type': 'youtubeMusic'}), isNull);
    expect(
        validateHostedBackend({
          'name': 'x',
          'type': 'youtubeMusic',
          'serverUrl': 42,
        }),
        isNotNull);
  });

  test('HostedBackend wire maps round trip', () {
    final backend = HostedBackend(
      id: 7,
      name: 'Navidrome',
      type: 'subsonic',
      serverUrl: 'http://n.local',
      username: 'u',
    );
    final restored = HostedBackend.fromMap(backend.toMap());
    expect(restored, isNotNull);
    expect(restored!.id, 7);
    expect(restored.name, 'Navidrome');
    expect(restored.type, 'subsonic');
    expect(restored.serverUrl, 'http://n.local');
    expect(restored.username, 'u');
    expect(restored.password, isNull);
  });
}
