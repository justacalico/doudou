import 'package:jellyfin_dart/jellyfin_dart.dart';

import '../../models/album.dart';
import '../../models/artist.dart';
import '../../models/playlist.dart';
import '../../models/server.dart';
import 'backend_capabilities.dart';
import 'music_backend.dart';

class JellyfinBackend extends MusicBackend {
  JellyfinBackend(this.server);

  final SettingsServer server;

  JellyfinDart? _client;
  String? _token;
  String? _userId;

  String get _baseUrl {
    String url = server.serverUrl ?? '';
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    return url;
  }

  Future<void> _ensureAuth() async {
    if (_token != null && _userId != null) return;
    final url = _baseUrl;
    if (url.isEmpty || server.username == null || server.password == null) return;
    _client = JellyfinDart(basePathOverride: url);
    _client!.setDeviceId('doudou-${server.id}');
    _client!.setVersion('1.0');
    try {
      final auth = await _client!.getUserApi().authenticateUserByName(
            authenticateUserByName: AuthenticateUserByName(
              username: server.username!,
              pw: server.password!,
            ),
          );
      final result = auth.data;
      _token = result?.accessToken;
      _userId = result?.user?.id;
      if (_token != null) _client!.setToken(_token);
    } catch (_) {
      _client = null;
      _token = null;
      _userId = null;
    }
  }

  Map<String, dynamic> _itemToTrack(BaseItemDto item) {
    final id = item.id ?? '';
    final runTimeTicks = item.runTimeTicks;
    final seconds = runTimeTicks != null ? (runTimeTicks / 10000000).round() : null;
    String imageUrl = '';
    if (id.isNotEmpty && _baseUrl.isNotEmpty) {
      imageUrl = '$_baseUrl/Items/$id/Images/Primary?api_key=${_token ?? ''}';
    }
    final artists = <Map<String, String>>[];
    if (item.albumArtist != null && item.albumArtist!.isNotEmpty) {
      artists.add({'name': item.albumArtist!});
    }
    if (item.albumArtists != null) {
      for (final a in item.albumArtists!) {
        if (a.name != null) {
          artists.add({
            'name': a.name!,
            if (a.id != null) 'id': a.id!,
          });
        }
      }
    }
    if (item.artists != null) {
      for (final a in item.artists!) {
        artists.add({'name': a});
      }
    }
    if (artists.isEmpty) artists.add({'name': item.albumArtist ?? 'Unknown'});
    final streamUrl = _token != null && id.isNotEmpty
        ? '$_baseUrl/Audio/$id/stream?Static=true&api_key=$_token'
        : null;
    return {
      'videoId': id,
      'title': item.name ?? 'Unknown',
      'thumbnails': [{'url': imageUrl}],
      'artists': artists,
      'album': item.album != null ? {'name': item.album, 'id': null} : null,
      'duration': seconds,
      'url': streamUrl,
      'length': seconds != null ? '${seconds ~/ 60}:${seconds % 60}' : null,
      'backendType': 'jellyfin',
      'serverId': server.id,
    };
  }

  @override
  BackendCapabilities get capabilities => BackendCapabilities.jellyfin;

