import 'dart:convert';

import 'package:dio/dio.dart';
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
      kprint.err('[SoundCloud] login: missing Client ID or Client Secret');
      return false;
    }
    kprint.lg('[SoundCloud] login: obtaining token (client_id=${_clientId!.length} chars)', symbol: '🌐');
    return _obtainToken();
  }

  /// Redirect URI must be set in your SoundCloud app at developers.soundcloud.com.
  /// Use this exact value in the app's "Redirect URI" field and click Save.
  static const String _redirectUri = 'http://localhost/callback';

  Future<bool> _obtainToken() async {
    _lastError = null;
    final credentials = base64Encode(utf8.encode('$_clientId:$_clientSecret'));
    kprint.lg('[SoundCloud] trying oauth2/token with redirect_uri=$_redirectUri', symbol: '🌐');
    final ok = await _requestToken(
      'https://secure.soundcloud.com/oauth2/token',
      credentials,
      {'grant_type': 'client_credentials', 'redirect_uri': _redirectUri},
    );
    if (ok) return true;
    kprint.warn('[SoundCloud] oauth2/token failed, trying legacy oauth/token');
    _lastError = null;
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
      kprint.lg('[SoundCloud] POST $url', symbol: '🌐');
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
        kprint.err('[SoundCloud] token response has no body');
        return false;
      }

      _accessToken = response.data!['access_token'] as String?;
      final expiresIn = response.data!['expires_in'] as int? ?? 3600;
      _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

      if (_accessToken == null || _accessToken!.isEmpty) {
        kprint.err('[SoundCloud] token response missing access_token');
        return false;
      }

      _dio.options.headers['Authorization'] = 'OAuth $_accessToken';
      kprint.lg('[SoundCloud] token obtained, expires_in=${expiresIn}s', symbol: '✅');
      return true;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      if (data is Map && data['error'] != null) {
        _lastError = data['error'] as String?;
        final desc = data['error_description'] as String?;
        if (desc != null) _lastError = '$_lastError: $desc';
      }
      kprint.err('[SoundCloud] token request failed status=$status error=$_lastError body=${e.response?.data}');
      return false;
    } catch (e, st) {
      kprint.err('[SoundCloud] token request threw: $e');
      kprint.err('[SoundCloud] $st');
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
    return [];
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
    return [];
  }

  @override
  Future<List<Track>> getAllTracks({int? maxTracks}) async {
    return getTracks(limit: maxTracks ?? 10000);
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
    final results = await search('music', limit: limit ?? 50);
    return results.tracks;
  }

  @override
  Future<List<Playlist>> getPlaylists() async {
    return [];
  }

  @override
  Future<List<Track>> getPlaylistTracks(String playlistId) async {
    return [];
  }

  @override
  String getStreamUrl(String trackId, {int? bitrate}) {
    return '';
  }

  @override
  Future<List<String>> getAlternativeStreamUrlsAsync(String trackId) async {
    if (!await _ensureToken()) return [];
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/tracks/$trackId',
        queryParameters: {'access': 'playable'},
      );
      final data = response.data;
      if (data == null) return [];

      final urls = <String>[];
      if (data['stream_url'] != null && _clientId != null) {
        final streamUrl = data['stream_url'] as String;
        final uri = Uri.parse(streamUrl);
        final withClientId = uri.queryParameters.isEmpty
            ? '$streamUrl?client_id=$_clientId'
            : uri.replace(queryParameters: {...uri.queryParameters, 'client_id': _clientId!}).toString();
        urls.add(withClientId);
      }
      if (data['hls_aac_160_url'] != null) {
        urls.add(data['hls_aac_160_url'] as String);
      }
      if (data['preview_mp3_128_url'] != null) {
        urls.add(data['preview_mp3_128_url'] as String);
      }
      return urls;
    } catch (_) {
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
    return itemId;
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
