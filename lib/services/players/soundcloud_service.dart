import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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

  static const String _apiV2Base = 'https://api-v2.soundcloud.com';
  String? _embeddedClientId;
  DateTime? _embeddedClientIdFetched;
  static const Duration _embeddedClientIdCache = Duration(hours: 1);

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
    Future<String?> tryPage(String url) async {
      try {
        final res = await http.get(Uri.parse(url), headers: headers);
        if (res.statusCode != 200) return null;
        final body = res.body;
        if (kDebugMode && body.isNotEmpty) {
          final snippet = body.length > 500 ? body.substring(0, 500) : body;
          _log('playback: page body (first ${snippet.length} chars): $snippet');
        }
        RegExp re = RegExp(r',client_id:\s*"([^"]+)"');
        var match = re.firstMatch(body);
        if (match == null) match = RegExp(r'client_id:\s*"([a-zA-Z0-9_.-]+)"').firstMatch(body);
        if (match == null) match = RegExp(r"client_id:\s*'([a-zA-Z0-9_.-]+)'").firstMatch(body);
        if (match == null) match = RegExp(r'client_id=([a-zA-Z0-9_.-]+)').firstMatch(body);
        if (match != null) return match.group(1);
        re = RegExp(r'https://[a-z0-9.-]+\.sndcdn\.com/assets/[^"]+\.js');
        match = re.firstMatch(body);
        if (match != null) {
          final scriptRes = await http.get(Uri.parse(match.group(0)!), headers: headers);
          if (scriptRes.statusCode == 200) {
            final re2 = RegExp(r',client_id:\s*"([^"]+)"');
            var m2 = re2.firstMatch(scriptRes.body);
            if (m2 == null) m2 = RegExp(r'client_id:\s*"([a-zA-Z0-9_.-]+)"').firstMatch(scriptRes.body);
            if (m2 == null) m2 = RegExp(r'client_id=([a-zA-Z0-9_.-]+)').firstMatch(scriptRes.body);
            if (m2 != null) return m2.group(1);
          }
        }
      } catch (_) {}
      return null;
    }

    try {
      String? cid = await tryPage('https://soundcloud.com');
      if (cid == null) cid = await tryPage('https://soundcloud.com/discover');
      if (cid == null) cid = await tryPage('https://soundcloud.com/mt-marcy/cold-nights');
      if (cid != null && cid.isNotEmpty) {
        _embeddedClientId = cid;
        _embeddedClientIdFetched = DateTime.now();
        _log('playback: embedded client_id obtained');
        return _embeddedClientId;
      }
      _log('playback: embedded client_id not found in any page', isError: true);
    } catch (e) {
      _log('getEmbeddedClientId failed: $e', isError: true);
    }
    return null;
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
  /// Per SoundCloud issue #478: use Bearer token, follow 302 redirect to get CDN URL for player.
  Future<String?> _resolveTranscodingUrlToCdn(String transcodingUrl) async {
    if (_accessToken == null) return null;
    _log('playback: resolve request ${_redactUrl(transcodingUrl)}');
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        followRedirects: true,
        headers: {
          'Authorization': 'Bearer $_accessToken',
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
        _log('playback: resolved to CDN via Bearer (redirect)');
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
        _log('playback: resolve 401 with Bearer');
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
        _log('playback: api URLs to resolve: ${apiUrls.length}');
        for (final apiUrl in apiUrls) {
          final cdn = await _resolveTranscodingUrlToCdn(apiUrl);
          if (cdn != null && cdn.isNotEmpty) {
            _log('playback: resolved API URL to CDN');
            return [cdn];
          }
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
            _log('playback: /streams api URLs to resolve: ${apiUrls.length}');
            for (final apiUrl in apiUrls) {
              final cdn = await _resolveTranscodingUrlToCdn(apiUrl);
              if (cdn != null && cdn.isNotEmpty) {
                _log('playback: resolved /streams API URL to CDN');
                return [cdn];
              }
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
