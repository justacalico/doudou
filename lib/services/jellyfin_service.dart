import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/jellyfin_models.dart';

class JellyfinService {
  late Dio _dio;
  JellyfinServer? _server;

  JellyfinService() {
    _dio = Dio();
    
    // Configure timeouts and retry options
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.sendTimeout = const Duration(seconds: 30);
    
    // Add retry interceptor for network resilience
    _dio.interceptors.add(RetryInterceptor(
      dio: _dio,
      retries: 2,
      retryDelays: const [
        Duration(seconds: 1),
        Duration(seconds: 3),
      ],
    ));
  }

  void setServer(JellyfinServer server) {
    _server = server;
    _dio.options.baseUrl = server.serverUrl;
    
    if (server.accessToken != null) {
      _dio.options.headers['X-Emby-Token'] = server.accessToken;
    }
  }

  Future<bool> authenticate(String serverUrl, String username, String password) async {
    try {
      _dio.options.baseUrl = serverUrl;
      
      final response = await _dio.post(
        '/Users/AuthenticateByName',
        data: {
          'Username': username,
          'Pw': password,
        },
        options: Options(
          headers: {
            'X-Emby-Authorization': 'MediaBrowser Client="Doudou", Device="Flutter", DeviceId="doudou-flutter", Version="1.0.0"',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        _server = JellyfinServer(
          serverUrl: serverUrl,
          userId: data['User']['Id'],
          accessToken: data['AccessToken'],
        );
        
        _dio.options.headers['X-Emby-Token'] = _server!.accessToken;
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Authentication error: $e');
      }
    }
    return false;
  }

  Future<List<Album>> getAlbums() async {
    if (_server == null) throw Exception('Server not configured');

    try {
      final response = await _dio.get(
        '/Users/${_server!.userId}/Items',
        queryParameters: {
          'IncludeItemTypes': 'MusicAlbum',
          'Recursive': true,
          'Fields': 'PrimaryImageAspectRatio,ImageTags',
          'SortBy': 'SortName',
          'SortOrder': 'Ascending',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> items = response.data['Items'];
        return items.map((item) => Album.fromJson(item)).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching albums: $e');
      }
    }
    return [];
  }

  Future<List<Track>> getAlbumTracks(String albumId) async {
    if (_server == null) throw Exception('Server not configured');

    try {
      final response = await _dio.get(
        '/Users/${_server!.userId}/Items',
        queryParameters: {
          'ParentId': albumId,
          'IncludeItemTypes': 'Audio',
          'Recursive': true,
          'Fields': 'PrimaryImageAspectRatio,ImageTags',
          'SortBy': 'IndexNumber',
          'SortOrder': 'Ascending',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> items = response.data['Items'];
        return items.map((item) => Track.fromJson(item)).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching album tracks: $e');
      }
    }
    return [];
  }

  Future<List<Track>> getAllTracks() async {
    if (_server == null) throw Exception('Server not configured');

    try {
      final response = await _dio.get(
        '/Users/${_server!.userId}/Items',
        queryParameters: {
          'IncludeItemTypes': 'Audio',
          'Recursive': true,
          'Fields': 'PrimaryImageAspectRatio,ImageTags,Artists,Album,AlbumId,IndexNumber,RunTimeTicks,UserData',
          'SortBy': 'Album,IndexNumber',
          'SortOrder': 'Ascending',
          'Limit': 1000, // Limit to prevent too large responses
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> items = response.data['Items'];
        return items.map((item) => Track.fromJson(item)).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching all tracks: $e');
      }
    }
    return [];
  }

  Future<List<Artist>> getArtists() async {
    if (_server == null) throw Exception('Server not configured');

    try {
      final response = await _dio.get(
        '/Artists',
        queryParameters: {
          'userId': _server!.userId,
          'Fields': 'PrimaryImageAspectRatio,ImageTags',
          'SortBy': 'SortName',
          'SortOrder': 'Ascending',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> items = response.data['Items'];
        return items.map((item) => Artist.fromJson(item)).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching artists: $e');
      }
    }
    return [];
  }

  Future<List<Playlist>> getPlaylists() async {
    if (_server == null) throw Exception('Server not configured');

    try {
      final response = await _dio.get(
        '/Users/${_server!.userId}/Items',
        queryParameters: {
          'IncludeItemTypes': 'Playlist',
          'Recursive': true,
          'Fields': 'PrimaryImageAspectRatio,ImageTags,ChildCount',
          'SortBy': 'SortName',
          'SortOrder': 'Ascending',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> items = response.data['Items'];
        return items.map((item) => Playlist.fromJson(item)).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching playlists: $e');
      }
    }
    return [];
  }

  Future<List<Track>> getPlaylistTracks(String playlistId) async {
    if (_server == null) throw Exception('Server not configured');

    try {
      final response = await _dio.get(
        '/Playlists/$playlistId/Items',
        queryParameters: {
          'UserId': _server!.userId,
          'Fields': 'PrimaryImageAspectRatio,ImageTags,UserData',
          'SortBy': 'SortName',
          'SortOrder': 'Ascending',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> items = response.data['Items'];
        return items.map((item) => Track.fromJson(item)).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching playlist tracks: $e');
      }
    }
    return [];
  }

  String getImageUrl(String itemId, {int? width, int? height}) {
    if (_server == null) return '';
    
    final params = <String, String>{};
    if (width != null) params['width'] = width.toString();
    if (height != null) params['height'] = height.toString();
    
    final queryString = params.isEmpty ? '' : '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    
    return '${_server!.serverUrl}/Items/$itemId/Images/Primary$queryString';
  }

  String getStreamUrl(String itemId) {
    if (_server == null) return '';
    
    // Use the stream endpoint with specific parameters for better compatibility
    final params = {
      'UserId': _server!.userId,
      'DeviceId': 'doudou-flutter',
      'api_key': _server!.accessToken,
      'Container': 'mp3,aac,m4a,flac,webm,mp4,ogg', // Specify supported containers
      'AudioCodec': 'mp3,aac,flac,vorbis,opus',      // Specify supported codecs
      'AudioBitRate': '128000',                       // Set reasonable bitrate
      'MaxAudioChannels': '2',                        // Stereo
      'TranscodingContainer': 'mp3',                  // Fallback container
      'TranscodingProtocol': 'http',                  // Use HTTP protocol
    };
    
    final queryString = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    
    return '${_server!.serverUrl}/Audio/$itemId/stream?$queryString';
  }

  String getDirectStreamUrl(String itemId) {
    if (_server == null) return '';
    
    // Alternative: direct download URL (no transcoding)
    return '${_server!.serverUrl}/Items/$itemId/Download?api_key=${_server!.accessToken}';
  }

  String getUniversalStreamUrl(String itemId) {
    if (_server == null) return '';
    
    // Alternative: universal endpoint with minimal params
    return '${_server!.serverUrl}/Audio/$itemId/universal?UserId=${_server!.userId}&DeviceId=doudou-flutter&api_key=${_server!.accessToken}';
  }

  Future<bool> toggleFavorite(String itemId, bool isFavorite) async {
    if (_server == null) throw Exception('Server not configured');

    try {
      final method = isFavorite ? 'DELETE' : 'POST';
      final response = await _dio.request(
        '/Users/${_server!.userId}/FavoriteItems/$itemId',
        options: Options(method: method),
      );

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      if (kDebugMode) {
        print('Error toggling favorite: $e');
      }
      return false;
    }
  }

  Future<Playlist?> createPlaylist(String name) async {
    if (_server == null) throw Exception('Server not configured');

    try {
      final response = await _dio.post(
        '/Playlists',
        data: {
          'Name': name,
          'MediaType': 'Audio',
          'UserId': _server!.userId,
        },
      );

      if (response.statusCode == 200) {
        final playlistId = response.data['Id'];
        if (playlistId != null) {
          // Return a new Playlist object
          return Playlist(
            id: playlistId,
            name: name,
            imageUrl: null,
            trackCount: 0,
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error creating playlist: $e');
      }
    }
    return null;
  }

  Future<bool> validateCredentials() async {
    if (_server == null) return false;

    try {
      final response = await _dio.get('/Users/${_server!.userId}');
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Error validating credentials: $e');
      }
      return false;
    }
  }

  JellyfinServer? get currentServer => _server;
}
