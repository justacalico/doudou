import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../models/jellyfin_models.dart';
import '../base_service.dart';

// Only import IO adapter for non-web platforms

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
    // Don't set sendTimeout on web as it's not supported
    if (!kIsWeb) {
      _dio.options.sendTimeout = const Duration(seconds: 30);
    }
    
    // Platform-specific configurations (not available on web)
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
      // On Linux, we might need more lenient SSL handling for self-signed certificates
      try {
        // Use dynamic type to avoid compilation issues on web
        final adapter = _dio.httpClientAdapter;
        if (adapter.runtimeType.toString() == 'IOHttpClientAdapter') {
          final dynamic ioAdapter = adapter;
          ioAdapter.onHttpClientCreate = (client) {
            client.badCertificateCallback = (cert, host, port) {
              if (kDebugMode) {
                print('Warning: Accepting bad certificate for $host:$port');
              }
              return true; // Accept all certificates for now (development)
            };
            return client;
          };
        }
      } catch (e) {
        if (kDebugMode) {
          print('Could not configure SSL certificate handling: $e');
        }
      }
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

  @override
  void setServer(String serverUrl) {
    _server = JellyfinServer(serverUrl: serverUrl);
    _dio.options.baseUrl = serverUrl;
  }

  void setJellyfinServer(JellyfinServer server) {
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

  @override
  Future<bool> authenticate(String serverUrl, String username, String password) async {
    try {
      _dio.options.baseUrl = serverUrl;
      
      if (kDebugMode) {
        print('JellyfinService: Attempting to authenticate to $serverUrl with user $username');
        print('Platform: ${kIsWeb ? 'Web' : defaultTargetPlatform.name}');
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
            'User-Agent': 'Doudou-Flutter/1.0.0 (${kIsWeb ? 'Web' : defaultTargetPlatform.name})',
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

  @override
  Future<List<Album>> getAlbums({String? libraryId, int? limit, int? startIndex}) async {
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

    if (kDebugMode) {
      print('JellyfinService.getAlbumTracks(): Fetching tracks for album: $albumId');
    }

    try {
      final response = await _dio.get(
        '/Users/${_server!.userId}/Items',
        queryParameters: {
          'ParentId': albumId,
          'IncludeItemTypes': 'Audio',
          'Recursive': true,
          'Fields': 'PrimaryImageAspectRatio,ImageTags,Artists,Album,AlbumId,IndexNumber,RunTimeTicks,UserData',
          'SortBy': 'IndexNumber',
          'SortOrder': 'Ascending',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> items = response.data['Items'];
        if (kDebugMode) {
          print('JellyfinService.getAlbumTracks(): Successfully loaded ${items.length} tracks for album: $albumId');
        }
        return items.map((item) => Track.fromJson(item)).toList();
      } else {
        if (kDebugMode) {
          print('JellyfinService.getAlbumTracks(): Bad response ${response.statusCode} for album: $albumId');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('JellyfinService.getAlbumTracks(): Error fetching album tracks for $albumId: $e');
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

  @override
  Future<List<Artist>> getArtists({String? libraryId, int? limit, int? startIndex}) async {
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

  @override
  Future<List<Playlist>> getPlaylists() async {
    if (_server == null) throw Exception('Server not configured');

    if (kDebugMode) {
      print('JellyfinService.getPlaylists() called');
      print('  - Server: ${_server!.serverUrl}');
      print('  - UserId: ${_server!.userId}');
    }

    try {
      final url = '/Users/${_server!.userId}/Items';
      final queryParams = {
        'IncludeItemTypes': 'Playlist',
        'Recursive': true,
        'Fields': 'PrimaryImageAspectRatio,ImageTags,ChildCount',
        'SortBy': 'SortName',
        'SortOrder': 'Ascending',
      };
      
      if (kDebugMode) {
        print('JellyfinService: Making request to: $url');
        print('JellyfinService: Query params: $queryParams');
      }

      final response = await _dio.get(url, queryParameters: queryParams);

      if (kDebugMode) {
        print('JellyfinService: Response status: ${response.statusCode}');
        print('JellyfinService: Response data type: ${response.data.runtimeType}');
      }

      if (response.statusCode == 200) {
        final List<dynamic> items = response.data['Items'];
        
        if (kDebugMode) {
          print('JellyfinService: Found ${items.length} playlist items');
          if (items.isNotEmpty) {
            print('JellyfinService: First playlist raw data: ${items.first}');
          }
        }
        
        final playlists = items.map((item) => Playlist.fromJson(item)).toList();
        
        if (kDebugMode) {
          print('JellyfinService: Converted to ${playlists.length} playlist objects');
          if (playlists.isNotEmpty) {
            print('JellyfinService: First playlist: ${playlists.first.name} (${playlists.first.trackCount} tracks)');
          }
        }
        
        return playlists;
      } else {
        if (kDebugMode) {
          print('JellyfinService: Unexpected response status: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('JellyfinService: Error fetching playlists: $e');
        print('JellyfinService: Error type: ${e.runtimeType}');
      }
    }
    return [];
  }

  @override
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

  // Simple cache for image URLs to reduce repeated generations
  final Map<String, String> _imageUrlCache = <String, String>{};

  @override
  String getImageUrl(String itemId, {String type = 'Primary', int? width, int? height}) {
    if (_server == null || itemId.isEmpty) {
      return '';
    }
    
    // Create cache key
    final cacheKey = '$itemId-$type-$width-$height';
    
    // Return cached URL if available
    if (_imageUrlCache.containsKey(cacheKey)) {
      return _imageUrlCache[cacheKey]!;
    }
    
    final params = <String, String>{};
    if (width != null) params['width'] = width.toString();
    if (height != null) params['height'] = height.toString();
    
    final queryString = params.isEmpty ? '' : '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    
    // Remove trailing slash from serverUrl to prevent double slashes
    final baseUrl = _server!.serverUrl.endsWith('/') 
        ? _server!.serverUrl.substring(0, _server!.serverUrl.length - 1)
        : _server!.serverUrl;
    
    final imageUrl = '$baseUrl/Items/$itemId/Images/$type$queryString';
    
    // Cache the generated URL
    _imageUrlCache[cacheKey] = imageUrl;
    
    // Only log first generation of each URL, not repeated calls
    if (kDebugMode && _imageUrlCache.length % 50 == 1) {
      // ignore: avoid_print
      print('JellyfinService.getImageUrl: Cached ${_imageUrlCache.length} image URLs');
    }
    
    return imageUrl;
  }

  @override
  String getStreamUrl(String itemId, {int? bitrate}) {
    if (!_isServerConfigurationValid() || itemId.isEmpty) {
      return '';
    }
    
    // Use the stream endpoint with specific parameters for better compatibility
    final params = {
      'UserId': _server!.userId!,
      'DeviceId': 'doudou-flutter',
      'api_key': _server!.accessToken!,
      'Container': 'mp3,aac,m4a,flac,webm,mp4,ogg', // Specify supported containers
      'AudioCodec': 'mp3,aac,flac,vorbis,opus',      // Specify supported codecs
      'AudioBitRate': bitrate?.toString() ?? '320000', // Use provided bitrate or default to high quality
      'MaxAudioChannels': '2',                        // Stereo
      'TranscodingContainer': 'mp3',                  // Fallback container
      'TranscodingProtocol': 'http',                  // Use HTTP protocol
    };
    
    final queryString = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    
    // Remove trailing slash from serverUrl to prevent double slashes
    final baseUrl = _server!.serverUrl.endsWith('/') 
        ? _server!.serverUrl.substring(0, _server!.serverUrl.length - 1)
        : _server!.serverUrl;
    
    final streamUrl = '$baseUrl/Audio/$itemId/stream?$queryString';
    
    if (kDebugMode) {
      print('JellyfinService.getStreamUrl: Generated URL: $streamUrl');
    }
    
    return streamUrl;
  }

  String getDirectStreamUrl(String itemId) {
    if (!_isServerConfigurationValid() || itemId.isEmpty) {
      return '';
    }
    
    // Remove trailing slash from serverUrl to prevent double slashes
    final baseUrl = _server!.serverUrl.endsWith('/') 
        ? _server!.serverUrl.substring(0, _server!.serverUrl.length - 1)
        : _server!.serverUrl;
    
    // Alternative: direct download URL (no transcoding)
    final directUrl = '$baseUrl/Items/$itemId/Download?api_key=${_server!.accessToken}';
    
    if (kDebugMode) {
      print('JellyfinService.getDirectStreamUrl: Generated URL: $directUrl');
    }
    
    return directUrl;
  }

  String getUniversalStreamUrl(String itemId) {
    if (!_isServerConfigurationValid() || itemId.isEmpty) {
      return '';
    }
    
    // Remove trailing slash from serverUrl to prevent double slashes
    final baseUrl = _server!.serverUrl.endsWith('/') 
        ? _server!.serverUrl.substring(0, _server!.serverUrl.length - 1)
        : _server!.serverUrl;
    
    // Alternative: universal endpoint with minimal params
    final universalUrl = '$baseUrl/Audio/$itemId/universal?UserId=${_server!.userId}&DeviceId=doudou-flutter&api_key=${_server!.accessToken}';
    
    if (kDebugMode) {
      print('JellyfinService.getUniversalStreamUrl: Generated URL: $universalUrl');
    }
    
    return universalUrl;
  }

  @override
  Future<bool> toggleFavorite(String itemId, bool isFavorite) async {
    if (_server == null) throw Exception('Server not configured');

    if (kDebugMode) {
      print('JellyfinService.toggleFavorite: itemId=$itemId, isFavorite=$isFavorite');
      print('Server URL: ${_server!.serverUrl}');
      print('User ID: ${_server!.userId}');
    }

    try {
      final method = isFavorite ? 'DELETE' : 'POST';
      final url = '/Users/${_server!.userId}/FavoriteItems/$itemId';
      
      if (kDebugMode) {
        print('Making $method request to: $url');
      }
      
      final response = await _dio.request(
        url,
        options: Options(method: method),
      );

      final success = response.statusCode == 200 || response.statusCode == 204;
      
      if (kDebugMode) {
        print('Jellyfin response: ${response.statusCode}, success: $success');
        if (response.data != null) {
          print('Response data: ${response.data}');
        }
      }

      return success;
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

  @override
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
            'User-Agent': 'Doudou-Flutter/1.0.0 (${kIsWeb ? 'Web' : defaultTargetPlatform.name})',
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
            'User-Agent': 'Doudou-Flutter/1.0.0 (${kIsWeb ? 'Web' : defaultTargetPlatform.name})',
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

  @override
  JellyfinServer? get currentServer => _server;

  // Validate server configuration for stream URL generation
  bool _isServerConfigurationValid() {
    if (_server == null) {
      if (kDebugMode) {
        print('JellyfinService._isServerConfigurationValid: Server is null');
      }
      return false;
    }
    
    if (_server!.serverUrl.isEmpty) {
      if (kDebugMode) {
        print('JellyfinService._isServerConfigurationValid: Server URL is empty');
      }
      return false;
    }
    
    if (_server!.userId == null || _server!.userId!.isEmpty) {
      if (kDebugMode) {
        print('JellyfinService._isServerConfigurationValid: User ID is null or empty');
      }
      return false;
    }
    
    if (_server!.accessToken == null || _server!.accessToken!.isEmpty) {
      if (kDebugMode) {
        print('JellyfinService._isServerConfigurationValid: Access token is null or empty');
      }
      return false;
    }
    
    return true;
  }

  // Get alternative stream URL format (simple direct playback)
  String getSimpleStreamUrl(String itemId) {
    if (!_isServerConfigurationValid() || itemId.isEmpty) {
      return '';
    }
    
    final baseUrl = _server!.serverUrl.endsWith('/') 
        ? _server!.serverUrl.substring(0, _server!.serverUrl.length - 1)
        : _server!.serverUrl;
    
    final simpleUrl = '$baseUrl/Audio/$itemId/stream.mp3?api_key=${_server!.accessToken}';
    
    if (kDebugMode) {
      print('JellyfinService.getSimpleStreamUrl: Generated URL: $simpleUrl');
    }
    
    return simpleUrl;
  }

  // Get alternative stream URL format (with minimal params)
  String getMinimalStreamUrl(String itemId) {
    if (!_isServerConfigurationValid() || itemId.isEmpty) {
      return '';
    }
    
    final baseUrl = _server!.serverUrl.endsWith('/') 
        ? _server!.serverUrl.substring(0, _server!.serverUrl.length - 1)
        : _server!.serverUrl;
    
    final minimalUrl = '$baseUrl/Audio/$itemId?api_key=${_server!.accessToken}';
    
    if (kDebugMode) {
      print('JellyfinService.getMinimalStreamUrl: Generated URL: $minimalUrl');
    }
    
    return minimalUrl;
  }

  // Get download URL for a track
  String getDownloadUrl(String itemId) {
    if (!_isServerConfigurationValid() || itemId.isEmpty) {
      return '';
    }
    
    // Remove trailing slash from serverUrl to prevent double slashes
    final baseUrl = _server!.serverUrl.endsWith('/') 
        ? _server!.serverUrl.substring(0, _server!.serverUrl.length - 1)
        : _server!.serverUrl;
    
    final downloadUrl = '$baseUrl/Items/$itemId/Download?api_key=${_server!.accessToken}';
    
    if (kDebugMode) {
      print('JellyfinService.getDownloadUrl: Generated URL: $downloadUrl');
    }
    
    return downloadUrl;
  }

  // Get authentication headers for HTTP requests
  Future<Map<String, String>> getAuthHeaders() async {
    if (_server == null) return {};
    
    return {
      'X-Emby-Token': _server!.accessToken ?? '',
      'X-Emby-Authorization': 'MediaBrowser UserId="${_server!.userId}", Client="doudou-flutter", Device="Flutter", DeviceId="doudou-flutter", Version="1.0.0"',
    };
  }

  @override
  Future<List<Library>> getLibraries() async {
    if (_server == null) throw Exception('Server not configured');
    
    try {
      final response = await _dio.get(
        '/Users/${_server!.userId}/Views',
        queryParameters: {
          'IncludeExternalContent': false,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> items = response.data['Items'];
        return items
            .where((item) => item['CollectionType'] == 'music')
            .map((item) => Library.fromJson(item))
            .toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching libraries: $e');
      }
    }
    return [];
  }

  @override
  Future<List<Track>> getTracks({String? libraryId, String? parentId, int? limit, int? startIndex}) async {
    if (_server == null) throw Exception('Server not configured');

    try {
      final params = <String, dynamic>{
        'IncludeItemTypes': 'Audio',
        'Recursive': true,
        'Fields': 'PrimaryImageAspectRatio,ImageTags,Artists,Album,AlbumId,IndexNumber,RunTimeTicks,UserData',
        'SortBy': 'Album,IndexNumber',
        'SortOrder': 'Ascending',
      };

      if (libraryId != null) params['ParentId'] = libraryId;
      if (parentId != null) params['ParentId'] = parentId;
      if (limit != null) params['Limit'] = limit;
      if (startIndex != null) params['StartIndex'] = startIndex;

      final response = await _dio.get(
        '/Users/${_server!.userId}/Items',
        queryParameters: params,
      );

      if (response.statusCode == 200) {
        final List<dynamic> items = response.data['Items'];
        return items.map((item) => Track.fromJson(item)).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching tracks: $e');
      }
    }
    return [];
  }

  @override
  Future<SearchResults> search(String query, {List<String>? includeItemTypes, int? limit}) async {
    if (_server == null) throw Exception('Server not configured');

    try {
      final params = <String, dynamic>{
        'SearchTerm': query,
        'IncludeItemTypes': includeItemTypes?.join(',') ?? 'MusicAlbum,MusicArtist,Audio',
        'Recursive': true,
        'Fields': 'PrimaryImageAspectRatio,ImageTags',
      };

      if (limit != null) params['Limit'] = limit;

      final response = await _dio.get(
        '/Users/${_server!.userId}/Items',
        queryParameters: params,
      );

      if (response.statusCode == 200) {
        final List<dynamic> items = response.data['Items'];
        
        final albums = <Album>[];
        final artists = <Artist>[];
        final tracks = <Track>[];

        for (final item in items) {
          switch (item['Type']) {
            case 'MusicAlbum':
              albums.add(Album.fromJson(item));
              break;
            case 'MusicArtist':
              artists.add(Artist.fromJson(item));
              break;
            case 'Audio':
              tracks.add(Track.fromJson(item));
              break;
          }
        }

        return SearchResults(albums: albums, artists: artists, tracks: tracks);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error searching: $e');
      }
    }
    return SearchResults();
  }

  @override
  Future<ServerInfo> getServerInfo() async {
    if (_server == null) {
      return ServerInfo(
        name: 'Jellyfin Server',
        version: 'Unknown',
        id: 'unknown',
        type: ServerType.jellyfin,
      );
    }

    try {
      final response = await _dio.get('/System/Info');
      
      if (response.statusCode == 200) {
        final data = response.data;
        return ServerInfo(
          name: data['ServerName'] ?? 'Jellyfin Server',
          version: data['Version'] ?? 'Unknown',
          id: data['Id'] ?? _server!.serverUrl,
          type: ServerType.jellyfin,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting server info: $e');
      }
    }
    
    return ServerInfo(
      name: 'Jellyfin Server',
      version: 'Unknown',
      id: _server!.serverUrl,
      type: ServerType.jellyfin,
    );
  }

  @override
  List<String> getAlternativeStreamUrls(String trackId) {
    if (kDebugMode) {
      print('JellyfinService.getAlternativeStreamUrls: Getting URLs for trackId: $trackId');
      print('JellyfinService.getAlternativeStreamUrls: Server configured: ${_server != null}');
      if (_server != null) {
        print('JellyfinService.getAlternativeStreamUrls: Server URL: ${_server!.serverUrl}');
        print('JellyfinService.getAlternativeStreamUrls: User ID: ${_server!.userId}');
        print('JellyfinService.getAlternativeStreamUrls: Access Token exists: ${_server!.accessToken != null && _server!.accessToken!.isNotEmpty}');
      }
    }
    
    // Return multiple Jellyfin stream URLs in order of preference for fallback
    // Prioritize direct download since it works most reliably
    final urls = [
      getDirectStreamUrl(trackId),    // Direct download URL (most reliable)
      getSimpleStreamUrl(trackId),    // Simple stream format
      getMinimalStreamUrl(trackId),   // Minimal params format
      getStreamUrl(trackId),          // Primary transcoded stream URL
      getUniversalStreamUrl(trackId), // Universal stream URL
    ].where((url) => url.isNotEmpty).toList(); // Filter out empty URLs
    
    if (kDebugMode) {
      print('JellyfinService.getAlternativeStreamUrls: Generated ${urls.length} valid URLs:');
      for (int i = 0; i < urls.length; i++) {
        final url = urls[i];
        print('  [$i] ${url.isEmpty ? '<EMPTY>' : url}');
      }
    }
    
    if (urls.isEmpty && kDebugMode) {
      if (kDebugMode) {
        print('JellyfinService.getAlternativeStreamUrls: ERROR - No valid URLs generated!');
      }
      if (kDebugMode) {
        print('  Server configuration valid: ${_isServerConfigurationValid()}');
      }
      if (kDebugMode) {
        print('  Track ID provided: ${trackId.isNotEmpty}');
      }
    }
    
    return urls;
  }

  @override
  Future<List<String>> getAlternativeStreamUrlsAsync(String trackId) async {
    // Jellyfin doesn't need async metadata fetching, return sync version
    return getAlternativeStreamUrls(trackId);
  }

  @override
  void clearAuth() {
    _server = null;
    _dio.options.headers.remove('X-Emby-Token');
    _dio.options.baseUrl = '';
  }
}
