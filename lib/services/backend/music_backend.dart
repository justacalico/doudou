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

  Future<List<Playlist>> getLibraryPlaylists();

  Future<Map<String, dynamic>> getSearchContinuation(
      Map<String, dynamic> additionalParamsNext,
      {int limit = 10});

  Future<String?> createPlaylist(String name, {List<String> songIds = const []}) async => null;

  Future<bool> addToPlaylist(String playlistId, List<String> songIds) async => false;
}
