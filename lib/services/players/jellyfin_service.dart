import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
  unknown,
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
  static String _appVersion = '1.0.0'; // Default, will be updated on init
  static bool _versionInitialized = false;

  @override
  ServerType get serverType => ServerType.jellyfin;

  /// Initialize the app version from package info
  static Future<void> initializeVersion() async {
    if (_versionInitialized) return;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = packageInfo.version;
      _versionInitialized = true;
    } catch (e) {
      // Failed to get app version
    }
  }

  /// Get the current app version string
  static String get appVersion => _appVersion;

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
              return true; // Accept all certificates for now (development)
            };
            return client;
          };
        }
      } catch (e) {
        // Could not configure SSL certificate handling
      }
    }

    // Add error handling interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
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
              error.requestOptions.extra['skipAuth'] != true) {
            // Don't retry skipAuth requests

            // Attempt to refresh the token
            _refreshToken()
                .then((success) {
                  if (success) {
                    // Retry the original request with the new token
                    final options = error.requestOptions;
                    options.headers['X-Emby-Token'] = _server!.accessToken;

                    _dio
                        .request(
                          options.path,
                          data: options.data,
                          queryParameters: options.queryParameters,
                          options: Options(
                            method: options.method,
                            headers: options.headers,
                            extra: options.extra,
                          ),
                        )
                        .then((response) {
                          handler.resolve(response);
                        })
                        .catchError((retryError) {
                          // If retry fails, proceed with original error handling
                          final networkError = _handleDioError(error);
                          handler.reject(
                            DioException(
                              requestOptions: error.requestOptions,
                              error: networkError,
                              message: networkError.message,
                            ),
                          );
                        });
                  } else {
                    // Token refresh failed, proceed with original error handling
                    final networkError = _handleDioError(error);
                    handler.reject(
                      DioException(
                        requestOptions: error.requestOptions,
                        error: networkError,
                        message: networkError.message,
                      ),
                    );
                  }
                })
                .catchError((refreshError) {
                  // Token refresh threw an error, proceed with original error handling
                  final networkError = _handleDioError(error);
                  handler.reject(
                    DioException(
                      requestOptions: error.requestOptions,
                      error: networkError,
                      message: networkError.message,
                    ),
                  );
                });
          } else {
            // Not a 401, no credentials to refresh, or skipAuth request - handle normally
            final networkError = _handleDioError(error);
            handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                error: networkError,
                message: networkError.message,
              ),
            );
          }
        },
      ),
    );
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
  Future<bool> authenticate(
    String serverUrl,
    String username,
    String password,
  ) async {
    try {
      _dio.options.baseUrl = serverUrl;
      // Clear any existing auth headers from previous sessions
      _dio.options.headers.remove('X-Emby-Token');

      final response = await _dio.post(
        '/Users/AuthenticateByName',
        data: {'Username': username, 'Pw': password},
        options: Options(
          headers: {
            'X-Emby-Authorization':
                'MediaBrowser Client="Doudou", Device="Flutter", DeviceId="doudou-flutter", Version="$_appVersion"',
            'Content-Type': 'application/json',
            'User-Agent':
                'Doudou-Flutter/$_appVersion (${kIsWeb ? 'Web' : defaultTargetPlatform.name})',
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

        return true;
      }
    } catch (e) {
      // Authentication error
    }
    return false;
  }

  /// Authenticate using an API key (X-Emby-Token)
  /// This allows users to login with just an API key instead of username/password
  Future<bool> authenticateWithApiKey(String serverUrl, String apiKey) async {
    try {
      _dio.options.baseUrl = serverUrl;
      // Clear any existing auth headers from previous sessions
      _dio.options.headers.remove('X-Emby-Token');

      // First, validate the API key by checking system info
      final systemResponse = await _dio.get(
        '/System/Info',
        options: Options(
          headers: {
            'X-Emby-Token': apiKey,
            'Content-Type': 'application/json',
            'User-Agent':
                'Doudou-Flutter/$_appVersion (${kIsWeb ? 'Web' : defaultTargetPlatform.name})',
          },
        ),
      );

      if (systemResponse.statusCode != 200) {
        return false;
      }

      // Get list of users to find one to use
      final usersResponse = await _dio.get(
        '/Users',
        options: Options(
          headers: {
            'X-Emby-Token': apiKey,
            'Content-Type': 'application/json',
            'User-Agent':
                'Doudou-Flutter/$_appVersion (${kIsWeb ? 'Web' : defaultTargetPlatform.name})',
          },
        ),
      );

      if (usersResponse.statusCode == 200 &&
          usersResponse.data is List &&
          (usersResponse.data as List).isNotEmpty) {
        // Use the first user (usually admin) or find the first non-disabled user
        final users = usersResponse.data as List;
        Map<String, dynamic>? selectedUser;

        for (final user in users) {
          if (user['Policy'] != null && user['Policy']['IsDisabled'] != true) {
            selectedUser = user;
            break;
          }
        }

        selectedUser ??= users.first;

        _server = JellyfinServer(
          serverUrl: serverUrl,
          userId: selectedUser!['Id'],
          accessToken: apiKey,
          apiKey: apiKey,
          username: selectedUser['Name'] ?? 'API User',
        );

        _dio.options.headers['X-Emby-Token'] = apiKey;

        return true;
      } else {
        return false;
      }
    } catch (e) {
      // API key authentication error
    }
    return false;
  }

  /// Check if Quick Connect is enabled on the server
  Future<bool> isQuickConnectEnabled(String serverUrl) async {
    try {
      final response = await _dio.get(
        '$serverUrl/QuickConnect/Enabled',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'User-Agent':
                'Doudou-Flutter/$_appVersion (${kIsWeb ? 'Web' : defaultTargetPlatform.name})',
          },
          extra: {'skipAuth': true},
        ),
      );

      if (response.statusCode == 200) {
        // Response is a boolean
        return response.data == true;
      }
    } catch (e) {
      // Quick Connect availability check error
    }
    return false;
  }

  /// Initiate a Quick Connect session and get the code
  Future<Map<String, dynamic>?> initiateQuickConnect(String serverUrl) async {
    try {
      final response = await _dio.post(
        '$serverUrl/QuickConnect/Initiate',
        options: Options(
          headers: {
            'X-Emby-Authorization':
                'MediaBrowser Client="Doudou", Device="Flutter", DeviceId="doudou-flutter", Version="$_appVersion"',
            'Content-Type': 'application/json',
            'User-Agent':
                'Doudou-Flutter/$_appVersion (${kIsWeb ? 'Web' : defaultTargetPlatform.name})',
          },
          extra: {'skipAuth': true},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        return {
          'secret': response.data['Secret'],
          'code': response.data['Code'],
        };
      }
    } catch (e) {
      // Quick Connect initiation error
    }
    return null;
  }

  /// Check the status of a Quick Connect session
  Future<Map<String, dynamic>?> checkQuickConnectStatus(
    String serverUrl,
    String secret,
  ) async {
    try {
      final response = await _dio.get(
        '$serverUrl/QuickConnect/Connect',
        queryParameters: {'secret': secret},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'User-Agent':
                'Doudou-Flutter/$_appVersion (${kIsWeb ? 'Web' : defaultTargetPlatform.name})',
          },
          extra: {'skipAuth': true},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        return {
          'authenticated': response.data['Authenticated'] == true,
          'secret': response.data['Secret'],
        };
      }
    } catch (e) {
      // Quick Connect status check error
    }
    return null;
  }

  /// Complete Quick Connect authentication after user authorizes
  Future<bool> authenticateWithQuickConnect(
    String serverUrl,
    String secret,
  ) async {
    try {
      _dio.options.baseUrl = serverUrl;
      // Clear any existing auth headers from previous sessions
      _dio.options.headers.remove('X-Emby-Token');

      final response = await _dio.post(
        '/Users/AuthenticateWithQuickConnect',
        data: {'Secret': secret},
        options: Options(
          headers: {
            'X-Emby-Authorization':
                'MediaBrowser Client="Doudou", Device="Flutter", DeviceId="doudou-flutter", Version="$_appVersion"',
            'Content-Type': 'application/json',
            'User-Agent':
                'Doudou-Flutter/$_appVersion (${kIsWeb ? 'Web' : defaultTargetPlatform.name})',
          },
          extra: {'skipAuth': true},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        _server = JellyfinServer(
          serverUrl: serverUrl,
          userId: data['User']['Id'],
          accessToken: data['AccessToken'],
          username: data['User']['Name'],
        );

        _dio.options.headers['X-Emby-Token'] = _server!.accessToken;

        return true;
      }
    } catch (e) {
      // Quick Connect authentication error
    }
    return false;
  }

  @override
  Future<List<Album>> getAlbums({
    String? libraryId,
    int? limit,
    int? startIndex,
  }) async {
    if (_server == null) {
      throw Exception('Server not configured');
    }

    try {
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
        return items.map((item) => Album.fromJson(item)).toList();
      }
    } catch (e) {
      // Error fetching albums
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
          'Fields':
              'PrimaryImageAspectRatio,ImageTags,Artists,Album,AlbumId,IndexNumber,RunTimeTicks,UserData',
          'SortBy': 'IndexNumber',
          'SortOrder': 'Ascending',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> items = response.data['Items'];
        return items.map((item) => Track.fromJson(item)).toList();
      }
    } catch (e) {
      // Error fetching album tracks
    }
    return [];
  }

  @override
  Future<List<Track>> getAllTracks({int? maxTracks}) async {
    if (_server == null) throw Exception('Server not configured');

    try {
      final response = await _dio.get(
        '/Users/${_server!.userId}/Items',
        queryParameters: {
          'IncludeItemTypes': 'Audio',
          'Recursive': true,
          'Fields':
              'PrimaryImageAspectRatio,ImageTags,Artists,Album,AlbumId,IndexNumber,RunTimeTicks,UserData',
          'SortBy': 'Album,IndexNumber',
          'SortOrder': 'Ascending',
          'Limit':
              maxTracks ??
              50000, // Use provided limit or high default for all tracks
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> items = response.data['Items'];
        return items.map((item) => Track.fromJson(item)).toList();
      }
    } catch (e) {
      // Error fetching all tracks
    }
    return [];
  }

  @override
  Future<List<Track>> getStarredTracks() async {
    return getFavoriteTracks();
  }

  @override
  Future<List<Album>> getStarredAlbums() async {
    return getFavoriteAlbums();
  }

  @override
  Future<List<Artist>> getStarredArtists() async {
    return getFavoriteArtists();
  }

  @override
  Future<List<Artist>> getArtists({
    String? libraryId,
    int? limit,
    int? startIndex,
  }) async {
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
      // Error fetching artists
    }
    return [];
  }

  @override
  Future<List<Playlist>> getPlaylists() async {
    if (_server == null) throw Exception('Server not configured');

    try {
      final url = '/Users/${_server!.userId}/Items';
      final queryParams = {
        'IncludeItemTypes': 'Playlist',
        'Recursive': true,
        'Fields': 'PrimaryImageAspectRatio,ImageTags,ChildCount',
        'SortBy': 'SortName',
        'SortOrder': 'Ascending',
      };

      final response = await _dio.get(url, queryParameters: queryParams);

      if (response.statusCode == 200) {
        final List<dynamic> items = response.data['Items'];
        final playlists = items.map((item) => Playlist.fromJson(item)).toList();
        return playlists;
      }
    } catch (e) {
      // Error fetching playlists
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
          'Fields':
              'PrimaryImageAspectRatio,ImageTags,Artists,Album,AlbumId,IndexNumber,RunTimeTicks,UserData',
          'SortBy': 'IndexNumber',
          'SortOrder': 'Ascending',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> items = response.data['Items'];
        return items.map((item) => Track.fromJson(item)).toList();
      }
    } catch (e) {
      // Error fetching playlist tracks
    }
    return [];
  }

  // Simple cache for image URLs to reduce repeated generations
  final Map<String, String> _imageUrlCache = <String, String>{};

  @override
  String getImageUrl(
    String itemId, {
    String type = 'Primary',
    int? width,
    int? height,
  }) {
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

    final queryString = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';

    // Remove trailing slash from serverUrl to prevent double slashes
    final baseUrl = _server!.serverUrl.endsWith('/')
        ? _server!.serverUrl.substring(0, _server!.serverUrl.length - 1)
        : _server!.serverUrl;

    final imageUrl = '$baseUrl/Items/$itemId/Images/$type$queryString';

    // Cache the generated URL
    _imageUrlCache[cacheKey] = imageUrl;

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
      'Container':
          'mp3,aac,m4a,flac,webm,mp4,ogg', // Specify supported containers
      'AudioCodec': 'mp3,aac,flac,vorbis,opus', // Specify supported codecs
      'AudioBitRate':
          bitrate?.toString() ??
          '320000', // Use provided bitrate or default to high quality
      'MaxAudioChannels': '2', // Stereo
      'TranscodingContainer': 'mp3', // Fallback container
      'TranscodingProtocol': 'http', // Use HTTP protocol
    };

    final queryString = params.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');

    // Remove trailing slash from serverUrl to prevent double slashes
    final baseUrl = _server!.serverUrl.endsWith('/')
        ? _server!.serverUrl.substring(0, _server!.serverUrl.length - 1)
        : _server!.serverUrl;

    final streamUrl = '$baseUrl/Audio/$itemId/stream?$queryString';

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
    final directUrl =
        '$baseUrl/Items/$itemId/Download?api_key=${_server!.accessToken}';

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
    final universalUrl =
        '$baseUrl/Audio/$itemId/universal?UserId=${_server!.userId}&DeviceId=doudou-flutter&api_key=${_server!.accessToken}';

    return universalUrl;
  }

  @override
  Future<bool> toggleFavorite(String itemId, bool isFavorite) async {
    if (_server == null) throw Exception('Server not configured');

    try {
      final method = isFavorite ? 'DELETE' : 'POST';
      final url = '/Users/${_server!.userId}/FavoriteItems/$itemId';

      final response = await _dio.request(
        url,
        options: Options(method: method),
      );

      final success = response.statusCode == 200 || response.statusCode == 204;

      return success;
    } catch (e) {
      // Error toggling favorite
      return false;
    }
  }

  Future<Playlist?> createPlaylist(String name) async {
    if (_server == null) throw Exception('Server not configured');

    try {
      final response = await _dio.post(
        '/Playlists',
        data: {'Name': name, 'MediaType': 'Audio', 'UserId': _server!.userId},
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
      // Error creating playlist
    }
    return null;
  }

  Future<bool> addToPlaylist(String playlistId, String trackId) async {
    if (_server == null) throw Exception('Server not configured');

    try {
      final response = await _dio.post(
        '/Playlists/$playlistId/Items',
        queryParameters: {'Ids': trackId, 'UserId': _server!.userId},
      );

      return response.statusCode ==
          204; // Jellyfin returns 204 for successful additions
    } catch (e) {
      // Error adding track to playlist
      return false;
    }
  }

  Future<bool> renamePlaylist(String playlistId, String newName) async {
    if (_server == null) throw Exception('Server not configured');

    try {
      // Get the current playlist to preserve other properties
      final currentPlaylist = await _dio.get(
        '/Users/${_server!.userId}/Items/$playlistId',
      );

      if (currentPlaylist.statusCode != 200) {
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
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      bool success = response.statusCode == 204 || response.statusCode == 200;

      return success;
    } catch (e) {
      // Error renaming playlist
      return false;
    }
  }

  Future<bool> removePlaylist(String playlistId) async {
    if (_server == null) throw Exception('Server not configured');

    try {
      final response = await _dio.delete('/Items/$playlistId');

      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      // Error removing playlist
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
      // Error validating credentials
      return false;
    }
  }

  /// Attempt to re-authenticate using stored credentials
  Future<bool> refreshAuthentication() async {
    if (_server == null) {
      return false;
    }

    // For Jellyfin, we need to get fresh credentials from storage since we don't store the password
    // This method will be called by AppState when it has access to stored credentials
    return false;
  }

  /// Re-authenticate with provided credentials (called from AppState)
  Future<bool> reauthenticateWithCredentials(
    String username,
    String password,
  ) async {
    if (_server == null) return false;

    try {
      final response = await _dio.post(
        '/Users/AuthenticateByName',
        data: {'Username': username, 'Pw': password},
        options: Options(
          headers: {
            'X-Emby-Authorization':
                'MediaBrowser Client="Doudou", Device="Flutter", DeviceId="doudou-flutter", Version="$_appVersion"',
            'Content-Type': 'application/json',
            'User-Agent':
                'Doudou-Flutter/$_appVersion (${kIsWeb ? 'Web' : defaultTargetPlatform.name})',
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

        return true;
      }
    } catch (e) {
      // Re-authentication failed
    }
    return false;
  }

  /// Internal method to refresh token using stored credentials
  Future<bool> _refreshToken() async {
    if (_server == null ||
        _server!.username == null ||
        _server!.password == null) {
      return false;
    }

    try {
      final response = await _dio.post(
        '/Users/AuthenticateByName',
        data: {'Username': _server!.username, 'Pw': _server!.password},
        options: Options(
          headers: {
            'X-Emby-Authorization':
                'MediaBrowser Client="Doudou", Device="Flutter", DeviceId="doudou-flutter", Version="$_appVersion"',
            'Content-Type': 'application/json',
            'User-Agent':
                'Doudou-Flutter/$_appVersion (${kIsWeb ? 'Web' : defaultTargetPlatform.name})',
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

        return true;
      }
    } catch (e) {
      // Token refresh failed
    }
    return false;
  }

  @override
  JellyfinServer? get currentServer => _server;

  // Validate server configuration for stream URL generation
  bool _isServerConfigurationValid() {
    if (_server == null) {
      return false;
    }

    if (_server!.serverUrl.isEmpty) {
      return false;
    }

    if (_server!.userId == null || _server!.userId!.isEmpty) {
      return false;
    }

    if (_server!.accessToken == null || _server!.accessToken!.isEmpty) {
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

    final simpleUrl =
        '$baseUrl/Audio/$itemId/stream.mp3?api_key=${_server!.accessToken}';

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

    final downloadUrl =
        '$baseUrl/Items/$itemId/Download?api_key=${_server!.accessToken}';

    return downloadUrl;
  }

  // Get authentication headers for HTTP requests
  Future<Map<String, String>> getAuthHeaders() async {
    if (_server == null) return {};

    return {
      'X-Emby-Token': _server!.accessToken ?? '',
      'X-Emby-Authorization':
          'MediaBrowser UserId="${_server!.userId}", Client="doudou-flutter", Device="Flutter", DeviceId="doudou-flutter", Version="$_appVersion"',
    };
  }

  @override
  Future<List<Library>> getLibraries() async {
    if (_server == null) throw Exception('Server not configured');

    try {
      final response = await _dio.get(
        '/Users/${_server!.userId}/Views',
        queryParameters: {'IncludeExternalContent': false},
      );

      if (response.statusCode == 200) {
        final List<dynamic> items = response.data['Items'];
        return items
            .where((item) => item['CollectionType'] == 'music')
            .map((item) => Library.fromJson(item))
            .toList();
      }
    } catch (e) {
      // Error fetching libraries
    }
    return [];
  }

  @override
  Future<List<Track>> getTracks({
    String? libraryId,
    String? parentId,
    int? limit,
    int? startIndex,
  }) async {
    if (_server == null) throw Exception('Server not configured');

    try {
      final params = <String, dynamic>{
        'IncludeItemTypes': 'Audio',
        'Recursive': true,
        'Fields':
            'PrimaryImageAspectRatio,ImageTags,Artists,Album,AlbumId,IndexNumber,RunTimeTicks,UserData',
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
      // Error fetching tracks
    }
    return [];
  }

  /// Get all favorite/starred tracks from the library
  Future<List<Track>> getFavoriteTracks() async {
    if (_server == null) throw Exception('Server not configured');

    try {
      final response = await _dio.get(
        '/Users/${_server!.userId}/Items',
        queryParameters: {
          'IncludeItemTypes': 'Audio',
          'Recursive': true,
          'Filters': 'IsFavorite',
          'Fields':
              'PrimaryImageAspectRatio,ImageTags,Artists,Album,AlbumId,IndexNumber,RunTimeTicks,UserData',
          'SortBy': 'Album,IndexNumber',
          'SortOrder': 'Ascending',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> items = response.data['Items'];
        return items.map((item) => Track.fromJson(item)).toList();
      }
    } catch (e) {
      // Error fetching favorite tracks
    }
    return [];
  }

  /// Get all favorite/starred albums from the library
  Future<List<Album>> getFavoriteAlbums() async {
    if (_server == null) throw Exception('Server not configured');

    try {
      final response = await _dio.get(
        '/Users/${_server!.userId}/Items',
        queryParameters: {
          'IncludeItemTypes': 'MusicAlbum',
          'Recursive': true,
          'Filters': 'IsFavorite',
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
      // Error fetching favorite albums
    }
    return [];
  }

  /// Get all favorite/starred artists from the library
  Future<List<Artist>> getFavoriteArtists() async {
    if (_server == null) throw Exception('Server not configured');

    try {
      final response = await _dio.get(
        '/Users/${_server!.userId}/Items',
        queryParameters: {
          'IncludeItemTypes': 'MusicArtist',
          'Recursive': true,
          'Filters': 'IsFavorite',
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
      // Error fetching favorite artists
    }
    return [];
  }

  @override
  Future<SearchResults> search(
    String query, {
    List<String>? includeItemTypes,
    int? limit,
  }) async {
    if (_server == null) throw Exception('Server not configured');

    try {
      final params = <String, dynamic>{
        'SearchTerm': query,
        'IncludeItemTypes':
            includeItemTypes?.join(',') ?? 'MusicAlbum,MusicArtist,Audio',
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
      // Error searching
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
      // Error getting server info
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
    // Return multiple Jellyfin stream URLs in order of preference for fallback
    // Prioritize direct download since it works most reliably
    final urls = [
      getDirectStreamUrl(trackId), // Direct download URL (most reliable)
      getSimpleStreamUrl(trackId), // Simple stream format
      getMinimalStreamUrl(trackId), // Minimal params format
      getStreamUrl(trackId), // Primary transcoded stream URL
      getUniversalStreamUrl(trackId), // Universal stream URL
    ].where((url) => url.isNotEmpty).toList(); // Filter out empty URLs

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
