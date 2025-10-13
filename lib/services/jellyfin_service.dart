import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import '../models/jellyfin_models.dart';
import 'base_service.dart';

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

class JellyfinService implements BaseMediaService {
  late Dio _dio;
  JellyfinServer? _server;

  @override
  ServerType get serverType => ServerType.jellyfin;

  JellyfinService() {
    _dio = Dio();
    
    // Configure timeouts for better network handling
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.sendTimeout = const Duration(seconds: 30);
    
    // Platform-specific configurations
    if (Platform.isLinux) {
      // On Linux, we might need more lenient SSL handling for self-signed certificates
      (_dio.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate = (client) {
        client.badCertificateCallback = (cert, host, port) {
          if (kDebugMode) {
            print('Warning: Accepting bad certificate for $host:$port');
          }
          return true; // Accept all certificates for now (development)
        };
        return client;
      };
    }
    
    // Add error handling interceptor
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // Skip adding auth headers if skipAuth is specified
        if (options.extra['skipAuth'] == true) {
          // Remove any existing auth headers for this request
          options.headers.remove('X-Emby-Token');
        }
        handler.next(options);
      },
      onError: (error, handler) {
        // Handle 401 errors with automatic token refresh
        if (error.response?.statusCode == 401 && 
            _server != null && 
            _server!.username != null && 
            _server!.password != null &&
            error.requestOptions.extra['skipAuth'] != true) { // Don't retry skipAuth requests
          
          if (kDebugMode) {
            print('JellyfinService: 401 error detected, attempting token refresh...');
          }
          
          // Attempt to refresh the token
          _refreshToken().then((success) {
            if (success) {
              if (kDebugMode) {
                print('JellyfinService: Token refresh successful, retrying request...');
              }
              // Retry the original request with the new token
              final options = error.requestOptions;
              options.headers['X-Emby-Token'] = _server!.accessToken;
              
              _dio.request(
                options.path,
                data: options.data,
                queryParameters: options.queryParameters,
                options: Options(
                  method: options.method,
                  headers: options.headers,
                  extra: options.extra,
                ),
              ).then((response) {
                handler.resolve(response);
              }).catchError((retryError) {
                if (kDebugMode) {
                  print('JellyfinService: Retry after token refresh failed: $retryError');
                }
                // If retry fails, proceed with original error handling
                final networkError = _handleDioError(error);
                handler.reject(DioException(
                  requestOptions: error.requestOptions,
                  error: networkError,
                  message: networkError.message,
                ));
              });
            } else {
              if (kDebugMode) {
                print('JellyfinService: Token refresh failed, proceeding with 401 error');
              }
              // Token refresh failed, proceed with original error handling
              final networkError = _handleDioError(error);
              handler.reject(DioException(
                requestOptions: error.requestOptions,
                error: networkError,
                message: networkError.message,
              ));
            }
          }).catchError((refreshError) {
            if (kDebugMode) {
              print('JellyfinService: Token refresh threw error: $refreshError');
            }
            // Token refresh threw an error, proceed with original error handling
            final networkError = _handleDioError(error);
            handler.reject(DioException(
              requestOptions: error.requestOptions,
              error: networkError,
              message: networkError.message,
            ));
          });
        } else {
          // Not a 401, no credentials to refresh, or skipAuth request - handle normally
          final networkError = _handleDioError(error);
          handler.reject(DioException(
            requestOptions: error.requestOptions,
            error: networkError,
            message: networkError.message,
          ));
        }
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

  // Public getters for server information
  String? get serverUrl => _server?.serverUrl;
  String? get username => _server?.username;
  String? get userId => _server?.userId;
  bool get isConnected => _server != null;

  Future<bool> authenticate(String serverUrl, String username, String password) async {
    try {
      _dio.options.baseUrl = serverUrl;
      
      if (kDebugMode) {
        print('JellyfinService: Attempting to authenticate to $serverUrl with user $username');
        print('Platform: ${Platform.operatingSystem}');
      }
      
      final response = await _dio.post(
        '/Users/AuthenticateByName',
        data: {
          'Username': username,
          'Pw': password,
        },
        options: Options(
          headers: {
            'X-Emby-Authorization': 'MediaBrowser Client="Doudou", Device="Flutter", DeviceId="doudou-flutter", Version="1.0.0"',
            'Content-Type': 'application/json',
            'User-Agent': 'Doudou-Flutter/1.0.0 (${Platform.operatingSystem})',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        _server = JellyfinServer(
          serverUrl: serverUrl,
          userId: data['User']['Id'],
          accessToken: data['AccessToken'],
          username: username,
          password: password,
        );
        
        _dio.options.headers['X-Emby-Token'] = _server!.accessToken;
        
        if (kDebugMode) {
          print('JellyfinService: Authentication successful. Server: ${_server!.serverUrl}, UserId: ${_server!.userId}, Token: ${_server!.accessToken?.substring(0, 8)}...');
        }
        
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
    if (_server == null) {
      if (kDebugMode) {
        print('JellyfinService.getAlbums(): Server not configured');
      }
      throw Exception('Server not configured');
    }

    if (kDebugMode) {
      print('JellyfinService.getAlbums(): Server URL: ${_server!.serverUrl}, Token exists: ${_server!.accessToken != null}');
    }

    try {
      if (kDebugMode) {
        print('JellyfinService.getAlbums(): Making API call to /Users/${_server!.userId}/Items');
      }
      
      final response = await _dio.get(
        '/Users/${_server!.userId}/Items',
        queryParameters: {
          'IncludeItemTypes': 'MusicAlbum',
          'Recursive': true,
          'Fields': 'PrimaryImageAspectRatio,ImageTags,DateCreated',
          'SortBy': 'DateCreated',
          'SortOrder': 'Descending',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> items = response.data['Items'];
        if (kDebugMode) {
          print('JellyfinService.getAlbums(): Successfully loaded ${items.length} albums');
        }
        return items.map((item) => Album.fromJson(item)).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('JellyfinService.getAlbums(): Error fetching albums: $e');
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
    
    // Remove trailing slash from serverUrl to prevent double slashes
    final baseUrl = _server!.serverUrl.endsWith('/') 
        ? _server!.serverUrl.substring(0, _server!.serverUrl.length - 1)
        : _server!.serverUrl;
    
    return '$baseUrl/Items/$itemId/Images/Primary$queryString';
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
    
    // Remove trailing slash from serverUrl to prevent double slashes
    final baseUrl = _server!.serverUrl.endsWith('/') 
        ? _server!.serverUrl.substring(0, _server!.serverUrl.length - 1)
        : _server!.serverUrl;
    
    return '$baseUrl/Audio/$itemId/stream?$queryString';
  }

  String getDirectStreamUrl(String itemId) {
    if (_server == null) return '';
    
    // Remove trailing slash from serverUrl to prevent double slashes
    final baseUrl = _server!.serverUrl.endsWith('/') 
        ? _server!.serverUrl.substring(0, _server!.serverUrl.length - 1)
        : _server!.serverUrl;
    
    // Alternative: direct download URL (no transcoding)
    return '$baseUrl/Items/$itemId/Download?api_key=${_server!.accessToken}';
  }

  String getUniversalStreamUrl(String itemId) {
    if (_server == null) return '';
    
    // Remove trailing slash from serverUrl to prevent double slashes
    final baseUrl = _server!.serverUrl.endsWith('/') 
        ? _server!.serverUrl.substring(0, _server!.serverUrl.length - 1)
        : _server!.serverUrl;
    
    // Alternative: universal endpoint with minimal params
    return '$baseUrl/Audio/$itemId/universal?UserId=${_server!.userId}&DeviceId=doudou-flutter&api_key=${_server!.accessToken}';
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

  /// Attempt to re-authenticate using stored credentials
  Future<bool> refreshAuthentication() async {
    if (_server == null) {
      if (kDebugMode) {
        print('JellyfinService: Cannot refresh authentication - no server configured');
      }
      return false;
    }

    // For Jellyfin, we need to get fresh credentials from storage since we don't store the password
    // This method will be called by AppState when it has access to stored credentials
    if (kDebugMode) {
      print('JellyfinService: refreshAuthentication called, but requires credentials from AppState');
    }
    return false;
  }

  /// Re-authenticate with provided credentials (called from AppState)
  Future<bool> reauthenticateWithCredentials(String username, String password) async {
    if (_server == null) return false;

    try {
      if (kDebugMode) {
        print('JellyfinService: Attempting to re-authenticate user $username');
      }

      final response = await _dio.post(
        '/Users/AuthenticateByName',
        data: {
          'Username': username,
          'Pw': password,
        },
        options: Options(
          headers: {
            'X-Emby-Authorization': 'MediaBrowser Client="Doudou", Device="Flutter", DeviceId="doudou-flutter", Version="1.0.0"',
            'Content-Type': 'application/json',
            'User-Agent': 'Doudou-Flutter/1.0.0 (${Platform.operatingSystem})',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        // Update the existing server with new access token
        _server = JellyfinServer(
          serverUrl: _server!.serverUrl,
          userId: data['User']['Id'],
          accessToken: data['AccessToken'],
          username: _server!.username,
          password: _server!.password,
        );
        
        // Update Dio headers with new token
        _dio.options.headers['X-Emby-Token'] = _server!.accessToken;
        
        if (kDebugMode) {
          print('JellyfinService: Re-authentication successful. New token: ${_server!.accessToken?.substring(0, 8)}...');
        }
        
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('JellyfinService: Re-authentication failed: $e');
      }
    }
    return false;
  }

  /// Internal method to refresh token using stored credentials
  Future<bool> _refreshToken() async {
    if (_server == null || _server!.username == null || _server!.password == null) {
      if (kDebugMode) {
        print('JellyfinService: Cannot refresh token - missing server or credentials');
      }
      return false;
    }

    try {
      if (kDebugMode) {
        print('JellyfinService: Attempting to refresh token for user ${_server!.username}');
      }

      final response = await _dio.post(
        '/Users/AuthenticateByName',
        data: {
          'Username': _server!.username,
          'Pw': _server!.password,
        },
        options: Options(
          headers: {
            'X-Emby-Authorization': 'MediaBrowser Client="Doudou", Device="Flutter", DeviceId="doudou-flutter", Version="1.0.0"',
            'Content-Type': 'application/json',
            'User-Agent': 'Doudou-Flutter/1.0.0 (${Platform.operatingSystem})',
          },
          // Don't include the old token in the refresh request
          extra: {'skipAuth': true},
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        // Update the server with new access token
        _server = JellyfinServer(
          serverUrl: _server!.serverUrl,
          userId: data['User']['Id'],
          accessToken: data['AccessToken'],
          username: _server!.username,
          password: _server!.password,
        );
        
        // Update Dio headers with new token
        _dio.options.headers['X-Emby-Token'] = _server!.accessToken;
        
        if (kDebugMode) {
          print('JellyfinService: Token refresh successful. New token: ${_server!.accessToken?.substring(0, 8)}...');
        }
        
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('JellyfinService: Token refresh failed: $e');
      }
    }
    return false;
  }

  JellyfinServer? get currentServer => _server;

  // Get download URL for a track
  String getDownloadUrl(String itemId) {
    if (_server == null) return '';
    
    // Remove trailing slash from serverUrl to prevent double slashes
    final baseUrl = _server!.serverUrl.endsWith('/') 
        ? _server!.serverUrl.substring(0, _server!.serverUrl.length - 1)
        : _server!.serverUrl;
    
    return '$baseUrl/Items/$itemId/Download?api_key=${_server!.accessToken}';
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
