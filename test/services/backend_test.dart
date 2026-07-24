import 'package:doudou/models/server.dart';
import 'package:doudou/services/backend/backend_capabilities.dart';
import 'package:doudou/services/backend/backend_factory.dart';
import 'package:doudou/services/backend/jellyfin_backend.dart';
import 'package:doudou/services/backend/music_backend.dart';
import 'package:doudou/services/backend/noop_backend.dart';
import 'package:doudou/services/backend/plex_backend.dart';
import 'package:doudou/services/backend/subsonic_backend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BackendCapabilities', () {
    test('default constructor sets all flags to false', () {
      const caps = BackendCapabilities();

      expect(caps.hasVideos, isFalse);
      expect(caps.hasCommunityPlaylists, isFalse);
      expect(caps.hasFeaturedPlaylists, isFalse);
      expect(caps.hasTrending, isFalse);
      expect(caps.hasDiscoverContent, isFalse);
      expect(caps.hasCharts, isFalse);
    });

    test('youtubeMusic enables all features', () {
      const caps = BackendCapabilities.youtubeMusic;

      expect(caps.hasVideos, isTrue);
      expect(caps.hasCommunityPlaylists, isTrue);
      expect(caps.hasFeaturedPlaylists, isTrue);
      expect(caps.hasTrending, isTrue);
      expect(caps.hasDiscoverContent, isTrue);
      expect(caps.hasCharts, isTrue);
    });

    test('jellyfin disables all optional features', () {
      const caps = BackendCapabilities.jellyfin;

      expect(caps.hasVideos, isFalse);
      expect(caps.hasCharts, isFalse);
    });

    test('subsonic disables all optional features', () {
      const caps = BackendCapabilities.subsonic;

      expect(caps.hasVideos, isFalse);
      expect(caps.hasCharts, isFalse);
    });

    test('plex disables all optional features', () {
      const caps = BackendCapabilities.plex;

      expect(caps.hasVideos, isFalse);
      expect(caps.hasCharts, isFalse);
    });
  });

  group('createBackend', () {
    test('returns JellyfinBackend for jellyfin type', () {
      final server = SettingsServer(
        id: 1,
        name: 'JF',
        type: ServerType.jellyfin,
        serverUrl: 'https://jellyfin.example',
      );

      final backend = createBackend(server);

      expect(backend, isA<JellyfinBackend>());
    });

    test('returns SubsonicBackend for subsonic type', () {
      final server = SettingsServer(
        id: 2,
        name: 'SS',
        type: ServerType.subsonic,
        serverUrl: 'https://subsonic.example',
        username: 'u',
      );

      final backend = createBackend(server);

      expect(backend, isA<SubsonicBackend>());
    });

    test('returns PlexBackend for plex type', () {
      final server = SettingsServer(
        id: 3,
        name: 'Plex',
        type: ServerType.plex,
        serverUrl: 'https://plex.example',
      );

      final backend = createBackend(server);

      expect(backend, isA<PlexBackend>());
    });

    // YouTubeMusicBackend is not tested here because its constructor
    // calls Get.find<MusicServices>(), which requires GetX DI setup.
  });

  group('NoOpBackend', () {
    test('capabilities returns all-false', () {
      final backend = NoOpBackend();

      expect(backend.capabilities.hasVideos, isFalse);
      expect(backend.capabilities.hasCharts, isFalse);
    });

    test('getLibraryArtists returns empty list', () async {
      final backend = NoOpBackend();

      expect(await backend.getLibraryArtists(), isEmpty);
    });

    test('getLibraryAlbums returns empty list', () async {
      final backend = NoOpBackend();

      expect(await backend.getLibraryAlbums(), isEmpty);
    });

    test('getLibrarySongs returns empty list', () async {
      final backend = NoOpBackend();

      expect(await backend.getLibrarySongs(), isEmpty);
    });

    test('getFavoriteSongs returns empty list', () async {
      final backend = NoOpBackend();

      expect(await backend.getFavoriteSongs(), isEmpty);
    });

    test('setSongFavorite completes without error', () async {
      final backend = NoOpBackend();

      await backend.setSongFavorite('id', true);
    });

    test('getHome returns empty list', () async {
      final backend = NoOpBackend();

      expect(await backend.getHome(), isEmpty);
    });

    test('getCharts returns empty list', () async {
      final backend = NoOpBackend();

      expect(await backend.getCharts('songs'), isEmpty);
    });

    test('search returns empty map', () async {
      final backend = NoOpBackend();

      expect(await backend.search('query'), isEmpty);
    });

    test('getPlaylistOrAlbumSongs returns empty map', () async {
      final backend = NoOpBackend();

      expect(await backend.getPlaylistOrAlbumSongs(playlistId: 'p'), isEmpty);
    });

    test('getContentRelatedToSong returns empty list', () async {
      final backend = NoOpBackend();

      expect(await backend.getContentRelatedToSong('vid', 'en'), isEmpty);
    });

    test('getStreamUrl returns null', () async {
      final backend = NoOpBackend();

      expect(await backend.getStreamUrl('id'), isNull);
    });

    test('getLibraryPlaylists returns empty list', () async {
      final backend = NoOpBackend();

      expect(await backend.getLibraryPlaylists(), isEmpty);
    });

    test('getSearchContinuation returns empty map', () async {
      final backend = NoOpBackend();

      expect(await backend.getSearchContinuation({}), isEmpty);
    });

    test('implements MusicBackend', () {
      final backend = NoOpBackend();

      expect(backend, isA<MusicBackend>());
    });
  });
}
