import 'package:doudou/models/server.dart';
import 'package:doudou/services/backend/jellyfin_backend.dart';
import 'package:doudou/services/backend/plex_backend.dart';
import 'package:doudou/services/players/plex_service.dart';
import 'package:doudou/ui/screens/Settings/settings_screen_controller.dart';
import 'package:doudou/utils/url_sanitizer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'dart:io';

import '../../fakes.dart';

void main() {
  group('scrubUrlAuthParams', () {
    test('strips the Jellyfin api_key param', () {
      expect(
        scrubUrlAuthParams(
            'https://jf.example/Items/1/Images/Primary?api_key=tok&w=100'),
        'https://jf.example/Items/1/Images/Primary?w=100',
      );
    });

    test('strips api_key when it is the only param', () {
      expect(
        scrubUrlAuthParams('https://jf.example/Audio/1/stream?api_key=tok'),
        'https://jf.example/Audio/1/stream',
      );
    });

    test('strips the Plex token param', () {
      expect(
        scrubUrlAuthParams(
            'https://plex.example/library/parts/9/file.mp3?X-Plex-Token=abc'),
        'https://plex.example/library/parts/9/file.mp3',
      );
    });

    test('leaves urls without credentials untouched', () {
      const url = 'https://rr.googlevideo.com/videoplayback?expire=1&id=2';
      expect(scrubUrlAuthParams(url), url);
    });

    test('handles malformed input without throwing', () {
      expect(scrubUrlAuthParams('api_key='), isA<String>());
      expect(scrubUrlAuthParams(''), '');
    });
  });

  group('PlexService media auth', () {
    test('stream urls carry no token but headers do', () {
      final service = PlexService()
        ..configure(serverUrl: 'https://plex.example', token: 'tok123');

      expect(service.getDownloadUrl('t1'),
          'https://plex.example/library/metadata/t1/download');
      expect(service.getDirectPartUrl('p1'),
          'https://plex.example/library/parts/p1/file.mp3');
      expect(service.getDirectStreamWithPartKey('/k/1'),
          'https://plex.example/k/1');
      expect(service.getUniversalStreamUrl('t1'),
          isNot(contains('X-Plex-Token')));

      expect(service.mediaRequestHeaders('https://plex.example/x'),
          {'X-Plex-Token': 'tok123'});
    });

    test('returns no headers for foreign urls or when unconfigured', () {
      final service = PlexService()
        ..configure(serverUrl: 'https://plex.example', token: 'tok123');
      expect(service.mediaRequestHeaders('https://other.example/x'), isEmpty);

      final bare = PlexService();
      expect(bare.mediaRequestHeaders('https://plex.example/x'), isEmpty);
    });
  });

  group('PlexBackend.mediaRequestHeaders', () {
    test('delegates to the service', () {
      final backend = PlexBackend(SettingsServer(
        id: 2,
        name: 'plex',
        type: ServerType.plex,
        serverUrl: 'https://plex.example',
        password: 'tok123',
      ));

      expect(backend.mediaRequestHeaders('https://plex.example/a'),
          {'X-Plex-Token': 'tok123'});
      expect(backend.mediaRequestHeaders('https://other.example/a'), isEmpty);
    });
  });

  group('JellyfinBackend media auth', () {
    test('returns no headers before authentication', () {
      final backend = JellyfinBackend(SettingsServer(
        id: 3,
        name: 'jf',
        type: ServerType.jellyfin,
        serverUrl: 'https://jf.example',
        username: 'u',
        password: 'p',
      ));

      expect(backend.mediaRequestHeaders('https://jf.example/Items/1'),
          isEmpty);
      expect(backend.mediaRequestHeaders('https://other.example/Items/1'),
          isEmpty);
    });

    test('mediaRequestHeadersFor ignores foreign urls without authing', () async {
      final backend = JellyfinBackend(SettingsServer(
        id: 3,
        name: 'jf',
        type: ServerType.jellyfin,
        serverUrl: 'https://jf.example',
      ));

      expect(await backend.mediaRequestHeadersFor('https://other.example/a'),
          isEmpty);
    });
  });

  group('SettingsScreenController backend lookup', () {
    late Directory dir;

    setUpAll(() async {
      dir = await Directory.systemTemp.createTemp('doudou_headers_test_');
      Hive.init(dir.path);
      await Hive.openBox('AppPrefs');
      Get.testMode = true;
    });

    tearDownAll(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    tearDown(() => Get.delete<SettingsScreenController>(force: true));

    test('resolves headers from the server owning the url', () {
      final settings = FakeSettingsScreenController();
      settings.servers.value = [
        SettingsServer(
          id: 5,
          name: 'plex',
          type: ServerType.plex,
          serverUrl: 'https://plex.example',
          password: 'tok123',
        ),
        SettingsServer(
          id: 6,
          name: 'jf',
          type: ServerType.jellyfin,
          serverUrl: 'https://jf.example',
          username: 'u',
        ),
      ];
      Get.put<SettingsScreenController>(settings);

      expect(settings.mediaRequestHeaders('https://plex.example/media/a'),
          {'X-Plex-Token': 'tok123'});
      // A different server's url does not get the Plex token.
      expect(settings.mediaRequestHeaders('https://jf.example/Items/1'),
          isEmpty);
      expect(settings.mediaRequestHeaders('https://unknown.example/x'),
          isEmpty);
    });

    test('backendForUrl reuses one instance per server', () {
      final settings = FakeSettingsScreenController();
      final server = SettingsServer(
        id: 7,
        name: 'jf',
        type: ServerType.jellyfin,
        serverUrl: 'https://jf.example',
        username: 'u',
      );
      settings.servers.value = [server];
      Get.put<SettingsScreenController>(settings);

      expect(settings.backendForServer(server),
          same(settings.backendForServer(server)));
      expect(settings.backendForUrl('https://jf.example/Items/1'),
          isA<JellyfinBackend>());
    });
  });
}
