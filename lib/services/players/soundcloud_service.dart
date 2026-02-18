import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kib_debug_print/kib_debug_print.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/jellyfin_models.dart';
import '../base_service.dart';

/// SoundCloud API service using user-provided client credentials.
/// Users register an app at https://developers.soundcloud.com and paste
/// client_id and client_secret into settings.
/// Uses Client Credentials flow for public resources (search, stream).
/// See: https://developers.soundcloud.com/docs/api/guide
class SoundCloudService implements BaseMediaService {
  static const String _apiBase = 'https://api.soundcloud.com';

  /// Log so it always appears in terminal; kprint only in debug (release-safe).
  static void _log(String msg, {bool isError = false}) {
    if (kDebugMode) {
      print('[SoundCloud] $msg');
    }
    if (kDebugMode) {
      if (isError) {
        kprint.err(msg);
      } else {
        kprint.lg(msg, symbol: '🌐');
      }
    }
  }

  late Dio _dio;
  String? _clientId;
  String? _clientSecret;
  String? _accessToken;
  DateTime? _tokenExpiry;

  static const String _apiV2Base = 'https://api-v2.soundcloud.com';
  String? _embeddedClientId;
  DateTime? _embeddedClientIdFetched;
  static const Duration _embeddedClientIdCache = Duration(hours: 1);

  // Local playlists, favorites, and followed artists (persisted in SharedPreferences). Keyed by server ID so each server keeps its own data when switching.
  String? _serverId;
  String _prefsKey(String base) =>
      _serverId != null && _serverId!.isNotEmpty ? '${base}_$_serverId' : base;
  List<Playlist> _localPlaylists = [];
  final Map<String, List<Map<String, dynamic>>> _localPlaylistTracks = {};
  List<Map<String, dynamic>> _localFavorites = [];
  List<Map<String, dynamic>> _localFollowedArtists = [];
  bool _localDataLoaded = false;

  @override
  ServerType get serverType => ServerType.soundcloud;

  SoundCloudService() {
    _dio = Dio(BaseOptions(
      baseUrl: _apiBase,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json; charset=utf-8'},
    ));
  }

  @override
  Future<bool> authenticate(
    String serverUrl,
    String identifier,
    String credential,
  ) async {
    _clientId = identifier.trim();
    _clientSecret = credential.trim();
    if (_clientId!.isEmpty || _clientSecret!.isEmpty) {
      _log('login: missing Client ID or Client Secret', isError: true);
      return false;
    }
    _log('login: obtaining token (client_id=${_clientId!.length} chars)');
    return _obtainToken();
  }

  Future<bool> _obtainToken() async {
    _lastError = null;
    final credentials = base64Encode(utf8.encode('$_clientId:$_clientSecret'));
    // SoundCloud only supports oauth/token (oauth2/token does not exist and returns 404)
    _log('trying oauth/token');
    return _requestToken(
      'https://secure.soundcloud.com/oauth/token',
      credentials,
      {'grant_type': 'client_credentials'},
    );
  }

  Future<bool> _requestToken(
    String url,
    String credentials,
    Map<String, String> body,
  ) async {
    try {
      _log('POST $url');
      final response = await _dio.post<Map<String, dynamic>>(
        url,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'Authorization': 'Basic $credentials',
            'Accept': 'application/json; charset=utf-8',
          },
        ),
        data: body,
      );

      if (response.data == null) {
        _log('token response has no body', isError: true);
        return false;
      }

      _accessToken = response.data!['access_token'] as String?;
      final expiresIn = response.data!['expires_in'] as int? ?? 3600;
      _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

      if (_accessToken == null || _accessToken!.isEmpty) {
        _log('token response missing access_token', isError: true);
        return false;
      }

