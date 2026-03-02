import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../../models/album.dart';
import '../../models/artist.dart';
import '../../models/playlist.dart';
import '../../ui/screens/Settings/settings_screen_controller.dart';
import '../../utils/server_storage.dart';
import '../music_service.dart';
import 'backend_capabilities.dart';
import 'music_backend.dart';

class YouTubeMusicBackend extends MusicBackend {
  YouTubeMusicBackend() : _musicServices = Get.find<MusicServices>();

  final MusicServices _musicServices;

  @override
  BackendCapabilities get capabilities => BackendCapabilities.youtubeMusic;

  @override
  Future<dynamic> getHome({int limit = 4}) =>
      _musicServices.getHome(limit: limit);

  @override
  Future<List<Map<String, dynamic>>> getCharts(String category,
          {String? countryCode}) =>
      _musicServices.getCharts(category, countryCode: countryCode);

  @override
  Future<Map<String, dynamic>> search(String query,
      {String? filter,
      String? scope,
      int limit = 30,
      bool ignoreSpelling = false,
      dynamic filterParams}) {
    return _musicServices.search(query,
        filter: filter,
        scope: scope,
        limit: limit,
        ignoreSpelling: ignoreSpelling,
        filterParams: filterParams is String ? filterParams : null);
  }

  @override
  Future<Map<String, dynamic>> getPlaylistOrAlbumSongs(
      {String? playlistId,
      String? albumId,
      int limit = 3000,
      bool related = false,
      int suggestionsLimit = 0}) {
    return _musicServices.getPlaylistOrAlbumSongs(
        playlistId: playlistId,
        albumId: albumId,
        limit: limit,
        related: related,
        suggestionsLimit: suggestionsLimit);
  }

  @override
  Future<dynamic> getContentRelatedToSong(String videoId, String hlCode) =>
      _musicServices.getContentRelatedToSong(videoId, hlCode);

  @override
  Future<String?> getStreamUrl(String mediaItemId) async => null;

  @override
  Future<List<Playlist>> getLibraryPlaylists() async => [];

  @override
  Future<List<Artist>> getLibraryArtists() async {
    final serverId =
        Get.find<SettingsScreenController>().activeServerId.value ?? 0;
    final box = await Hive.openBox(libraryArtistsBoxName(serverId));
    final list = box.values
        .map<Artist?>((item) => Artist.fromJson(item))
        .whereType<Artist>()
        .toList();
    return list;
  }

  @override
  Future<List<Album>> getLibraryAlbums() async {
    final serverId =
        Get.find<SettingsScreenController>().activeServerId.value ?? 0;
    final box = await Hive.openBox(libraryAlbumsBoxName(serverId));
    return box.values
        .map<Album?>((item) => Album.fromJson(item))
        .whereType<Album>()
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getLibrarySongs() async {
    // YouTube Music library songs are handled via existing local logic
    // in LibrarySongsController using cached and downloaded songs.
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getFavoriteSongs() async {
    // YouTube Music favorites are stored locally in Hive (LIBFAV),
    // so this backend method is unused.
    return [];
  }

  @override
  Future<void> setSongFavorite(String songId, bool favorite) async {
    // YouTube Music favorites are handled locally via Hive in PlayerController.
    return;
  }

  @override
  Future<Map<String, dynamic>> getSearchContinuation(
          Map<String, dynamic> additionalParamsNext,
          {int limit = 10}) =>
      _musicServices.getSearchContinuation(additionalParamsNext, limit: limit);
}
