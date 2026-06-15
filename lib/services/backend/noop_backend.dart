import '../../models/album.dart';
import '../../models/artist.dart';
import '../../models/playlist.dart';
import 'backend_capabilities.dart';
import 'music_backend.dart';

class NoOpBackend extends MusicBackend {
  @override
  BackendCapabilities get capabilities => const BackendCapabilities();

  @override
  Future<List<Artist>> getLibraryArtists() async => [];

  @override
  Future<List<Album>> getLibraryAlbums() async => [];

  @override
  Future<List<Map<String, dynamic>>> getLibrarySongs() async => [];

  @override
  Future<List<Map<String, dynamic>>> getFavoriteSongs() async => [];

  @override
  Future<void> setSongFavorite(String songId, bool favorite) async {}

  @override
  Future<dynamic> getHome({int limit = 4}) async => [];

  @override
  Future<List<Map<String, dynamic>>> getCharts(String category,
          {String? countryCode}) async =>
      [];

  @override
  Future<Map<String, dynamic>> search(String query,
          {String? filter,
          String? scope,
          int limit = 30,
          bool ignoreSpelling = false,
          dynamic filterParams}) async =>
      {};

  @override
  Future<Map<String, dynamic>> getPlaylistOrAlbumSongs(
          {String? playlistId,
          String? albumId,
          int limit = 3000,
          bool related = false,
          int suggestionsLimit = 0}) async =>
      {};

  @override
  Future<dynamic> getContentRelatedToSong(String videoId, String hlCode) async =>
      [];

  @override
  Future<String?> getStreamUrl(String mediaItemId) async => null;

  @override
  Future<List<Playlist>> getLibraryPlaylists() async => [];

  @override
  Future<Map<String, dynamic>> getSearchContinuation(
          Map<String, dynamic> additionalParamsNext,
          {int limit = 10}) async =>
      {};
}