  @override
  Future<dynamic> getHome({int limit = 4}) async {
    await _ensureAuth();
    if (_client == null || _userId == null) return [];
    try {
      final res = await _client!.getItemsApi().getItems(
            userId: _userId,
            includeItemTypes: [BaseItemKind.audio],
            sortBy: [ItemSortBy.datePlayed],
            sortOrder: [SortOrder.descending],
            limit: limit,
          );
      final items = res.data?.items ?? [];
      if (items.isEmpty) return [];
      return [
        {
          'title': 'Recently Played',
          'contents': items.map((e) => _itemToTrack(e)).toList(),
        }
      ];
    } catch (_) {
      return [];
    }
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
    await _ensureAuth();
    if (_client == null || _userId == null) return {};
    try {
      final res = await _client!.getItemsApi().getItems(
            userId: _userId,
            searchTerm: query,
            includeItemTypes: [
              BaseItemKind.audio,
              BaseItemKind.musicAlbum,
              BaseItemKind.musicArtist,
              BaseItemKind.playlist,
            ],
            limit: limit,
          );
      final items = res.data?.items ?? [];
      final songs = <dynamic>[];
      final albums = <dynamic>[];
      final artists = <dynamic>[];
      final playlists = <dynamic>[];
      for (final item in items) {
        switch (item.type) {
          case BaseItemKind.audio:
            songs.add(_itemToTrack(item));
            break;
          case BaseItemKind.musicAlbum:
            albums.add({
              'browseId': item.id,
              'title': item.name,
              'thumbnails': item.id != null
                  ? [
                      {
                        'url':
                            '$_baseUrl/Items/${item.id}/Images/Primary?api_key=${_token ?? ''}'
                      }
                    ]
                  : [],
            });
            break;
          case BaseItemKind.musicArtist:
            artists.add({
              'browseId': item.id,
              'title': item.name,
              'thumbnails': item.id != null
                  ? [
                      {
                        'url':
                            '$_baseUrl/Items/${item.id}/Images/Primary?api_key=${_token ?? ''}'
                      }
                    ]
                  : [],
            });
            break;
          case BaseItemKind.playlist:
            playlists.add({
              'playlistId': item.id,
              'title': item.name,
              'thumbnails': item.id != null
                  ? [
                      {
                        'url':
                            '$_baseUrl/Items/${item.id}/Images/Primary?api_key=${_token ?? ''}'
                      }
                    ]
                  : [],
            });
            break;
          default:
            break;
        }
      }
      return {
        if (songs.isNotEmpty) 'Songs': songs,
        if (albums.isNotEmpty) 'Albums': albums,
        if (artists.isNotEmpty) 'Artists': artists,
        if (playlists.isNotEmpty) 'Playlists': playlists,
      };
    } catch (_) {
      return {};
    }
  }

  @override
  Future<Map<String, dynamic>> getPlaylistOrAlbumSongs(
      {String? playlistId,
      String? albumId,
      int limit = 3000,
      bool related = false,
      int suggestionsLimit = 0}) async {
    await _ensureAuth();
    if (_client == null || _userId == null) {
      return {'tracks': <dynamic>[], 'playlistId': playlistId ?? ''};
    }
    final id = playlistId ?? albumId;
    if (id == null || id.isEmpty) {
      return {'tracks': <dynamic>[], 'playlistId': id ?? ''};
    }
    try {
      final res = await _client!.getPlaylistsApi().getPlaylistItems(
            playlistId: id,
            userId: _userId,
            limit: limit,
          );
      final items = res.data?.items ?? [];
      final tracks = items.map((e) => _itemToTrack(e)).toList();
      return {'tracks': tracks, 'playlistId': id};
    } catch (_) {
      try {
        final res = await _client!.getItemsApi().getItems(
              userId: _userId,
              parentId: id,
              includeItemTypes: [BaseItemKind.audio],
              limit: limit,
            );
        final items = res.data?.items ?? [];
        final tracks = items.map((e) => _itemToTrack(e)).toList();
        return {'tracks': tracks, 'playlistId': id};
      } catch (_) {
        return {'tracks': <dynamic>[], 'playlistId': id};
      }
    }
  }

  @override
  Future<dynamic> getContentRelatedToSong(String videoId, String hlCode) async {
    return [];
  }

  @override
  Future<String?> getStreamUrl(String mediaItemId) async {
    await _ensureAuth();
    if (_token == null || mediaItemId.isEmpty) return null;
    return '$_baseUrl/Audio/$mediaItemId/stream?Static=true&api_key=$_token';
  }

