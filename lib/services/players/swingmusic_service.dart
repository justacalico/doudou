import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import '../../models/jellyfin_models.dart';
import '../base_service.dart';

class SwingMusicService implements BaseMediaService {
  late Dio _dio;
  String? _serverUrl;
  String? _username;
  String? _accessToken;
  String? _refreshToken;
  int? _userId;

  @override
  ServerType get serverType => ServerType.swingmusic;

  SwingMusicService() {
    _dio = Dio();

    // Configure timeouts
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.sendTimeout = const Duration(seconds: 30);

    // Platform-specific configurations
    if (!kIsWeb && Platform.isLinux) {
      (_dio.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate =
          (client) {
            client.badCertificateCallback = (cert, host, port) {
              return true;
            };
            return client;
          };
    }
  }

  @override
  Future<bool> authenticate(
    String serverUrl,
    String identifier,
    String credential,
  ) async {
    try {
      _serverUrl = serverUrl.endsWith('/')
          ? serverUrl.substring(0, serverUrl.length - 1)
          : serverUrl;
      _username = identifier;

      // Swing Music API endpoint - note: some Flask servers need trailing slash
      final loginUrl = '$_serverUrl/auth/login';

      // Swing Music uses JWT authentication
      // The API expects a JSON body with username and password
      // Disable redirect following to debug 405 issues
      final response = await _dio.post(
        loginUrl,
        data: {'username': identifier, 'password': credential},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      // Handle redirect - Flask may redirect to URL with trailing slash
      if (response.statusCode == 307 || response.statusCode == 308) {
        final redirectUrl = response.headers['location']?.first;
        if (redirectUrl != null) {
          final redirectResponse = await _dio.post(
            redirectUrl.startsWith('http')
                ? redirectUrl
                : '$_serverUrl$redirectUrl',
            data: {'username': identifier, 'password': credential},
            options: Options(
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              validateStatus: (status) => status != null && status < 500,
            ),
          );

          if (redirectResponse.statusCode == 200 &&
              redirectResponse.data != null) {
            _accessToken = redirectResponse.data['accesstoken'];
            _refreshToken = redirectResponse.data['refreshtoken'];
            await _getUserInfo();
            return true;
          }
        }
        _accessToken = response.data['accesstoken'];
        _refreshToken = response.data['refreshtoken'];

        // Get user info
        await _getUserInfo();

        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _getUserInfo() async {
    try {
      final response = await _dio.get(
        '$_serverUrl/auth/user',
        options: _authOptions,
      );

      if (response.statusCode == 200 && response.data != null) {
        _userId = response.data['id'];
      }
    } catch (e) {
      // Error getting user info
    }
  }

  Options get _authOptions => Options(
    headers: {
      'Authorization': 'Bearer $_accessToken',
      'Content-Type': 'application/json',
    },
  );

  @override
  void setServer(String serverUrl) {
    _serverUrl = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;
  }

  @override
  Future<bool> validateCredentials() async {
    if (_serverUrl == null || _accessToken == null) {
      return false;
    }

    try {
      final response = await _dio.get(
        '$_serverUrl/auth/user',
        options: _authOptions,
      );

      if (response.statusCode == 200) {
        return true;
      }

      // Try to refresh token
      return await _refreshAccessToken();
    } catch (e) {
      // Try to refresh token on error
      return await _refreshAccessToken();
    }
  }

  Future<bool> _refreshAccessToken() async {
    if (_refreshToken == null) return false;

    try {
      final response = await _dio.post(
        '$_serverUrl/auth/refresh',
        options: Options(headers: {'Authorization': 'Bearer $_refreshToken'}),
      );

      if (response.statusCode == 200 && response.data != null) {
        _accessToken = response.data['accesstoken'];
        _refreshToken = response.data['refreshtoken'];
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<Library>> getLibraries() async {
    // Swing Music doesn't have a concept of libraries like Jellyfin
    // Return a single "All Music" library
    return [Library(id: 'all', name: 'All Music', collectionType: 'music')];
  }

  @override
  Future<List<Album>> getAlbums({
    String? libraryId,
    int? limit,
    int? startIndex,
  }) async {
    try {
      final response = await _dio.get(
        '$_serverUrl/getall/albums',
        queryParameters: {
          if (limit != null) 'limit': limit,
          if (startIndex != null) 'start': startIndex,
        },
        options: _authOptions,
      );

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> albumsData =
            response.data['items'] ?? response.data;
        return albumsData.map((album) => _parseAlbum(album)).toList();
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  Album _parseAlbum(Map<String, dynamic> json) {
    return Album(
      id: json['albumhash'] ?? json['id'] ?? '',
      name: json['title'] ?? json['name'] ?? '',
      artistName:
          json['albumartists'] is List && json['albumartists'].isNotEmpty
          ? json['albumartists'][0]['name']
          : (json['artist'] ?? 'Unknown Artist'),
      imageUrl: json['albumhash'] ?? json['image'],
      year: json['date'] != null
          ? int.tryParse(json['date'].toString().split('-').first)
          : null,
      isFavorite: json['is_favorite'] ?? false,
    );
  }

  @override
  Future<List<Artist>> getArtists({
    String? libraryId,
    int? limit,
    int? startIndex,
  }) async {
    try {
      final response = await _dio.get(
        '$_serverUrl/getall/artists',
        queryParameters: {
          if (limit != null) 'limit': limit,
          if (startIndex != null) 'start': startIndex,
        },
        options: _authOptions,
      );

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> artistsData =
            response.data['items'] ?? response.data;
        return artistsData.map((artist) => _parseArtist(artist)).toList();
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  Artist _parseArtist(Map<String, dynamic> json) {
    return Artist(
      id: json['artisthash'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      imageUrl: json['artisthash'] ?? json['image'],
    );
  }

  @override
  Future<List<Track>> getTracks({
    String? libraryId,
    String? parentId,
    int? limit,
    int? startIndex,
  }) async {
    try {
      String endpoint;
      Map<String, dynamic> queryParams = {};

      if (parentId != null) {
        // Get tracks for a specific album
        final response = await _dio.post(
          '$_serverUrl/album',
          data: {'albumhash': parentId},
          options: _authOptions,
        );

        if (response.statusCode == 200 && response.data != null) {
          final List<dynamic> tracksData = response.data['tracks'] ?? [];
          return tracksData.map((track) => _parseTrack(track)).toList();
        }
        return [];
      } else {
        // Get all tracks
        endpoint = '$_serverUrl/getall/tracks';
        if (limit != null) queryParams['limit'] = limit;
        if (startIndex != null) queryParams['start'] = startIndex;
      }

      final response = await _dio.get(
        endpoint,
        queryParameters: queryParams,
        options: _authOptions,
      );

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> tracksData =
            response.data['items'] ?? response.data;
        return tracksData.map((track) => _parseTrack(track)).toList();
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  Track _parseTrack(Map<String, dynamic> json) {
    // Duration is in seconds, convert to milliseconds
    final durationSeconds = json['duration'] as int? ?? 0;

    return Track(
      id: json['trackhash'] ?? json['id'] ?? '',
      name: json['title'] ?? json['name'] ?? '',
      albumName: json['album'] ?? json['albumtitle'],
      artistName: json['artists'] is List && json['artists'].isNotEmpty
          ? (json['artists'] as List)
                .map((a) => a is Map ? a['name'] : a.toString())
                .join(', ')
          : (json['artist'] ?? 'Unknown Artist'),
      albumId: json['albumhash'],
      duration: durationSeconds * 1000, // Convert to milliseconds
      trackNumber: json['track'] ?? json['trackno'],
      imageUrl: json['albumhash'] ?? json['image'],
      isFavorite: json['is_favorite'] ?? false,
    );
  }

  @override
  Future<List<Playlist>> getPlaylists() async {
    try {
      final response = await _dio.get(
        '$_serverUrl/playlist/all',
        options: _authOptions,
      );

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> playlistsData =
            response.data['items'] ?? response.data;
        return playlistsData
            .map((playlist) => _parsePlaylist(playlist))
            .toList();
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  Playlist _parsePlaylist(Map<String, dynamic> json) {
    return Playlist(
      id: json['id']?.toString() ?? json['playlistid']?.toString() ?? '',
      name: json['name'] ?? '',
      imageUrl: json['image'],
      trackCount: json['trackcount'] ?? json['count'] ?? 0,
    );
  }

  @override
  Future<List<Track>> getPlaylistTracks(String playlistId) async {
    try {
      final response = await _dio.get(
        '$_serverUrl/playlist/$playlistId',
        options: _authOptions,
      );

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> tracksData = response.data['tracks'] ?? [];
        return tracksData.map((track) => _parseTrack(track)).toList();
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Create a new playlist
  Future<Playlist?> createPlaylist(String name) async {
    try {
      final response = await _dio.post(
        '$_serverUrl/playlist/new',
        data: {'name': name},
        options: _authOptions,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data != null) {
          return _parsePlaylist(response.data);
        }
        // If no data returned, create a minimal playlist object
        return Playlist(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          imageUrl: null,
          trackCount: 0,
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Add a track to a playlist
  Future<bool> addToPlaylist(String playlistId, String trackId) async {
    try {
      final response = await _dio.post(
        '$_serverUrl/playlist/$playlistId/add',
        data: {'trackhash': trackId},
        options: _authOptions,
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  /// Rename a playlist
  Future<bool> renamePlaylist(String playlistId, String newName) async {
    try {
      final response = await _dio.put(
        '$_serverUrl/playlist/$playlistId',
        data: {'name': newName},
        options: _authOptions,
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Remove/delete a playlist
  Future<bool> removePlaylist(String playlistId) async {
    try {
      final response = await _dio.delete(
        '$_serverUrl/playlist/$playlistId',
        options: _authOptions,
      );

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  @override
  String getStreamUrl(String trackId, {int? bitrate}) {
    if (_serverUrl == null) return '';

    // Swing Music streams via /file/<trackhash>/legacy endpoint
    String url = '$_serverUrl/file/$trackId/legacy?filepath=';

    if (bitrate != null && bitrate < 320) {
      url += '&quality=$bitrate&container=mp3';
    }

    return url;
  }

  @override
  List<String> getAlternativeStreamUrls(String trackId) {
    if (_serverUrl == null) return [];
    return [getStreamUrl(trackId)];
  }

  @override
  Future<List<String>> getAlternativeStreamUrlsAsync(String trackId) async {
    return getAlternativeStreamUrls(trackId);
  }

  @override
  String getImageUrl(
    String itemId, {
    String type = 'Primary',
    int? width,
    int? height,
  }) {
    if (_serverUrl == null || itemId.isEmpty) return '';

    // Swing Music serves images via /img endpoint
    // The itemId is usually an albumhash or artisthash
    String url = '$_serverUrl/img/thumbnail/$itemId';

    if (width != null || height != null) {
      final size = width ?? height ?? 300;
      url = '$_serverUrl/img/thumbnail/$itemId?size=$size';
    }

    return url;
  }

  @override
  Future<SearchResults> search(
    String query, {
    List<String>? includeItemTypes,
    int? limit,
  }) async {
    try {
      // Get top search results
      final response = await _dio.get(
        '$_serverUrl/search/top',
        queryParameters: {'q': query, if (limit != null) 'limit': limit},
        options: _authOptions,
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;

        List<Album> albums = [];
        List<Artist> artists = [];
        List<Track> tracks = [];

        if (data['albums'] != null) {
          albums = (data['albums'] as List).map((a) => _parseAlbum(a)).toList();
        }

        if (data['artists'] != null) {
          artists = (data['artists'] as List)
              .map((a) => _parseArtist(a))
              .toList();
        }

        if (data['tracks'] != null) {
          tracks = (data['tracks'] as List).map((t) => _parseTrack(t)).toList();
        }

        return SearchResults(
          albums: albums,
          artists: artists,
          tracks: tracks,
          playlists: [],
        );
      }

      return SearchResults();
    } catch (e) {
      return SearchResults();
    }
  }

  @override
  Future<ServerInfo> getServerInfo() async {
    return ServerInfo(
      name: 'Swing Music',
      version: '2.1.0', // Will be updated when we can fetch from server
      id: 'swingmusic',
      type: ServerType.swingmusic,
    );
  }

  @override
  dynamic get currentServer => SwingMusicServer(
    serverUrl: _serverUrl ?? '',
    username: _username,
    userId: _userId,
    accessToken: _accessToken,
    refreshToken: _refreshToken,
  );

  @override
  Future<bool> toggleFavorite(String itemId, bool isFavorite) async {
    try {
      final endpoint = isFavorite
          ? '$_serverUrl/favorites/remove'
          : '$_serverUrl/favorites/add';

      final response = await _dio.post(
        endpoint,
        data: {'trackhash': itemId},
        options: _authOptions,
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  @override
  void clearAuth() {
    _serverUrl = null;
    _username = null;
    _accessToken = null;
    _refreshToken = null;
    _userId = null;
  }

  // Additional methods specific to Swing Music

  /// Get favorite tracks
  Future<List<Track>> getFavorites() async {
    try {
      final response = await _dio.get(
        '$_serverUrl/favorites/tracks',
        options: _authOptions,
      );

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> tracksData =
            response.data['tracks'] ?? response.data;
        return tracksData.map((track) => _parseTrack(track)).toList();
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get recently played tracks
  Future<List<Track>> getRecentlyPlayed({int limit = 20}) async {
    try {
      final response = await _dio.get(
        '$_serverUrl/home',
        options: _authOptions,
      );

      if (response.statusCode == 200 && response.data != null) {
        final recentlyPlayed = response.data['recently_played'];
        if (recentlyPlayed != null && recentlyPlayed['tracks'] != null) {
          final List<dynamic> tracksData = recentlyPlayed['tracks'];
          return tracksData
              .take(limit)
              .map((track) => _parseTrack(track))
              .toList();
        }
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get artist details with albums and tracks
  Future<Map<String, dynamic>?> getArtistDetails(String artistHash) async {
    try {
      final response = await _dio.get(
        '$_serverUrl/artist/$artistHash',
        options: _authOptions,
      );

      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Getters for credentials (useful for saving/restoring state)
  String? get serverUrl => _serverUrl;
  String? get username => _username;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  int? get userId => _userId;

  // Setters for restoring state
  void restoreCredentials({
    required String serverUrl,
    required String username,
    required String accessToken,
    required String refreshToken,
    int? userId,
  }) {
    _serverUrl = serverUrl;
    _username = username;
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _userId = userId;
  }

  @override
  Future<List<Track>> getAllTracks({int? maxTracks}) async {
    // SwingMusic doesn't have great pagination, use getTracks with high limit
    return getTracks(limit: maxTracks ?? 50000);
  }

  @override
  Future<List<Track>> getStarredTracks() async {
    // SwingMusic favorites - not implemented yet
    return [];
  }

  @override
  Future<List<Album>> getStarredAlbums() async {
    return [];
  }

  @override
  Future<List<Artist>> getStarredArtists() async {
    return [];
  }
}

/// Represents a Swing Music server configuration
class SwingMusicServer {
  final String serverUrl;
  final String? username;
  final int? userId;
  final String? accessToken;
  final String? refreshToken;

  SwingMusicServer({
    required this.serverUrl,
    this.username,
    this.userId,
    this.accessToken,
    this.refreshToken,
  });

  Map<String, dynamic> toJson() => {
    'serverUrl': serverUrl,
    'username': username,
    'userId': userId,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'type': 'swingmusic',
  };

  factory SwingMusicServer.fromJson(Map<String, dynamic> json) {
    return SwingMusicServer(
      serverUrl: json['serverUrl'] ?? '',
      username: json['username'],
      userId: json['userId'],
      accessToken: json['accessToken'],
      refreshToken: json['refreshToken'],
    );
  }
}
