import 'package:doudou/models/server.dart';
import 'package:doudou/services/backend/music_backend.dart';
import 'package:doudou/services/backend/plex_backend.dart';
import 'package:flutter_test/flutter_test.dart';

PlexBackend makeBackend({
  String? url,
  String? password,
}) {
  return PlexBackend(SettingsServer(
    id: 1,
    name: 'test',
    type: ServerType.plex,
    serverUrl: url,
    password: password,
  ));
}

void main() {
  group('PlexBackend.capabilities', () {
    test('returns plex capabilities', () {
      final backend = makeBackend(url: 'https://plex.example');

      expect(backend.capabilities.hasVideos, isFalse);
      expect(backend.capabilities.hasCharts, isFalse);
    });
  });

  group('PlexBackend.getStreamUrl', () {
    test('returns null for empty mediaItemId', () async {
      final backend = makeBackend(url: 'https://plex.example', password: 't');

      expect(await backend.getStreamUrl(''), isNull);
    });
  });

  group('PlexBackend.getPlaylistOrAlbumSongs', () {
    test('returns empty tracks when both ids are null', () async {
      final backend = makeBackend(url: 'https://plex.example');

      final result = await backend.getPlaylistOrAlbumSongs();

      expect(result['tracks'], isEmpty);
      expect(result['playlistId'], '');
    });

    test('returns empty tracks when both ids are empty', () async {
      final backend = makeBackend(url: 'https://plex.example');

      final result = await backend.getPlaylistOrAlbumSongs(
        playlistId: '',
        albumId: '',
      );

      expect(result['tracks'], isEmpty);
      expect(result['playlistId'], '');
    });
  });

  group('PlexBackend.getHome', () {
    test('returns empty list when service is unconfigured', () async {
      final backend = makeBackend();

      expect(await backend.getHome(), isEmpty);
    });
  });

  group('PlexBackend.getCharts', () {
    test('returns empty list', () async {
      final backend = makeBackend();

      expect(await backend.getCharts('songs'), isEmpty);
    });
  });

  group('PlexBackend.search', () {
    test('returns empty map when service is unconfigured', () async {
      final backend = makeBackend();

      expect(await backend.search('query'), isEmpty);
    });
  });

  group('PlexBackend.getContentRelatedToSong', () {
    test('returns empty list', () async {
      final backend = makeBackend();

      expect(await backend.getContentRelatedToSong('v', 'en'), isEmpty);
    });
  });

  group('PlexBackend.getSearchContinuation', () {
    test('returns empty map', () async {
      final backend = makeBackend();

      expect(await backend.getSearchContinuation({}), isEmpty);
    });
  });

  group('PlexBackend.setSongFavorite', () {
    test('completes without error', () async {
      final backend = makeBackend();

      await backend.setSongFavorite('id', true);
    });
  });

  group('PlexBackend.library getters', () {
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

  group('PlexBackend implements MusicBackend', () {
    test('is a MusicBackend', () {
      final backend = makeBackend();

      expect(backend, isA<MusicBackend>());
    });
  });
}
