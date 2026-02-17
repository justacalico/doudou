import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kib_debug_print/kib_debug_print.dart';

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

  /// Redirect URI must be set in your SoundCloud app at developers.soundcloud.com.
  /// Use this exact value in the app's "Redirect URI" field and click Save.
  static const String _redirectUri = 'http://localhost/callback';

  Future<bool> _obtainToken() async {
    _lastError = null;
    final credentials = base64Encode(utf8.encode('$_clientId:$_clientSecret'));
    // Try legacy endpoint first (oauth2/token returns 404 on SoundCloud)
    _log('trying oauth/token');
    final ok = await _requestToken(
      'https://secure.soundcloud.com/oauth/token',
      credentials,
      {'grant_type': 'client_credentials'},
    );
    if (ok) return true;
    _log('oauth/token failed, trying oauth2/token with redirect_uri');
    _lastError = null;
    return _requestToken(
      'https://secure.soundcloud.com/oauth2/token',
      credentials,
      {'grant_type': 'client_credentials', 'redirect_uri': _redirectUri},
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

  /// Last error from token endpoint (e.g. invalid_client). Null if none.
  String? get lastAuthError => _lastError;

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
  }

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
  Future<List<Track>> getStarredTracks() async => [];

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
    if (!await _ensureToken()) return [];
    try {
      final results = await search('', limit: (limit ?? 50).clamp(1, 200));
      final seen = <String>{};
      final artists = <Artist>[];
      for (final t in results.tracks) {
        final name = t.artistName ?? 'Unknown Artist';
        final id = name.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
        if (seen.contains(id)) continue;
        seen.add(id);
        artists.add(Artist(id: id, name: name, imageUrl: null));
      }
      return artists;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Track>> getAllTracks({int? maxTracks}) async {
    return getTracks(limit: maxTracks ?? 500);
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
    if (!await _ensureToken()) return [];
    try {
      final response = await _dio.get<dynamic>(
        '/playlists',
        queryParameters: {
          'q': 'music',
          'representation': 'compact',
          'limit': 50,
          'linked_partitioning': 'true',
        },
      );
      final data = response.data;
      if (data == null) return [];
      final collection = data is List
          ? data
          : (data is Map && data['collection'] != null)
              ? data['collection'] as List<dynamic>
              : <dynamic>[];
      final playlists = <Playlist>[];
      for (final item in collection) {
        final map = item as Map<String, dynamic>;
        final id = map['id']?.toString();
        if (id == null) continue;
        final title = map['title'] as String? ?? 'Playlist';
        final trackCount = (map['track_count'] as num?)?.toInt() ??
            (map['tracks'] as List<dynamic>?)?.length ??
            0;
        final artwork = map['artwork_url'] as String?;
        playlists.add(Playlist(
          id: id,
          name: title,
          imageUrl: artwork,
          trackCount: trackCount,
        ));
      }
      return playlists;
    } catch (e) {
      _log('getPlaylists failed: $e', isError: true);
      return [];
    }
  }

  @override
  Future<List<Track>> getPlaylistTracks(String playlistId) async {
    if (!await _ensureToken()) return [];
    try {
      // Default representation returns full track objects
      final response = await _dio.get<Map<String, dynamic>>(
        '/playlists/$playlistId',
      );
      final data = response.data;
      if (data == null) return [];
      final trackList = data['tracks'] as List<dynamic>? ?? [];
      final tracks = <Track>[];
      for (final t in trackList) {
        if (t is! Map<String, dynamic>) continue;
        final id = t['id']?.toString();
        if (id == null) continue;
        final title = t['title'] as String? ?? 'Unknown';
        final user = t['user'] as Map<String, dynamic>?;
        final artistName = user?['username'] as String? ?? 'Unknown Artist';
        final durationMs = t['duration'] != null
            ? (t['duration'] as num).toInt()
            : null;
        final artwork = t['artwork_url'] as String?;
        tracks.add(Track(
          id: id,
          name: title,
          artistName: artistName,
          albumName: null,
          albumId: playlistId,
          duration: durationMs,
          imageUrl: artwork,
          isFavorite: false,
        ));
      }
      return tracks;
    } catch (e) {
      _log('getPlaylistTracks failed: $e', isError: true);
      return [];
    }
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
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    if (uri.queryParameters.containsKey('client_id')) return url;
    final sep = url.contains('?') ? '&' : '?';
    return '$url${sep}client_id=$_clientId';
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

  List<String> _collectStreamUrlsFromMap(Map<String, dynamic> data) {
    final urls = <String>[];
    // Progressive URLs first for best compatibility (e.g. media_kit/libmpv)
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

  @override
  Future<List<String>> getAlternativeStreamUrlsAsync(String trackId) async {
    if (!await _ensureToken()) return [];
    final numericId = _normalizeTrackId(trackId);
    if (numericId.isEmpty) return [];
    try {
      // GET track – response may include stream_url and/or transcoding URLs
      final response = await _dio.get<Map<String, dynamic>>(
        '/tracks/$numericId',
        queryParameters: {'access': 'playable'},
      );
      final data = response.data;
      if (data != null) {
        final urls = _collectStreamUrlsFromMap(data);
        if (urls.isNotEmpty) return urls;
      }
      // Fallback: dedicated streams endpoint (API: /tracks/{track_urn}/streams)
      for (final id in [numericId, if (trackId != numericId) trackId]) {
        try {
          final streamsResponse = await _dio.get<Map<String, dynamic>>(
            '/tracks/$id/streams',
          );
          final streamsData = streamsResponse.data;
          if (streamsData != null) {
            final urls = _collectStreamUrlsFromMap(streamsData);
            if (urls.isNotEmpty) return urls;
          }
        } catch (_) {
          continue;
        }
      }
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

      for (final item in collection) {
        final map = item as Map<String, dynamic>;
        final id = map['id']?.toString();
        if (id == null) continue;

        final user = map['user'] as Map<String, dynamic>?;
        final artistName = user?['username'] as String? ?? 'Unknown Artist';
        final durationMs = map['duration'] != null
            ? (map['duration'] as num).toInt()
            : null;
        final artwork = map['artwork_url'] as String?;

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

      return SearchResults(tracks: tracks);
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
    return false;
  }
}
