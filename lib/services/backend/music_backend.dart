import '../../models/album.dart';
import '../../models/artist.dart';
import '../../models/playlist.dart';
import 'backend_capabilities.dart';

abstract class MusicBackend {
  BackendCapabilities get capabilities;

  Future<List<Artist>> getLibraryArtists();
  Future<List<Album>> getLibraryAlbums();
  Future<List<Map<String, dynamic>>> getLibrarySongs();
  Future<List<Map<String, dynamic>>> getFavoriteSongs();

  Future<void> setSongFavorite(String songId, bool favorite);

  Future<dynamic> getHome({int limit = 4});

  Future<List<Map<String, dynamic>>> getCharts(String category,
      {String? countryCode});

  Future<Map<String, dynamic>> search(String query,
      {String? filter,
      String? scope,
      int limit = 30,
      bool ignoreSpelling = false,
      dynamic filterParams});

  Future<Map<String, dynamic>> getPlaylistOrAlbumSongs(
      {String? playlistId,
      String? albumId,
      int limit = 3000,
      bool related = false,
      int suggestionsLimit = 0});

  Future<dynamic> getContentRelatedToSong(String videoId, String hlCode);

  Future<String?> getStreamUrl(String mediaItemId);

  /// Headers required to fetch media bytes or artwork from this backend's
  /// server. Stream urls deliberately carry no credentials, so playback,
  /// downloads and image loading must attach these. Returns empty when no
  /// auth is needed, when the url does not belong to this server, or when the
  /// backend is not authenticated yet (best effort; for a guaranteed attempt
  /// use [mediaRequestHeadersFor]).
  Map<String, String> mediaRequestHeaders(String url) => const {};

  /// Like [mediaRequestHeaders] but may authenticate first, so callers that
  /// can await always get headers when the server requires them.
  Future<Map<String, String>> mediaRequestHeadersFor(String url) async =>
      mediaRequestHeaders(url);

  Future<List<Playlist>> getLibraryPlaylists();

  Future<Map<String, dynamic>> getSearchContinuation(
      Map<String, dynamic> additionalParamsNext,
      {int limit = 10});

  Future<String?> createPlaylist(String name, {List<String> songIds = const []}) async => null;

  Future<bool> addToPlaylist(String playlistId, List<String> songIds) async => false;
}