      _dio.options.headers['Authorization'] = 'OAuth $_accessToken';
      _log('token obtained, expires_in=${expiresIn}s');
      // Pre-warm embedded client_id for faster first playback
      unawaited(_getEmbeddedClientId());
      return true;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      if (data is Map && data['error'] != null) {
        _lastError = data['error'] as String?;
        final desc = data['error_description'] as String?;
        if (desc != null) _lastError = '$_lastError: $desc';
      }
      _log('token request failed status=$status error=$_lastError body=${e.response?.data}', isError: true);
      return false;
    } catch (e, st) {
      _log('token request threw: $e', isError: true);
      if (kDebugMode) {
        print('[SoundCloud] $st');
      }
      if (kDebugMode) {
        kprint.err('[SoundCloud] $st');
      }
      return false;
    }
  }

  String? _lastError;

  /// Last error from token endpoint (e.g. invalid_client, rate_limit_exceeded). Null if none.
  /// Returns a user-friendly message when the error is known.
  String? get lastAuthError {
    if (_lastError == null) return null;
    switch (_lastError!) {
      case 'rate_limit_exceeded':
        return 'Rate limit exceeded. Please wait a few minutes before trying again.';
      case 'invalid_client':
      case 'invalid_client_id':
        return 'Invalid Client ID or Client Secret. Check your app at developers.soundcloud.com.';
      default:
        return _lastError;
    }
  }

  Future<bool> _ensureToken() async {
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!.subtract(const Duration(minutes: 5)))) {
      return true;
    }
    return _obtainToken();
  }

  @override
  void setServer(String serverUrl) {}

  @override
  void setServerId(String? serverId) {
    _serverId = serverId;
  }

  @override
  Future<void> persistLocalDataIfAny() async {
    if (!_localDataLoaded) return;
    await _saveLocalPlaylists();
    await _saveLocalFavorites();
    await _saveFollowedArtists();
  }

  @override
  Future<bool> validateCredentials() async {
    if (_clientId == null || _clientSecret == null) return false;
    return _obtainToken();
  }

  @override
  void clearAuth() {
    _clientId = null;
    _clientSecret = null;
    _accessToken = null;
    _tokenExpiry = null;
    _lastError = null;
    _dio.options.headers.remove('Authorization');
    _localPlaylists = [];
    _localPlaylistTracks.clear();
    _localFavorites = [];
    _localFollowedArtists = [];
    _localDataLoaded = false;
  }

  /// Follow an artist (SoundCloud only) - their tracks show up on home/library
  Future<bool> followArtist(Artist artist) async {
    await _loadLocalData();
    if (_localFollowedArtists.any((a) => a['id'] == artist.id)) return true;
    _localFollowedArtists.add({
      'id': artist.id,
      'name': artist.name,
      'imageUrl': artist.imageUrl,
    });
    await _saveFollowedArtists();
    return true;
  }

  /// Unfollow an artist
  Future<bool> unfollowArtist(String userId) async {
    await _loadLocalData();
    _localFollowedArtists.removeWhere((a) => a['id'] == userId);
    await _saveFollowedArtists();
    return true;
  }

  bool isFollowingArtist(String userId) {
    return _localFollowedArtists.any((a) => a['id'] == userId);
  }

  Future<List<Artist>> getFollowedArtists() async {
    await _loadLocalData();
    return _localFollowedArtists.map((j) => Artist(
      id: j['id'] ?? '',
      name: j['name'] ?? 'Unknown Artist',
      imageUrl: j['imageUrl'] as String?,
    )).toList();
  }

  Future<void> _saveFollowedArtists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey('soundcloud_followed_artists'), jsonEncode(_localFollowedArtists));
    } catch (e) {
      if (kDebugMode) _log('_saveFollowedArtists failed: $e', isError: true);
    }
  }

  /// Fetch tracks for a specific artist (user) via /users/{id}/tracks
  /// SoundCloud returns { collection: [...], next_href?: string } when linked_partitioning=true
  Future<List<Track>> getArtistTracks(String userId, {String? artistName}) async {
    if (!await _ensureToken()) return [];
    try {
      final response = await _dio.get<dynamic>(
        '/users/$userId/tracks',
        queryParameters: {'limit': 100, 'linked_partitioning': 'true'},
      );
      final raw = response.data;
      List<dynamic> list;
      if (raw is List<dynamic>) {
        list = raw;
      } else if (raw is Map<String, dynamic>) {
        final coll = raw['collection'];
        list = coll is List<dynamic> ? coll : <dynamic>[];
      } else {
        return [];
      }
      final fallbackName = artistName ?? _localFollowedArtists
          .where((a) => a['id'] == userId)
          .map((a) => a['name'] as String)
          .firstOrNull ?? 'Unknown Artist';
      final tracks = <Track>[];
      for (final item in list) {
        if (item is! Map<String, dynamic>) continue;
        final id = item['id']?.toString();
        if (id == null) continue;
        final user = item['user'] as Map<String, dynamic>?;
        final durationMs = item['duration'] != null ? (item['duration'] as num).toInt() : null;
        final artwork = item['artwork_url'] as String?;
        tracks.add(Track(
          id: id,
          name: item['title'] as String? ?? 'Unknown',
          artistName: user?['username'] ?? fallbackName,
          albumName: null,
          duration: durationMs,
          imageUrl: artwork,
          isFavorite: _localFavorites.any((f) => (f['id'] ?? '').toString() == id),
        ));
      }
      return tracks;
    } catch (e) {
      if (kDebugMode) _log('getArtistTracks $userId: $e', isError: true);
      return [];
    }
  }

  /// Fetch tracks from followed artists via /users/{id}/tracks
  /// SoundCloud returns { collection: [...], next_href?: string } when linked_partitioning=true
  Future<List<Track>> _getTracksFromFollowedArtists({int? maxPerArtist}) async {
    if (!await _ensureToken()) return [];
    final limit = maxPerArtist ?? 50;
    final allTracks = <Track>[];
    for (final a in _localFollowedArtists) {
      final userId = a['id'] as String?;
      if (userId == null || userId.isEmpty) continue;
      try {
        final response = await _dio.get<dynamic>(
          '/users/$userId/tracks',
          queryParameters: {'limit': limit, 'linked_partitioning': 'true'},
        );
        final raw = response.data;
        List<dynamic> list;
        if (raw is List<dynamic>) {
          list = raw;
        } else if (raw is Map<String, dynamic>) {
          final coll = raw['collection'];
          list = coll is List<dynamic> ? coll : <dynamic>[];
        } else {
          continue;
        }
        final artistName = a['name'] as String? ?? 'Unknown Artist';
        for (final item in list) {
          if (item is! Map<String, dynamic>) continue;
          final id = item['id']?.toString();
          if (id == null) continue;
          final user = item['user'] as Map<String, dynamic>?;
          final name = user?['username'] ?? artistName;
          final durationMs = item['duration'] != null ? (item['duration'] as num).toInt() : null;
          final artwork = item['artwork_url'] as String?;
          allTracks.add(Track(
            id: id,
            name: item['title'] as String? ?? 'Unknown',
            artistName: name,
            albumName: null,
            duration: durationMs,
            imageUrl: artwork,
            isFavorite: _localFavorites.any((f) => (f['id'] ?? '').toString() == id),
          ));
        }
      } catch (e) {
        if (kDebugMode) _log('getTracksFromFollowedArtists user $userId: $e', isError: true);
      }
    }
    return allTracks;
  }

  Future<void> _loadLocalData() async {
    if (_localDataLoaded) return;
    _localDataLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final playlistsJson = prefs.getString(_prefsKey('soundcloud_playlists'));
      if (playlistsJson != null) {
        final list = jsonDecode(playlistsJson) as List<dynamic>?;
        _localPlaylists = (list ?? []).map((e) => _playlistFromJson(e as Map<String, dynamic>)).toList();
      }
      final tracksJson = prefs.getString(_prefsKey('soundcloud_playlist_tracks'));
      if (tracksJson != null) {
        final map = jsonDecode(tracksJson) as Map<String, dynamic>?;
        _localPlaylistTracks.clear();
        if (map != null) {
          for (final entry in map.entries) {
            final list = entry.value as List<dynamic>?;
            _localPlaylistTracks[entry.key] = list?.cast<Map<String, dynamic>>() ?? [];
          }
        }
      }
      final favJson = prefs.getString(_prefsKey('soundcloud_favorites'));
      if (favJson != null) {
        final list = jsonDecode(favJson) as List<dynamic>?;
        _localFavorites = list?.cast<Map<String, dynamic>>() ?? [];
      }
      final followedJson = prefs.getString(_prefsKey('soundcloud_followed_artists'));
      if (followedJson != null) {
        final list = jsonDecode(followedJson) as List<dynamic>?;
        _localFollowedArtists = list?.cast<Map<String, dynamic>>() ?? [];
      }
    } catch (e) {
      if (kDebugMode) _log('_loadLocalData failed: $e', isError: true);
    }
  }

  Future<void> _saveLocalPlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey('soundcloud_playlists'), jsonEncode(_localPlaylists.map(_playlistToJson).toList()));
      final tracksMap = <String, List<Map<String, dynamic>>>{};
      for (final e in _localPlaylistTracks.entries) {
        tracksMap[e.key] = e.value;
      }
      await prefs.setString(_prefsKey('soundcloud_playlist_tracks'), jsonEncode(tracksMap));
    } catch (e) {
      if (kDebugMode) _log('_saveLocalPlaylists failed: $e', isError: true);
    }
  }

  Future<void> _saveLocalFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey('soundcloud_favorites'), jsonEncode(_localFavorites));
    } catch (e) {
      if (kDebugMode) _log('_saveLocalFavorites failed: $e', isError: true);
    }
  }

  static Map<String, dynamic> _playlistToJson(Playlist p) => {
        'id': p.id,
        'name': p.name,
        'imageUrl': p.imageUrl,
        'trackCount': p.trackCount,
      };
  static Playlist _playlistFromJson(Map<String, dynamic> j) => Playlist(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        imageUrl: j['imageUrl'],
        trackCount: (j['trackCount'] as num?)?.toInt() ?? 0,
      );

  static Track _trackFromStoredJson(Map<String, dynamic> j) => Track(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        artistName: j['artistName'],
        albumName: j['albumName'],
        albumId: j['albumId'],
        duration: (j['duration'] as num?)?.toInt(),
        imageUrl: j['imageUrl'],
        isFavorite: j['isFavorite'] == true,
      );
  static Map<String, dynamic> _trackToStoredJson(Track t) => {
        'id': t.id,
        'name': t.name,
        'artistName': t.artistName,
        'albumName': t.albumName,
        'albumId': t.albumId,
        'duration': t.duration,
        'imageUrl': t.imageUrl,
        'isFavorite': t.isFavorite,
      };

  @override
  dynamic get currentServer => {
        'url': _apiBase,
        'clientId': _clientId,
      };

  @override
  Future<List<Library>> getLibraries() async {
    return [
      Library(
        id: 'soundcloud',
        name: 'SoundCloud',
        collectionType: 'music',
        imageUrl: null,
      ),
    ];
  }

  @override
  Future<List<Album>> getAlbums({
    String? libraryId,
    int? limit,
    int? startIndex,
  }) async {
    // SoundCloud has no albums; map playlists to albums so Library shows content
    final playlists = await getPlaylists();
    return playlists
        .map((p) => Album(
              id: p.id,
              name: p.name,
              artistName: null,
              imageUrl: p.imageUrl,
              isFavorite: false,
            ))
        .toList();
  }

  @override
  Future<List<Track>> getStarredTracks() async {
    try {
      await _loadLocalData();
      return _localFavorites.map(_trackFromStoredJson).toList();
    } catch (e) {
      if (kDebugMode) _log('getStarredTracks failed: $e', isError: true);
      return [];
    }
  }

  @override
  Future<List<Album>> getStarredAlbums() async => [];

  @override
  Future<List<Artist>> getStarredArtists() async => [];

  @override
  Future<List<Artist>> getArtists({
    String? libraryId,
    int? limit,
    int? startIndex,
  }) async {
    await _loadLocalData();
    // SoundCloud: Artists = followed artists (your dashboard shows their content)
    return getFollowedArtists();
  }

  @override
  Future<List<Track>> getAllTracks({int? maxTracks}) async {
    try {
      await _loadLocalData();
      // SoundCloud: followed artists + favorites + all playlist tracks
      final fromFollowed = await _getTracksFromFollowedArtists(
        maxPerArtist: ((maxTracks ?? 500) / 10).ceil().clamp(10, 100),
      );
      final favorites = await getStarredTracks();
      final seen = <String>{};
      final merged = <Track>[];
      for (final t in [...fromFollowed, ...favorites]) {
        if (seen.contains(t.id)) continue;
        seen.add(t.id);
        merged.add(t);
      }
      for (final entry in _localPlaylistTracks.entries) {
        for (final j in entry.value) {
          final t = _trackFromStoredJson(j);
          if (seen.contains(t.id)) continue;
          seen.add(t.id);
          merged.add(t);
        }
      }
      return merged;
    } catch (e) {
      if (kDebugMode) _log('getAllTracks failed: $e', isError: true);
      return [];
    }
  }

  @override
  List<String> getAlternativeStreamUrls(String trackId) => [];

  @override
  Future<List<Track>> getTracks({
    String? libraryId,
    String? parentId,
    int? limit,
    int? startIndex,
  }) async {
    if (parentId != null && parentId.isNotEmpty) {
      return getPlaylistTracks(parentId);
    }
    final results = await search('', limit: limit ?? 100);
    return results.tracks;
  }

  @override
  Future<List<Playlist>> getPlaylists() async {
    await _loadLocalData();
    return List<Playlist>.from(_localPlaylists);
  }

  @override
  Future<List<Track>> getPlaylistTracks(String playlistId) async {
    await _loadLocalData();
    final list = _localPlaylistTracks[playlistId];
    if (list == null) return [];
    return list.map((j) {
      final t = _trackFromStoredJson(j);
      return Track(
        id: t.id,
        name: t.name,
        artistName: t.artistName,
        albumName: t.albumName,
        albumId: playlistId,
        duration: t.duration,
        imageUrl: t.imageUrl,
        isFavorite: t.isFavorite,
      );
    }).toList();
  }

  @override
  String getStreamUrl(String trackId, {int? bitrate}) {
    return '';
  }

  /// SoundCloud API expects numeric track id. Strip URN prefix if present (e.g. from MPRIS/media item).
  static String _normalizeTrackId(String trackId) {
    if (trackId.startsWith('soundcloud:tracks:')) {
      return trackId.substring('soundcloud:tracks:'.length);
    }
    return trackId;
  }

  /// Ensure URL has client_id for streaming (required by SoundCloud).
  String? _urlWithClientId(String? url) {
    if (url == null || url.isEmpty || _clientId == null) return url;
    String abs = url;
    if (url.startsWith('/')) {
      abs = '$_apiBase$url';
    }
    final uri = Uri.tryParse(abs);
    if (uri == null) return abs;
    if (uri.queryParameters.containsKey('client_id')) return abs;
    final sep = abs.contains('?') ? '&' : '?';
    return '$abs${sep}client_id=$_clientId';
  }

  /// Only CDN URLs work for playback; api.soundcloud.com URLs require Authorization
  /// which the player (MPV) cannot send, so they always 401.
  static bool _isUsableStreamUrl(String url) {
    if (url.isEmpty) return false;
    final lower = url.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) return false;
    if (lower.contains('api.soundcloud.com')) return false;
    return true;
  }

  /// Redact query for logs (keep param names, hide values).
  static String _redactUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url.length > 80 ? '${url.substring(0, 80)}...' : url;
    final q = uri.queryParameters;
    if (q.isEmpty) return url.length > 100 ? '${url.substring(0, 100)}...' : url;
    final redacted = q.keys.map((k) => '$k=***').join('&');
    return '${uri.origin}${uri.path}?$redacted';
  }

  /// Some SoundCloud responses use transcodings array: [{ "url": "...", "protocol": "hls" }, ...].
  List<String> _addUrlsFromTranscodings(Map<String, dynamic> data, List<String> urls) {
    final list = data['transcodings'] as List<dynamic>?;
    if (list == null) return urls;
    for (final t in list) {
      if (t is! Map<String, dynamic>) continue;
      final url = t['url'] as String?;
      if (url == null || url.isEmpty) continue;
      final u = _urlWithClientId(url) ?? url;
      if (_isUsableStreamUrl(u) && !urls.contains(u)) urls.add(u);
      if (u.toLowerCase().contains('api.soundcloud.com')) {
        // will be resolved later in caller
      }
    }
    return urls;
  }

  /// Api-v2 style: media.transcodings; prefer progressive (see sound-on-fire).
  void _addApiUrlsFromMediaTranscodings(Map<String, dynamic> data, List<String> apiUrls) {
    final media = data['media'] as Map<String, dynamic>?;
    final list = media?['transcodings'] as List<dynamic>?;
    if (list == null) return;
    final fromMedia = <String>[];
    String? progressiveUrl;
    for (final t in list) {
      if (t is! Map<String, dynamic>) continue;
      final url = t['url'] as String?;
      if (url == null || url.isEmpty) continue;
      final format = t['format'] as Map<String, dynamic>?;
      final protocol = format?['protocol'] as String?;
      final u = _urlWithClientId(url) ?? url;
      if (u.isEmpty || !u.toLowerCase().contains('api.soundcloud.com')) continue;
      if (protocol == 'progressive') progressiveUrl ??= u;
      if (!fromMedia.contains(u)) fromMedia.add(u);
    }
    if (progressiveUrl != null) apiUrls.insert(0, progressiveUrl);
    for (final u in fromMedia) {
      if (!apiUrls.contains(u)) apiUrls.add(u);
    }
  }

  List<String> _collectStreamUrlsFromMap(Map<String, dynamic> data) {
    final urls = <String>[];
    if (data['stream_url'] != null && _clientId != null) {
      final streamUrl = data['stream_url'] as String;
      final u = _urlWithClientId(streamUrl) ?? streamUrl;
      if (_isUsableStreamUrl(u)) urls.add(u);
    }
    final httpMp3 = data['http_mp3_128_url'] as String?;
    if (httpMp3 != null && httpMp3.isNotEmpty) {
      final u = _urlWithClientId(httpMp3) ?? httpMp3;
      if (_isUsableStreamUrl(u) && !urls.contains(u)) urls.add(u);
    }
    final hlsAac = data['hls_aac_160_url'] as String? ?? data['hls_aac_96_url'] as String?;
    if (hlsAac != null && hlsAac.isNotEmpty) {
      final u = _urlWithClientId(hlsAac) ?? hlsAac;
      if (_isUsableStreamUrl(u) && !urls.contains(u)) urls.add(u);
    }
    final preview = data['preview_mp3_128_url'] as String?;
    if (preview != null && preview.isNotEmpty) {
      final u = _urlWithClientId(preview) ?? preview;
      if (_isUsableStreamUrl(u) && !urls.contains(u)) urls.add(u);
    }
    return urls;
  }

  /// Fetch client_id embedded in SoundCloud's public pages (used by their web player).
  /// Enables api-v2 streaming when the official API returns 401.
  Future<String?> _getEmbeddedClientId() async {
    if (_embeddedClientId != null &&
        _embeddedClientIdFetched != null &&
        DateTime.now().difference(_embeddedClientIdFetched!) < _embeddedClientIdCache) {
      return _embeddedClientId;
    }
    const headers = {
      'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml',
    };
    Future<String?> tryPage(String url, {bool logBody = false}) async {
      try {
        final res = await http.get(Uri.parse(url), headers: headers);
        if (res.statusCode != 200) return null;
        final body = res.body;
        if (logBody && kDebugMode && body.isNotEmpty) {
          final snippet = body.length > 500 ? body.substring(0, 500) : body;
          _log('playback: page body (first ${snippet.length} chars): $snippet');
        }
        if (kDebugMode) _log('playback: [embed] tryPage url=$url');
        RegExp re = RegExp(r',client_id:\s*"([a-zA-Z0-9_.-]{20,})"');
        var match = re.firstMatch(body);
        match ??= RegExp(r'client_id:\s*"([a-zA-Z0-9_.-]{20,})"').firstMatch(body);
        match ??= RegExp(r"client_id:\s*'([a-zA-Z0-9_.-]{20,})'").firstMatch(body);
        match ??= RegExp(r'client_id=([a-zA-Z0-9_.-]{20,})').firstMatch(body);
        if (match != null) {
          final cid = match.group(1)!;
          if (cid.length >= 20) {
            if (kDebugMode) _log('playback: [embed] client_id found in page body (regex)');
            return cid;
          }
        }
        if (kDebugMode) _log('playback: [embed] no client_id in page body, trying script URLs');
        if (kDebugMode) _log('playback: [embed] page body length=${body.length}, collecting unique script URLs');
        final List<RegExp> scriptUrlPatterns = [
          RegExp(r'https://a-v2\.sndcdn\.com/[^"]+\.js'),
          RegExp(r'//a-v2\.sndcdn\.com/([^"]+\.js)'),
          RegExp(r'https://[a-z0-9.-]+\.sndcdn\.com/[^"]+\.js'),
          RegExp(r'src="(https://[^"]*sndcdn[^"]+\.js)"'),
          RegExp(r'src="(//[^"]*sndcdn[^"]+\.js)"'),
          RegExp(r'[a-z0-9.-]+\.sndcdn\.com/([^"\s>]+\.js)'),
          RegExp(r'"(https://[^"]*sndcdn[^"]+\.js)"'),
          RegExp(r'"(//[^"]*sndcdn[^"]+\.js)"'),
        ];
        final Set<String> uniqueUrls = {};
        for (final pattern in scriptUrlPatterns) {
          for (final m in pattern.allMatches(body)) {
            final String raw = m.groupCount >= 1 && m.group(1) != null ? m.group(1)! : m.group(0)!;
            String url = raw;
            if (!url.startsWith('http')) url = url.startsWith('//') ? 'https:$url' : 'https://a-v2.sndcdn.com/$url';
            uniqueUrls.add(url);
          }
        }
        if (kDebugMode) _log('playback: [embed] unique script URLs: ${uniqueUrls.length}, fetching in parallel');
        // Fetch all scripts in parallel for faster client_id extraction
        final scriptBodies = await Future.wait(
          uniqueUrls.map((scriptUrl) async {
            try {
              final res = await http.get(Uri.parse(scriptUrl), headers: headers);
              return res.statusCode == 200 ? res.body : null;
            } catch (_) {
              return null;
            }
          }),
        );
        for (final scriptBody in scriptBodies) {
          if (scriptBody == null ||
              (scriptBody.length < 2000 && !scriptBody.contains('client_id'))) {
            continue;
          }
          final re2 = RegExp(r',client_id:\s*"([a-zA-Z0-9_.-]{20,})"');
          var m2 = re2.firstMatch(scriptBody);
          m2 ??= RegExp(r'client_id:\s*"([a-zA-Z0-9_.-]{20,})"').firstMatch(scriptBody);
          m2 ??= RegExp(r'client_id=([a-zA-Z0-9_.-]{20,})').firstMatch(scriptBody);
          m2 ??= RegExp(r'client_id:\s*"([^"]{20,})"').firstMatch(scriptBody);
          if (m2 != null) {
            final cid = m2.group(1)!;
            if (cid.length >= 20) {
              if (kDebugMode) _log('playback: [embed] client_id found in script');
              return cid;
            }
          }
        }
        if (kDebugMode) _log('playback: [embed] no client_id in ${uniqueUrls.length} script(s)');
      } catch (e, st) {
        if (kDebugMode) _log('playback: [embed] tryPage error: $e\n$st');
      }
      return null;
    }

    try {
      if (kDebugMode) _log('playback: [embed] _getEmbeddedClientId: trying soundcloud.com');
      String? cid = await tryPage('https://soundcloud.com', logBody: true);
      if (cid == null && kDebugMode) _log('playback: [embed] soundcloud.com: no client_id, trying discover');
      cid ??= await tryPage('https://soundcloud.com/discover');
      if (cid == null && kDebugMode) _log('playback: [embed] discover: no client_id, trying track page');
      cid ??= await tryPage('https://soundcloud.com/mt-marcy/cold-nights');
      if (cid != null && cid.length >= 20) {
        _embeddedClientId = cid;
        _embeddedClientIdFetched = DateTime.now();
        _log('playback: [embed] embedded client_id obtained (${cid.length} chars)');
        return _embeddedClientId;
      }
      if (cid != null && cid.isNotEmpty && kDebugMode) {
        _log('playback: [embed] rejected client_id (${cid.length} chars, need >=20)', isError: true);
      }
      _log('playback: embedded client_id not found in any page', isError: true);
    } catch (e) {
      _log('getEmbeddedClientId failed: $e', isError: true);
    }
    return null;
  }

  /// Run OAuth resolve and embedded client_id resolve in parallel; return first success.
  Future<String?> _resolveStreamWithRace(
    List<String> apiUrls,
    String trackId,
  ) async {
    final completer = Completer<String?>();
    var oauthDone = false;
    var embeddedDone = false;

    void tryComplete(String? url) {
      if (url != null && url.isNotEmpty && !completer.isCompleted) {
        completer.complete(url);
      }
    }

    void maybeCompleteNull() {
      if (oauthDone && embeddedDone && !completer.isCompleted) {
        completer.complete(null);
      }
    }

    Future<void> oauthPath() async {
      for (final apiUrl in apiUrls) {
        if (completer.isCompleted) return;
        final cdn = await _resolveTranscodingUrlToCdn(apiUrl);
        if (cdn != null && cdn.isNotEmpty) {
          tryComplete(cdn);
          return;
        }
      }
      oauthDone = true;
      maybeCompleteNull();
    }

    Future<void> embeddedPath() async {
      if (completer.isCompleted) return;
      final url = await _resolveStreamViaEmbeddedClientId(trackId);
      tryComplete(url);
      embeddedDone = true;
      maybeCompleteNull();
    }

    unawaited(oauthPath());
    unawaited(embeddedPath());

    return completer.future;
  }

  /// Resolve stream via api-v2 with embedded client_id (bypasses official API 401).
  Future<String?> _resolveStreamViaEmbeddedClientId(String trackId) async {
    _log('playback: trying embedded client_id fallback');
    final clientId = await _getEmbeddedClientId();
    if (clientId == null) return null;
    try {
      _log('playback: trying api-v2 with embedded client_id');
      final trackUrl = '$_apiV2Base/tracks/$trackId?client_id=$clientId';
      final trackRes = await http.get(Uri.parse(trackUrl));
      if (trackRes.statusCode != 200) {
        _log('playback: api-v2 track status ${trackRes.statusCode}', isError: true);
        return null;
      }
      final trackData = jsonDecode(trackRes.body) as Map<String, dynamic>?;
      if (trackData == null) return null;
      final media = trackData['media'] as Map<String, dynamic>?;
      final transcodings = media?['transcodings'] as List<dynamic>?;
      if (transcodings == null || transcodings.isEmpty) return null;
      String? transcodingUrl;
      for (final t in transcodings) {
        if (t is! Map<String, dynamic>) continue;
        final format = t['format'] as Map<String, dynamic>?;
        if (format?['protocol'] == 'progressive') {
          transcodingUrl = t['url'] as String?;
          break;
        }
      }
      transcodingUrl ??= (transcodings.first as Map<String, dynamic>)['url'] as String?;
      if (transcodingUrl == null || transcodingUrl.isEmpty) return null;
      if (transcodingUrl.startsWith('/')) transcodingUrl = '$_apiV2Base$transcodingUrl';
      final resolveUrl = transcodingUrl.contains('?')
          ? '$transcodingUrl&client_id=$clientId'
          : '$transcodingUrl?client_id=$clientId';
      final resolveRes = await http.get(Uri.parse(resolveUrl));
      if (resolveRes.statusCode != 200) {
        _log('playback: api-v2 resolve status ${resolveRes.statusCode}', isError: true);
        return null;
      }
      final resolveData = jsonDecode(resolveRes.body) as Map<String, dynamic>?;
      final url = resolveData?['url'] as String?;
      if (url != null && url.isNotEmpty && _isUsableStreamUrl(url)) {
        _log('playback: resolved via api-v2 + embedded client_id');
        return url;
      }
    } catch (e) {
      _log('playback: api-v2 embedded resolve failed: $e', isError: true);
    }
    return null;
  }

  /// Resolve transcoding URL to final CDN stream URL.
  /// Per SoundCloud issue #478: use OAuth token, follow 302 redirect to get CDN URL for player.
  /// SoundCloud API requires `Authorization: OAuth <token>`, not Bearer (see developers.soundcloud.com).
  Future<String?> _resolveTranscodingUrlToCdn(String transcodingUrl) async {
    if (_accessToken == null) return null;
    _log('playback: resolve request ${_redactUrl(transcodingUrl)}');
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        followRedirects: true,
        headers: {
          'Authorization': 'OAuth $_accessToken',
          'Accept': '*/*',
        },
      ));
      final response = await dio.get<dynamic>(
        transcodingUrl,
        options: Options(
          validateStatus: (s) => s != null && s < 500,
          followRedirects: true,
        ),
      );
      final finalUri = response.realUri.toString();
      if (_isUsableStreamUrl(finalUri)) {
        _log('playback: resolved to CDN via OAuth (redirect)');
        return finalUri;
      }
      if (response.statusCode == 302 || response.statusCode == 301) {
        final location = response.headers.value('location');
        if (location != null && _isUsableStreamUrl(location)) {
          _log('playback: resolved to CDN via Location header');
          return location;
        }
      }
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final url = (response.data as Map<String, dynamic>)['url'] as String?;
        if (url != null && _isUsableStreamUrl(url)) {
          _log('playback: resolved to CDN via JSON url');
          return url;
        }
      }
      if (response.statusCode == 401) {
        _log('playback: resolve 401 with OAuth');
      }
      return null;
    } catch (e) {
      _log('resolveTranscodingUrlToCdn failed: $e', isError: true);
      return null;
    }
  }

  @override
  Future<List<String>> getAlternativeStreamUrlsAsync(String trackId) async {
    if (!await _ensureToken()) {
      _log('playback: no token', isError: true);
      return [];
    }
    final numericId = _normalizeTrackId(trackId);
    if (numericId.isEmpty) {
      _log('playback: empty trackId after normalize', isError: true);
      return [];
    }
    _log('playback: resolving stream for trackId=$trackId numericId=$numericId');
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/tracks/$numericId',
        queryParameters: {'access': 'playable'},
      );
      final data = response.data;
      if (data != null) {
        final keys = data.keys.toList();
        _log('playback: /tracks response keys: $keys');
        final streamUrlVal = data['stream_url'] as String?;
        if (streamUrlVal != null && streamUrlVal.isNotEmpty) {
          _log('playback: /tracks stream_url prefix: ${streamUrlVal.length > 80 ? streamUrlVal.substring(0, 80) : streamUrlVal}');
        }
        var urls = _collectStreamUrlsFromMap(data);
        urls = _addUrlsFromTranscodings(data, urls);
        if (urls.isNotEmpty) {
          _log('playback: got ${urls.length} CDN URL(s) from /tracks');
          return urls;
        }
        final apiUrls = <String>[];
        if (data['stream_url'] != null) {
          final raw = data['stream_url'] as String;
          if (!raw.toLowerCase().contains('/preview')) {
            final u = _urlWithClientId(raw) ?? raw;
            if (u.isNotEmpty && u.toLowerCase().contains('api.soundcloud.com')) apiUrls.add(u);
          }
        }
        for (final k in ['http_mp3_128_url', 'hls_mp3_128_url', 'hls_aac_160_url', 'hls_aac_96_url']) {
          if (data[k] != null) {
            final u = _urlWithClientId(data[k] as String) ?? data[k] as String;
            if (u.isNotEmpty && u.toLowerCase().contains('api.soundcloud.com') && !apiUrls.contains(u)) apiUrls.add(u);
          }
        }
        final transcodings = data['transcodings'] as List<dynamic>?;
        if (transcodings != null) {
          for (final t in transcodings) {
            if (t is! Map<String, dynamic>) continue;
            final url = t['url'] as String?;
            if (url == null || url.isEmpty) continue;
            final u = _urlWithClientId(url) ?? url;
            if (u.toLowerCase().contains('api.soundcloud.com') && !apiUrls.contains(u)) apiUrls.add(u);
          }
        }
        _addApiUrlsFromMediaTranscodings(data, apiUrls);
        _log('playback: api URLs to resolve: ${apiUrls.length} (OAuth + embedded in parallel)');
        final cdn = await _resolveStreamWithRace(apiUrls, numericId);
        if (cdn != null && cdn.isNotEmpty) {
          _log('playback: resolved API URL to CDN');
          return [cdn];
        }
      }
      for (final id in [numericId, if (trackId != numericId) trackId]) {
        try {
          _log('playback: trying /tracks/$id/streams');
          final streamsResponse = await _dio.get<Map<String, dynamic>>(
            '/tracks/$id/streams',
          );
          final streamsData = streamsResponse.data;
          if (streamsData != null) {
            final sk = streamsData.keys.toList();
            _log('playback: /streams response keys: $sk');
            final sampleKey = sk.isNotEmpty ? sk.first : null;
            if (sampleKey != null) {
              final sampleVal = streamsData[sampleKey];
              if (sampleVal is String && sampleVal.isNotEmpty) {
                _log('playback: /streams $sampleKey prefix: ${sampleVal.length > 80 ? sampleVal.substring(0, 80) : sampleVal}');
              }
            }
            var surls = _collectStreamUrlsFromMap(streamsData);
            surls = _addUrlsFromTranscodings(streamsData, surls);
            if (surls.isNotEmpty) {
              _log('playback: got ${surls.length} CDN URL(s) from /streams');
              return surls;
            }
            final apiUrls = <String>[];
            for (final k in ['stream_url', 'http_mp3_128_url', 'hls_mp3_128_url', 'hls_aac_160_url', 'hls_aac_96_url']) {
              if (streamsData[k] != null) {
                final raw = streamsData[k] as String;
                if (raw.toLowerCase().contains('/preview')) continue;
                final u = _urlWithClientId(raw) ?? raw;
                if (u.isNotEmpty && u.toLowerCase().contains('api.soundcloud.com') && !apiUrls.contains(u)) apiUrls.add(u);
              }
            }
            final st = streamsData['transcodings'] as List<dynamic>?;
            if (st != null) {
              for (final t in st) {
                if (t is! Map<String, dynamic>) continue;
                final url = t['url'] as String?;
                if (url == null || url.isEmpty) continue;
                final u = _urlWithClientId(url) ?? url;
                if (u.toLowerCase().contains('api.soundcloud.com') && !apiUrls.contains(u)) apiUrls.add(u);
              }
            }
            _addApiUrlsFromMediaTranscodings(streamsData, apiUrls);
            _log('playback: /streams api URLs to resolve: ${apiUrls.length} (OAuth + embedded in parallel)');
            final cdn = await _resolveStreamWithRace(apiUrls, id);
            if (cdn != null && cdn.isNotEmpty) {
              _log('playback: resolved /streams API URL to CDN');
              return [cdn];
            }
          }
        } catch (e) {
          _log('playback: /streams $id failed: $e', isError: true);
          continue;
        }
      }
      final embeddedUrl = await _resolveStreamViaEmbeddedClientId(numericId);
      if (embeddedUrl != null && embeddedUrl.isNotEmpty) return [embeddedUrl];
      _log('playback: no usable stream URL for track $numericId', isError: true);
      return [];
    } catch (e) {
      _log('getAlternativeStreamUrlsAsync failed: $e', isError: true);
      return [];
    }
  }

  @override
  String getImageUrl(
    String itemId, {
    String type = 'Primary',
    int? width,
    int? height,
  }) {
    if (itemId.isEmpty) return '';
    if (itemId.startsWith('http://') || itemId.startsWith('https://')) {
      return itemId;
    }
    return '';
  }

  @override
  Future<SearchResults> search(
    String query, {
    List<String>? includeItemTypes,
    int? limit,
  }) async {
    if (!await _ensureToken()) return SearchResults();

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/tracks',
        queryParameters: {
          'q': query.isEmpty ? 'music' : query,
          'access': 'playable',
          'limit': (limit ?? 50).clamp(1, 200),
          'linked_partitioning': 'true',
        },
      );

      final data = response.data;
      if (data == null) return SearchResults();

      final collection = data['collection'] as List<dynamic>? ?? [];
      final tracks = <Track>[];
      final seenArtists = <String>{};
      final artists = <Artist>[];

      for (final item in collection) {
        final map = item as Map<String, dynamic>;
        final id = map['id']?.toString();
        if (id == null) continue;

        final user = map['user'] as Map<String, dynamic>?;
        final artistName = user?['username'] as String? ?? 'Unknown Artist';
        final userId = user?['id']?.toString();
        final durationMs = map['duration'] != null
            ? (map['duration'] as num).toInt()
            : null;
        final artwork = map['artwork_url'] as String?;

        if (userId != null && !seenArtists.contains(userId)) {
          seenArtists.add(userId);
          artists.add(Artist(
            id: userId,
            name: artistName,
            imageUrl: user?['avatar_url'] as String?,
          ));
        }

        tracks.add(Track(
          id: id,
          name: map['title'] as String? ?? 'Unknown',
          artistName: artistName,
          albumName: null,
          duration: durationMs,
          imageUrl: artwork,
          isFavorite: false,
        ));
      }

      return SearchResults(artists: artists, tracks: tracks);
    } catch (_) {
      return SearchResults();
    }
  }

  @override
  Future<ServerInfo> getServerInfo() async {
    return ServerInfo(
      name: 'SoundCloud',
      version: '1',
      id: 'soundcloud',
      type: ServerType.soundcloud,
    );
  }

  @override
  Future<bool> toggleFavorite(String itemId, bool isFavorite) async {
    await _loadLocalData();
    final numericId = _normalizeTrackId(itemId);
    if (isFavorite) {
      _localFavorites.removeWhere((j) => (j['id'] ?? '').toString() == numericId || (j['id'] ?? '').toString() == itemId);
      await _saveLocalFavorites();
      return true;
    }
    // Adding to favorites: fetch track from API to store full snapshot; fallback to minimal entry on API failure
    if (!await _ensureToken()) return false;
    try {
      final response = await _dio.get<Map<String, dynamic>>('/tracks/$numericId');
      final data = response.data;
      if (data == null) return false;
      final user = data['user'] as Map<String, dynamic>?;
      final artistName = user?['username'] as String? ?? 'Unknown Artist';
      final track = Track(
        id: data['id']?.toString() ?? numericId,
        name: data['title'] as String? ?? 'Unknown',
        artistName: artistName,
        albumName: null,
        duration: (data['duration'] as num?)?.toInt(),
        imageUrl: data['artwork_url'] as String?,
        isFavorite: true,
      );
      if (_localFavorites.any((j) => (j['id'] ?? '').toString() == track.id)) return true;
      _localFavorites.add(_trackToStoredJson(track));
      await _saveLocalFavorites();
      return true;
    } catch (e) {
      if (kDebugMode) _log('toggleFavorite fetch track failed: $e, saving minimal favorite locally', isError: true);
      // Fallback: save minimal favorite locally so the favorite persists even when API fails
      if (_localFavorites.any((j) => (j['id'] ?? '').toString() == numericId)) return true;
      _localFavorites.add({
        'id': numericId,
        'name': 'Unknown',
        'artistName': 'Unknown Artist',
        'albumName': null,
        'albumId': null,
        'duration': null,
        'imageUrl': null,
        'isFavorite': true,
      });
      await _saveLocalFavorites();
      return true;
    }
  }

  /// Local playlist CRUD (used by media_service_manager for SoundCloud)
  Future<Playlist?> createPlaylist(String name) async {
    await _loadLocalData();
    final id = 'sc_local_${DateTime.now().millisecondsSinceEpoch}_${name.hashCode.abs()}';
    final playlist = Playlist(id: id, name: name, trackCount: 0);
    _localPlaylists.add(playlist);
    _localPlaylistTracks[id] = [];
    await _saveLocalPlaylists();
    return playlist;
  }

  Future<bool> addToPlaylist(String playlistId, String trackId) async {
    await _loadLocalData();
    if (!_localPlaylists.any((p) => p.id == playlistId)) return false;
    final numericId = _normalizeTrackId(trackId);
    final list = _localPlaylistTracks[playlistId] ?? [];
    if (list.any((j) => (j['id'] ?? '').toString() == numericId)) return true;
    if (!await _ensureToken()) return false;
    try {
      final response = await _dio.get<Map<String, dynamic>>('/tracks/$numericId');
      final data = response.data;
      if (data == null) return false;
      final user = data['user'] as Map<String, dynamic>?;
      final track = Track(
        id: data['id']?.toString() ?? numericId,
        name: data['title'] as String? ?? 'Unknown',
        artistName: user?['username'] as String? ?? 'Unknown Artist',
        albumName: null,
        albumId: playlistId,
        duration: (data['duration'] as num?)?.toInt(),
        imageUrl: data['artwork_url'] as String?,
        isFavorite: false,
      );
      list.add(_trackToStoredJson(track));
      _localPlaylistTracks[playlistId] = list;
      final idx = _localPlaylists.indexWhere((p) => p.id == playlistId);
      if (idx >= 0) {
        final p = _localPlaylists[idx];
        _localPlaylists[idx] = Playlist(
          id: p.id,
          name: p.name,
          imageUrl: p.imageUrl ?? track.imageUrl,
          trackCount: list.length,
        );
      }
      await _saveLocalPlaylists();
      return true;
    } catch (e) {
      if (kDebugMode) _log('addToPlaylist fetch track failed: $e', isError: true);
      return false;
    }
  }

  Future<bool> removeTrackFromPlaylist(String playlistId, String trackId) async {
    await _loadLocalData();
    final list = _localPlaylistTracks[playlistId];
    if (list == null) return false;
    final numericId = _normalizeTrackId(trackId);
    final before = list.length;
    list.removeWhere((j) => (j['id'] ?? '').toString() == numericId || (j['id'] ?? '').toString() == trackId);
    if (list.length == before) return false;
    final idx = _localPlaylists.indexWhere((p) => p.id == playlistId);
    if (idx >= 0) {
      final p = _localPlaylists[idx];
      _localPlaylists[idx] = Playlist(
        id: p.id,
        name: p.name,
        imageUrl: list.isNotEmpty ? (list.first['imageUrl'] ?? p.imageUrl) : null,
        trackCount: list.length,
      );
    }
    await _saveLocalPlaylists();
    return true;
  }

  Future<bool> renamePlaylist(String playlistId, String newName) async {
    await _loadLocalData();
    final idx = _localPlaylists.indexWhere((p) => p.id == playlistId);
    if (idx < 0) return false;
    final p = _localPlaylists[idx];
    _localPlaylists[idx] = Playlist(id: p.id, name: newName, imageUrl: p.imageUrl, trackCount: p.trackCount);
    await _saveLocalPlaylists();
    return true;
  }

  Future<bool> removePlaylist(String playlistId) async {
    await _loadLocalData();
    final idx = _localPlaylists.indexWhere((p) => p.id == playlistId);
    if (idx < 0) return false;
    _localPlaylists.removeAt(idx);
    _localPlaylistTracks.remove(playlistId);
    await _saveLocalPlaylists();
    return true;
  }
}
