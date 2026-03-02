import 'package:dio/dio.dart';

import '../../models/album.dart';
import '../../models/artist.dart';
import '../../models/playlist.dart';
import '../../models/server.dart';
import 'backend_capabilities.dart';
import 'music_backend.dart';

class SubsonicBackend extends MusicBackend {
  SubsonicBackend(this.server);

  final SettingsServer server;

  static const _clientName = 'HarmonyMusic';
  static const _version = '1.16.0';

  String get _baseUrl {
    String url = server.serverUrl ?? '';
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    return url;
  }

  Dio? _dio;

  String _restUrl(String method) =>
      '$_baseUrl/rest/$method.view?u=${Uri.encodeComponent(server.username ?? '')}&p=${Uri.encodeComponent(server.password ?? '')}&v=$_version&c=$_clientName&f=json';

  Future<Map<String, dynamic>?> _get(String method,
      [Map<String, String> params = const {}]) async {
    if (_baseUrl.isEmpty || server.username == null) return null;
    _dio ??= Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));
    final sb = StringBuffer(_restUrl(method));
    for (final e in params.entries) {
      sb.write('&${e.key}=${Uri.encodeComponent(e.value)}');
    }
    try {
      final r = await _dio!.get<Map<String, dynamic>>(sb.toString());
      final data = r.data;
      if (data == null) return null;
      final resp = data['subsonic-response'];
      if (resp is! Map || resp['status'] != 'ok') return null;
      return Map<String, dynamic>.from(resp);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _songToTrack(Map<String, dynamic> song) {
    final id = song['id']?.toString() ?? '';
    final duration = (song['duration'] as num?)?.toInt();
    final coverArt = song['coverArt']?.toString();
    String imageUrl = '';
    if (_baseUrl.isNotEmpty && coverArt != null && coverArt.isNotEmpty) {
      imageUrl = '${_restUrl('getCoverArt')}&id=$coverArt';
    }
    final streamUrl = id.isNotEmpty
        ? '$_baseUrl/rest/stream.view?u=${Uri.encodeComponent(server.username ?? '')}&p=${Uri.encodeComponent(server.password ?? '')}&v=$_version&c=$_clientName&id=$id'
        : null;
    return {
      'videoId': id,
      'title': song['title'] ?? 'Unknown',
      'thumbnails': [{'url': imageUrl}],
      'artists': [
        {'name': song['artist']?.toString() ?? 'Unknown'}
      ],
      'album': song['album'] != null
          ? {'name': song['album'], 'id': song['albumId']}
          : null,
      'duration': duration,
      'url': streamUrl,
      'length': duration != null ? '${duration ~/ 60}:${duration % 60}' : null,
      'backendType': 'subsonic',
      'serverId': server.id,
    };
  }

  @override
  BackendCapabilities get capabilities => BackendCapabilities.subsonic;

  @override
  Future<dynamic> getHome({int limit = 4}) async => [];

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
    final data = await _get('search2', {
      'query': query,
      'songCount': '$limit',
      'albumCount': '10',
      'artistCount': '10',
    });
    final sr = data?['searchResult2'];
    if (sr is! Map) return {};
    final result = <String, dynamic>{};
    final songs = sr['song'];
    if (songs is List) {
      result['Songs'] = songs
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .map(_songToTrack)
          .toList();
    }
    final albums = sr['album'];
    if (albums is List) {
      result['Albums'] = albums.map<Map<String, dynamic>>((e) {
        final m = Map<String, dynamic>.from(e as Map);
        final id = m['id']?.toString();
        return {
          'browseId': id,
          'title': m['title'] ?? m['name'],
          'thumbnails': [
            {
              'url': id != null && _baseUrl.isNotEmpty
                  ? '${_restUrl('getCoverArt')}&id=${m['coverArt'] ?? id}'
                  : ''
            }
          ],
        };
      }).toList();
    }
    final artists = sr['artist'];
    if (artists is List) {
      result['Artists'] = artists.map<Map<String, dynamic>>((e) {
        final m = Map<String, dynamic>.from(e as Map);
        final id = m['id']?.toString();
        return {
          'browseId': id,
          'title': m['name'],
          'thumbnails': [
            {
              'url': id != null && _baseUrl.isNotEmpty
                  ? '${_restUrl('getCoverArt')}&id=${m['coverArt'] ?? id}'
                  : ''
            }
          ],
        };
      }).toList();
    }
    return result;
  }

  @override
  Future<Map<String, dynamic>> getPlaylistOrAlbumSongs(
      {String? playlistId,
      String? albumId,
      int limit = 3000,
      bool related = false,
      int suggestionsLimit = 0}) async {
    final id = playlistId ?? albumId;
    if (id == null || id.isEmpty) {
      return {'tracks': <dynamic>[], 'playlistId': ''};
    }
    Map<String, dynamic>? data;
    if (playlistId != null) {
      data = await _get('getPlaylist', {'id': playlistId});
    } else {
      data = await _get('getMusicDirectory', {'id': albumId!});
    }
    List? entries;
    if (playlistId != null) {
      entries = data?['playlist']?['entry'];
    } else {
      entries = data?['directory']?['child'];
    }
    if (entries is! List) return {'tracks': <dynamic>[], 'playlistId': id};
    final tracks = entries
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
        .where((e) => e['isDir'] != true)
        .map(_songToTrack)
        .toList();
    return {'tracks': tracks, 'playlistId': id};
  }

  @override
  Future<dynamic> getContentRelatedToSong(String videoId, String hlCode) async {
    return [];
  }

  @override
  Future<String?> getStreamUrl(String mediaItemId) async {
    if (mediaItemId.isEmpty || _baseUrl.isEmpty || server.username == null) {
      return null;
    }
    return '$_baseUrl/rest/stream.view?u=${Uri.encodeComponent(server.username ?? '')}&p=${Uri.encodeComponent(server.password ?? '')}&v=$_version&c=$_clientName&id=$mediaItemId';
  }

  @override
  Future<List<Playlist>> getLibraryPlaylists() async {
    final data = await _get('getPlaylists');
    final list = data?['playlists']?['playlist'];
    if (list is! List) return [];
    return list.map<Playlist>((e) {
      final m = Map<String, dynamic>.from(e as Map);
      final id = m['id']?.toString() ?? '';
      final coverId = m['coverArt'] ?? id;
      final thumb = _baseUrl.isNotEmpty && id.isNotEmpty
          ? '${_restUrl('getCoverArt')}&id=$coverId'
          : '';
      return Playlist(
        title: m['name']?.toString() ?? 'Playlist',
        playlistId: id,
        thumbnailUrl: thumb,
        description: null,
        songCount: m['songCount']?.toString(),
        isPipedPlaylist: false,
        isCloudPlaylist: true,
      );
    }).toList();
  }

  @override
  Future<List<Artist>> getLibraryArtists() async {
    final data = await _get('getArtists');
    final indexes = data?['artists']?['index'];
    if (indexes is! List) return [];
    final out = <Artist>[];
    for (final idx in indexes) {
      final indexMap = idx is Map ? Map<String, dynamic>.from(idx) : null;
      final artistList = indexMap?['artist'];
      if (artistList is! List) continue;
      for (final a in artistList) {
        final m = a is Map ? Map<String, dynamic>.from(a) : null;
        if (m == null) continue;
        final id = m['id']?.toString() ?? '';
        final name = m['name']?.toString() ?? 'Unknown';
        final coverId = m['coverArt'] ?? id;
        final imageUrl = _baseUrl.isNotEmpty && coverId.isNotEmpty
            ? '${_restUrl('getCoverArt')}&id=$coverId'
            : '';
        out.add(Artist.fromJson({
          'artist': name,
          'browseId': id,
          'thumbnails': [{'url': imageUrl}],
        }));
      }
    }
    return out;
  }

  @override
  Future<List<Album>> getLibraryAlbums() async {
    final out = <Album>[];
    int offset = 0;
    const size = 500;
    while (true) {
      final data = await _get('getAlbumList', {
        'type': 'alphabeticalByName',
        'size': '$size',
        'offset': '$offset',
      });
      final list = data?['albumList']?['album'];
      if (list is! List || list.isEmpty) break;
      for (final e in list) {
        final m = e is Map ? Map<String, dynamic>.from(e) : null;
        if (m == null) continue;
        final id = m['id']?.toString() ?? '';
        final title = m['title'] ?? m['name'] ?? m['album'] ?? 'Unknown';
        final coverId = m['coverArt'] ?? id;
        final imageUrl = _baseUrl.isNotEmpty && coverId.isNotEmpty
            ? '${_restUrl('getCoverArt')}&id=$coverId'
            : '';
        final artistName = m['artist']?.toString() ?? 'Unknown';
        out.add(Album.fromJson({
          'title': title,
          'browseId': id,
          'artists': [{'name': artistName}],
          'thumbnails': [{'url': imageUrl}],
          'year': m['year']?.toString(),
        }));
      }
      if (list.length < size) break;
      offset += size;
    }
    return out;
  }

  @override
  Future<List<Map<String, dynamic>>> getLibrarySongs() async {
    final out = <Map<String, dynamic>>[];
    int offset = 0;
    const size = 500;
    while (true) {
      final data = await _get('getAlbumList', {
        'type': 'alphabeticalByName',
        'size': '$size',
        'offset': '$offset',
      });
      final list = data?['albumList']?['album'];
      if (list is! List || list.isEmpty) break;
      for (final e in list) {
        final albumMap = e is Map ? Map<String, dynamic>.from(e) : null;
        if (albumMap == null) continue;
        final albumId = albumMap['id']?.toString();
        if (albumId == null || albumId.isEmpty) continue;
        final dirData = await _get('getMusicDirectory', {'id': albumId});
        final children = dirData?['directory']?['child'];
        if (children is! List) continue;
        for (final c in children) {
          final m = c is Map ? Map<String, dynamic>.from(c) : null;
          if (m == null || m['isDir'] == true) continue;
          out.add(_songToTrack(m));
        }
      }
      if (list.length < size) break;
      offset += size;
    }
    return out;
  }

  @override
  Future<List<Map<String, dynamic>>> getFavoriteSongs() async {
    final data = await _get('getStarred2');
    final songs = data?['starred2']?['song'];
    if (songs is! List) return [];
    return songs
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
        .map(_songToTrack)
        .toList();
  }

  @override
  Future<void> setSongFavorite(String songId, bool favorite) async {
    if (songId.isEmpty) return;
    final method = favorite ? 'star' : 'unstar';
    await _get(method, {'id': songId});
  }

  @override
  Future<Map<String, dynamic>> getSearchContinuation(
      Map<String, dynamic> additionalParamsNext,
      {int limit = 10}) async {
    return {};
  }
}