  @override
  Future<List<Playlist>> getLibraryPlaylists() async {
    await _ensureAuth();
    if (_client == null || _userId == null) return [];
    try {
      final res = await _client!.getItemsApi().getItems(
            userId: _userId,
            includeItemTypes: [BaseItemKind.playlist],
          );
      final items = res.data?.items ?? [];
      return items.map((item) {
        final thumb = item.id != null
            ? '$_baseUrl/Items/${item.id}/Images/Primary?api_key=${_token ?? ''}'
            : '';
        return Playlist(
          title: item.name ?? 'Playlist',
          playlistId: item.id ?? '',
          thumbnailUrl: thumb,
          description: item.overview,
          songCount: item.childCount?.toString(),
          isPipedPlaylist: false,
          isCloudPlaylist: true,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Artist>> getLibraryArtists() async {
    await _ensureAuth();
    if (_client == null || _userId == null) return [];
    try {
      final res = await _client!.getItemsApi().getItems(
            userId: _userId,
            includeItemTypes: [BaseItemKind.musicArtist],
            limit: 10000,
          );
      final items = (res.data?.items ?? [])
          .where((item) => item.type == BaseItemKind.musicArtist)
          .toList();
      return items.map((item) {
        final id = item.id ?? '';
        final imageUrl = id.isNotEmpty && _baseUrl.isNotEmpty
            ? '$_baseUrl/Items/$id/Images/Primary?api_key=${_token ?? ''}'
            : '';
        return Artist.fromJson({
          'artist': item.name ?? 'Unknown',
          'browseId': id,
          'thumbnails': [{'url': imageUrl}],
        });
      }).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Album>> getLibraryAlbums() async {
    await _ensureAuth();
    if (_client == null || _userId == null) return [];
    try {
      final res = await _client!.getItemsApi().getItems(
            userId: _userId,
            includeItemTypes: [BaseItemKind.musicAlbum],
            limit: 10000,
          );
      final items = (res.data?.items ?? [])
          .where((item) => item.type == BaseItemKind.musicAlbum)
          .toList();
      return items.map((item) {
        final id = item.id ?? '';
        final imageUrl = id.isNotEmpty && _baseUrl.isNotEmpty
            ? '$_baseUrl/Items/$id/Images/Primary?api_key=${_token ?? ''}'
            : '';
        final artists = <Map<String, dynamic>>[];
        if (item.albumArtists != null) {
          for (final a in item.albumArtists!) {
            if (a.name != null) artists.add({'name': a.name!});
          }
        }
        if (artists.isEmpty) artists.add({'name': item.albumArtist ?? 'Unknown'});
        return Album.fromJson({
          'title': item.name ?? 'Unknown',
          'browseId': id,
          'artists': artists,
          'thumbnails': [{'url': imageUrl}],
          'year': item.productionYear?.toString(),
        });
      }).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getLibrarySongs() async {
    await _ensureAuth();
    if (_client == null || _userId == null) return [];
    try {
      final res = await _client!.getItemsApi().getItems(
            userId: _userId,
            includeItemTypes: [BaseItemKind.audio],
            limit: 10000,
          );
      final items = res.data?.items ?? [];
      return items.map((e) => _itemToTrack(e)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getFavoriteSongs() async {
    await _ensureAuth();
    if (_client == null || _userId == null) return [];
    try {
      final res = await _client!.getItemsApi().getItems(
            userId: _userId,
            includeItemTypes: [BaseItemKind.audio],
            isFavorite: true,
            limit: 10000,
          );
      final items = res.data?.items ?? [];
      return items.map((e) => _itemToTrack(e)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> setSongFavorite(String songId, bool favorite) async {
    await _ensureAuth();
    if (_client == null || _userId == null || songId.isEmpty) return;
    try {
      final api = _client!.getUserLibraryApi();
      if (favorite) {
        await api.markFavoriteItem(userId: _userId!, itemId: songId);
      } else {
        await api.unmarkFavoriteItem(userId: _userId!, itemId: songId);
      }
    } catch (_) {
      // ignore network errors for favorite toggles
    }
  }

  @override
  Future<Map<String, dynamic>> getSearchContinuation(
      Map<String, dynamic> additionalParamsNext,
      {int limit = 10}) async {
    return {};
  }
}
