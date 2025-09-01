import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/jellyfin_models.dart';

// Network error types for better error handling
enum NetworkErrorType {
  connectionTimeout,
  serverError,
  unauthorized,
  notFound,
  noInternet,
  unknown
}

class NetworkException implements Exception {
  final String message;
  final NetworkErrorType type;
  
  NetworkException(this.message, this.type);
  
  @override
  String toString() => message;
}

class JellyfinService {
  late Dio _dio;
  JellyfinServer? _server;

  JellyfinService() {
    _dio = Dio();
    
    // Configure timeouts for better network handling
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.sendTimeout = const Duration(seconds: 30);
    
    // Add error handling interceptor
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) {
        final networkError = _handleDioError(error);
        handler.reject(DioException(
          requestOptions: error.requestOptions,
          error: networkError,
          message: networkError.message,
        ));
      },
    ));
  }
  
  NetworkException _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkException(
          'Connection timeout. Please check your network connection and server availability.',
          NetworkErrorType.connectionTimeout,
        );
      case DioExceptionType.badResponse:
        switch (error.response?.statusCode) {
          case 401:
            return NetworkException(
              'Invalid username or password. Please check your credentials.',
              NetworkErrorType.unauthorized,
            );
          case 404:
            return NetworkException(
              'Server not found. Please check your server URL.',
              NetworkErrorType.notFound,
            );
          case 500:
          case 502:
          case 503:
            return NetworkException(
              'Server error. Please try again later or contact your server administrator.',
              NetworkErrorType.serverError,
            );
          default:
            return NetworkException(
              'Server returned error ${error.response?.statusCode}. Please try again.',
              NetworkErrorType.serverError,
            );
        }
      case DioExceptionType.cancel:
        return NetworkException(
          'Request was cancelled.',
          NetworkErrorType.unknown,
        );
      case DioExceptionType.connectionError:
        return NetworkException(
          'Unable to connect to server. Please check your network connection and server URL.',
          NetworkErrorType.noInternet,
        );
      default:
        return NetworkException(
          'Network error: ${error.message ?? 'Unknown error occurred'}',
          NetworkErrorType.unknown,
        );
    }
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
          'Fields': 'PrimaryImageAspectRatio,ImageTags,Artists,Album,AlbumId,IndexNumber,RunTimeTicks,UserData',
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

  Future<bool> addToPlaylist(String playlistId, String trackId) async {
    if (_server == null) throw Exception('Server not configured');

    try {
      final response = await _dio.post(
        '/Playlists/$playlistId/Items',
        queryParameters: {
          'Ids': trackId,
          'UserId': _server!.userId,
        },
      );

      return response.statusCode == 204; // Jellyfin returns 204 for successful additions
    } catch (e) {
      if (kDebugMode) {
        print('Error adding track to playlist: $e');
      }
      return false;
    }
  }

  Future<bool> renamePlaylist(String playlistId, String newName) async {
    if (_server == null) throw Exception('Server not configured');

    try {
      // Get the current playlist to preserve other properties
      final currentPlaylist = await _dio.get('/Users/${_server!.userId}/Items/$playlistId');
      
      if (currentPlaylist.statusCode != 200) {
        if (kDebugMode) {
          print('Failed to get current playlist data');
        }
        return false;
      }
      
      final playlistData = currentPlaylist.data;
      
      // Update the playlist using the correct Jellyfin endpoint
      final response = await _dio.post(
        '/Items/$playlistId',
        data: {
          'Id': playlistId,
          'Name': newName,
          'Overview': playlistData['Overview'] ?? '',
          'MediaType': playlistData['MediaType'] ?? 'Audio',
          'PlaylistMediaType': playlistData['PlaylistMediaType'] ?? 'Audio',
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      bool success = response.statusCode == 204 || response.statusCode == 200;
      
      if (kDebugMode) {
        print('Rename playlist response: ${response.statusCode}');
        if (!success) {
          print('Rename failed with data: ${response.data}');
        }
      }
      
      return success;
    } catch (e) {
      if (kDebugMode) {
        print('Error renaming playlist: $e');
      }
      return false;
    }
  }

  Future<bool> removePlaylist(String playlistId) async {
    if (_server == null) throw Exception('Server not configured');

    try {
      final response = await _dio.delete('/Items/$playlistId');

      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Error removing playlist: $e');
      }
      return false;
    }
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

  // Get download URL for a track
  String getDownloadUrl(String itemId) {
    if (_server == null) return '';
    return '${_server!.serverUrl}/Items/$itemId/Download?api_key=${_server!.accessToken}';
  }

  // Get authentication headers for HTTP requests
  Future<Map<String, String>> getAuthHeaders() async {
    if (_server == null) return {};
    
    return {
      'X-Emby-Token': _server!.accessToken ?? '',
      'X-Emby-Authorization': 'MediaBrowser UserId="${_server!.userId}", Client="doudou-flutter", Device="Flutter", DeviceId="doudou-flutter", Version="1.0.0"',
    };
  }
}
