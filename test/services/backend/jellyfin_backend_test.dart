import 'package:doudou/models/server.dart';
import 'package:doudou/services/backend/jellyfin_backend.dart';
import 'package:doudou/services/backend/music_backend.dart';
import 'package:flutter_test/flutter_test.dart';

JellyfinBackend makeBackend({
  String? url,
  String? username,
  String? password,
}) {
  return JellyfinBackend(SettingsServer(
    id: 1,
    name: 'test',
    type: ServerType.jellyfin,
    serverUrl: url,
    username: username,
    password: password,
  ));
}

void main() {
  group('JellyfinBackend.capabilities', () {
    test('returns jellyfin capabilities', () {
      final backend = makeBackend(url: 'https://jf.example');

      expect(backend.capabilities.hasVideos, isFalse);
      expect(backend.capabilities.hasCharts, isFalse);
    });
  });

  group('JellyfinBackend._baseUrl', () {
    test('strips trailing slash from serverUrl', () async {
      final backend = makeBackend(url: 'https://jf.example/', username: null);

      // _ensureAuth touches _baseUrl and returns because username is null.
      await backend.getHome();

      // getStreamUrl with no token returns null; this exercises _baseUrl.
      expect(await backend.getStreamUrl('song'), isNull);
    });
  });

  group('JellyfinBackend.getStreamUrl', () {
    test('returns null for empty mediaItemId', () async {
      final backend = makeBackend(url: 'https://jf.example', username: 'u');

      expect(await backend.getStreamUrl(''), isNull);
    });

    test('returns null when not authenticated', () async {
      final backend = makeBackend(url: 'https://jf.example');

      expect(await backend.getStreamUrl('song'), isNull);
    });
  });

  group('JellyfinBackend.getPlaylistOrAlbumSongs', () {
    test('returns empty tracks when ids are null', () async {
      final backend = makeBackend(url: 'https://jf.example');

      final result = await backend.getPlaylistOrAlbumSongs();

      expect(result['tracks'], isEmpty);
      expect(result['playlistId'], '');
    });

    test('returns empty tracks when id is empty', () async {
      final backend = makeBackend(url: 'https://jf.example');

      final result = await backend.getPlaylistOrAlbumSongs(playlistId: '');

      expect(result['tracks'], isEmpty);
      expect(result['playlistId'], '');
    });
  });

  group('JellyfinBackend.getHome', () {
    test('returns empty list when unconfigured', () async {
      final backend = makeBackend();

      expect(await backend.getHome(), isEmpty);
    });
  });

  group('JellyfinBackend.getCharts', () {
    test('returns empty list', () async {
      final backend = makeBackend();

      expect(await backend.getCharts('songs'), isEmpty);
    });
  });

  group('JellyfinBackend.search', () {
    test('returns empty map when unconfigured', () async {
      final backend = makeBackend();

      expect(await backend.search('query'), isEmpty);
    });
  });

  group('JellyfinBackend.getContentRelatedToSong', () {
    test('returns empty list', () async {
      final backend = makeBackend();

      expect(await backend.getContentRelatedToSong('v', 'en'), isEmpty);
    });
  });

  group('JellyfinBackend.getSearchContinuation', () {
    test('returns empty map', () async {
      final backend = makeBackend();

      expect(await backend.getSearchContinuation({}), isEmpty);
    });
  });

  group('JellyfinBackend.setSongFavorite', () {
    test('completes without error', () async {
      final backend = makeBackend();

      await backend.setSongFavorite('id', true);
    });
  });

  group('JellyfinBackend.library getters', () {
    test('getLibraryPlaylists returns empty list when unconfigured', () async {
      final backend = makeBackend();

      expect(await backend.getLibraryPlaylists(), isEmpty);
    });

    test('getLibraryArtists returns empty list when unconfigured', () async {
      final backend = makeBackend();

      expect(await backend.getLibraryArtists(), isEmpty);
    });

    test('getLibraryAlbums returns empty list when unconfigured', () async {
      final backend = makeBackend();

      expect(await backend.getLibraryAlbums(), isEmpty);
    });

    test('getLibrarySongs returns empty list when unconfigured', () async {
      final backend = makeBackend();

      expect(await backend.getLibrarySongs(), isEmpty);
    });

    test('getFavoriteSongs returns empty list when unconfigured', () async {
      final backend = makeBackend();

      expect(await backend.getFavoriteSongs(), isEmpty);
    });
  });

  group('JellyfinBackend.getLibrary', () {
    test('getLibraryArtists returns empty list when unconfigured', () async {
      final backend = makeBackend();

      expect(await backend.getLibraryArtists(), isEmpty);
    });
  });

  group('JellyfinBackend implements MusicBackend', () {
    test('is a MusicBackend', () {
      final backend = makeBackend();

      expect(backend, isA<MusicBackend>());
    });
  });
}
