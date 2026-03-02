import '../../models/album.dart' as app_album;
import '../../models/artist.dart' as app_artist;
import '../../models/playlist.dart' as app_playlist;
import '../../models/server.dart';
import '../players/plex_service.dart';
import 'backend_capabilities.dart';
import 'music_backend.dart';

class PlexBackend extends MusicBackend {
  PlexBackend(this.server) : _service = PlexService() {
    final url = server.serverUrl ?? '';
    final token = server.password ?? '';
    if (url.isNotEmpty && token.isNotEmpty) {
      _service.configure(serverUrl: url, token: token);
    }
  }

  final SettingsServer server;
  final PlexService _service;

  @override
  BackendCapabilities get capabilities => BackendCapabilities.plex;

  @override
  Future<dynamic> getHome({int limit = 4}) async {
    final tracks = await _service.getTracks(limit: limit);
    if (tracks.isEmpty) return [];
    return [
      {
        'title': 'Recently Added',
        'contents': tracks.map(_trackToMap).toList(),
      }
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getCharts(String category,
      {String? countryCode}) async {
    return [];
  }

  @override
  Future<Map<String, dynamic>> search(String query,
      {String? filter,
      String? scope,
      int limit = 30,
      bool ignoreSpelling = false,
      dynamic filterParams}) async {
    final res = await _service.search(query, limit: limit);
    final songs = res.tracks.map(_trackToMap).toList();
    final albums = res.albums
        .map((a) => {
              'browseId': a.id,
              'title': a.name,
              'thumbnails': [
                if (a.imageUrl != null && a.imageUrl!.isNotEmpty)
                  {'url': a.imageUrl}
              ],
            })
        .toList();
    final artists = res.artists
        .map((a) => {
              'browseId': a.id,
              'title': a.name,
              'thumbnails': [
                if (a.imageUrl != null && a.imageUrl!.isNotEmpty)
                  {'url': a.imageUrl}
              ],
            })
        .toList();
    return {
      if (songs.isNotEmpty) 'Songs': songs,
      if (albums.isNotEmpty) 'Albums': albums,
      if (artists.isNotEmpty) 'Artists': artists,
    };
  }

  @override
  Future<Map<String, dynamic>> getPlaylistOrAlbumSongs(
      {String? playlistId,
      String? albumId,
      int limit = 3000,
      bool related = false,
      int suggestionsLimit = 0}) async {
    if (playlistId == null && albumId == null) {
      return {'tracks': <dynamic>[], 'playlistId': ''};
    }
    final id = playlistId ?? albumId!;
    if (playlistId != null) {
      final tracks = await _service.getPlaylistTracks(playlistId);
      return {
        'tracks': tracks.map(_trackToMap).toList(),
        'playlistId': id,
      };
    } else {
      final tracks = await _service.getTracks(parentId: albumId);
      return {
        'tracks': tracks.map(_trackToMap).toList(),
        'playlistId': id,
      };
    }
  }

  @override
  Future<dynamic> getContentRelatedToSong(String videoId, String hlCode) async {
    return [];
  }

  @override
  Future<String?> getStreamUrl(String mediaItemId) async {
    if (mediaItemId.isEmpty) return null;
    return _service.getBestStreamUrl(mediaItemId);
  }

  @override
  Future<List<app_playlist.Playlist>> getLibraryPlaylists() async {
    final list = await _service.getPlaylists();
    return list
        .map(
          (p) => app_playlist.Playlist(
            title: p.name,
            playlistId: p.id,
            description: null,
            thumbnailUrl: p.imageUrl ?? app_playlist.Playlist.thumbPlaceholderUrl,
            songCount: p.trackCount.toString(),
            isPipedPlaylist: false,
            isCloudPlaylist: true,
          ),
        )
        .toList();
  }

  @override
  Future<List<app_artist.Artist>> getLibraryArtists() async {
    final list = await _service.getArtists();
    return list
        .map(
          (a) => app_artist.Artist(
            name: a.name,
            browseId: a.id,
            radioId: null,
            thumbnailUrl: a.imageUrl ?? '',
            subscribers: null,
          ),
        )
        .toList();
  }

  @override
  Future<List<app_album.Album>> getLibraryAlbums() async {
    final list = await _service.getAlbums();
    return list
        .map(
          (a) => app_album.Album(
            title: a.name,
            browseId: a.id,
            artists: [
              {'name': a.artistName ?? 'Unknown'}
            ],
            year: a.year?.toString(),
            audioPlaylistId: null,
            description: 'Album',
            thumbnailUrl: a.imageUrl ?? '',
          ),
        )
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getLibrarySongs() async {
    final tracks = await _service.getTracks();
    return tracks.map(_trackToMap).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getFavoriteSongs() async {
    final tracks = await _service.getTracks(); // no favorites endpoint yet
    return tracks.map(_trackToMap).toList();
  }

  @override
  Future<void> setSongFavorite(String songId, bool favorite) async {
    // Favorites are not yet wired through PlexService in this build.
    return;
  }

  @override
  Future<Map<String, dynamic>> getSearchContinuation(
      Map<String, dynamic> additionalParamsNext,
      {int limit = 10}) async {
    return {};
  }

  Map<String, dynamic> _trackToMap(track) {
    return {
      'videoId': track.id,
      'title': track.name,
      'thumbnails': [
        if (track.imageUrl != null && track.imageUrl!.isNotEmpty)
          {'url': track.imageUrl}
      ],
      'artists': [
        {'name': track.artistName ?? 'Unknown'}
      ],
      'album': track.albumName != null
          ? {
              'name': track.albumName,
              'id': track.albumId,
            }
          : null,
      'duration': track.duration,
      'url': _service.getStreamUrl(track.id),
      'length':
          track.duration != null ? '${track.duration ~/ 60}:${track.duration % 60}' : null,
      'backendType': 'plex',
      'serverId': server.id,
    };
  }
}

