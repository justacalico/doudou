import 'package:doudou/models/server.dart';
import 'package:doudou/services/backend/subsonic_backend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SubsonicBackend makeBackend({
    String? url,
    String? username,
    String? password,
  }) {
    return SubsonicBackend(SettingsServer(
      id: 1,
      name: 'test',
      type: ServerType.subsonic,
      serverUrl: url,
      username: username,
      password: password,
    ));
  }

  group('SubsonicBackend.capabilities', () {
    test('returns subsonic capabilities (all false)', () {
      final backend = makeBackend(url: 'https://x', username: 'u');

      expect(backend.capabilities.hasVideos, isFalse);
      expect(backend.capabilities.hasCharts, isFalse);
    });
  });

  group('SubsonicBackend.getStreamUrl', () {
    test('returns null when mediaItemId is empty', () async {
      final backend = makeBackend(url: 'https://x', username: 'u');

      expect(await backend.getStreamUrl(''), isNull);
    });

    test('returns null when baseUrl is empty', () async {
      final backend = makeBackend(url: '', username: 'u');

      expect(await backend.getStreamUrl('song1'), isNull);
    });

    test('returns null when username is null', () async {
      final backend = makeBackend(url: 'https://x', username: null);

      expect(await backend.getStreamUrl('song1'), isNull);
    });

    test('builds stream URL with credentials', () async {
      final backend = makeBackend(
        url: 'https://sub.example',
        username: 'alice',
        password: 'pw',
      );

      final url = await backend.getStreamUrl('song1');

      expect(url, isNotNull);
      expect(url, contains('https://sub.example/rest/stream.view'));
      expect(url, contains('u=alice'));
      expect(url, contains('p=pw'));
      expect(url, contains('id=song1'));
      expect(url, contains('v=1.16.0'));
      expect(url, contains('c=Doudou'));
    });

    test('strips trailing slash from base url', () async {
      final backend = makeBackend(
        url: 'https://sub.example/',
        username: 'alice',
      );

      final url = await backend.getStreamUrl('song1');

      expect(url, isNotNull);
      expect(url, startsWith('https://sub.example/rest/stream.view'));
      expect(url, isNot(contains('//rest')));
    });
  });

  group('SubsonicBackend.getPlaylistOrAlbumSongs', () {
    test('returns empty tracks when id is null', () async {
      final backend = makeBackend(url: 'https://x', username: 'u');

      final result = await backend.getPlaylistOrAlbumSongs();

      expect(result['tracks'], isEmpty);
      expect(result['playlistId'], '');
    });

    test('returns empty tracks when id is empty', () async {
      final backend = makeBackend(url: 'https://x', username: 'u');

      final result = await backend.getPlaylistOrAlbumSongs(playlistId: '');

      expect(result['tracks'], isEmpty);
      expect(result['playlistId'], '');
    });
  });

  group('SubsonicBackend.addToPlaylist', () {
    test('returns false when playlistId is empty', () async {
      final backend = makeBackend(url: 'https://x', username: 'u');

      expect(await backend.addToPlaylist('', ['s1']), isFalse);
    });

    test('returns false when songIds is empty', () async {
      final backend = makeBackend(url: 'https://x', username: 'u');

      expect(await backend.addToPlaylist('pl1', []), isFalse);
    });
  });

  group('SubsonicBackend.setSongFavorite', () {
    test('completes without error for empty songId', () async {
      final backend = makeBackend(url: 'https://x', username: 'u');

      await backend.setSongFavorite('', true);
    });
  });

  group('SubsonicBackend.getHome', () {
    test('returns empty list', () async {
      final backend = makeBackend(url: 'https://x', username: 'u');

      expect(await backend.getHome(), isEmpty);
    });
  });

  group('SubsonicBackend.getCharts', () {
    test('returns empty list', () async {
      final backend = makeBackend(url: 'https://x', username: 'u');

      expect(await backend.getCharts('songs'), isEmpty);
    });
  });

  group('SubsonicBackend.getContentRelatedToSong', () {
    test('returns empty list', () async {
      final backend = makeBackend(url: 'https://x', username: 'u');

      expect(await backend.getContentRelatedToSong('v', 'en'), isEmpty);
    });
  });

  group('SubsonicBackend.getSearchContinuation', () {
    test('returns empty map', () async {
      final backend = makeBackend(url: 'https://x', username: 'u');

      expect(await backend.getSearchContinuation({}), isEmpty);
    });
  });
}
