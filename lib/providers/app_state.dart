import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import '../models/jellyfin_models.dart';
import '../services/players/jellyfin_service.dart';
import '../services/media_service_manager.dart';
import '../services/base_service.dart';
import '../services/audio_service_integration.dart';
import '../services/cache_service.dart';
import '../services/image_cache_manager.dart';
import '../services/download_service.dart';
import '../services/logging_service.dart';

class AppState extends ChangeNotifier {
  final JellyfinService _jellyfinService = JellyfinService();
  late final MediaServiceManager _mediaServiceManager;
  final CacheService _cacheService = CacheService.instance;
  late final DownloadService _downloadService;
  AudioServiceIntegration? _audioHandler;

  // Platform detection helpers (web-safe)
  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _isLinux => !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  bool _isLoggedIn = false;
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isOfflineMode = false;
  bool _isConnected = true;
  String? _errorMessage;
  List<Album> _albums = [];
  List<Artist> _artists = [];
  List<Track> _tracks = [];
  List<Playlist> _playlists = [];
  List<Track> _recentTracks = [];

  bool _normalizeVolumeEnabled = false;
  bool _gaplessPlaybackEnabled = true;
  bool _oledDarkModeEnabled = true;
  bool _showAlbumArtEnabled = true;
  bool _loggingEnabled = false; // Disabled by default
  bool _useDynamicIsle = true; // Enabled by default

  // Debouncing for play/pause to prevent rapid-fire clicking deadlocks
  DateTime? _lastPlayPauseCommand;
  static const Duration _playPauseDebounceDelay = Duration(milliseconds: 300);

  // Theme settings
  ThemeMode _themeMode = ThemeMode.system;
  Color _accentColor = Colors.purple;

  // Locale settings
  Locale? _locale; // null means use system locale

  // Getters
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isOfflineMode => _isOfflineMode;
  bool get isConnected => _isConnected;
  String? get errorMessage => _errorMessage;
  List<Album> get albums => _albums;
  List<Artist> get artists => _artists;
  List<Track> get tracks => _tracks;
  List<Playlist> get playlists => _playlists;
  List<Track> get recentTracks => _recentTracks;
  JellyfinService get jellyfinService => _jellyfinService;
  MediaServiceManager get mediaServiceManager => _mediaServiceManager;
  DownloadService get downloadService => _downloadService;
  // Audio handler getter - returns the appropriate handler for the platform
  dynamic get audioHandler => _audioHandler;

  // Stream getters for the integrated audio system
  Stream<PlayerState>? get playerStateStream =>
      _audioHandler?.playerStateStream;
  Stream<PlaybackState>? get playbackState => _audioHandler?.playbackState;
  Stream<Duration>? get positionStream => _audioHandler?.positionStream;
  Stream<MediaItem?>? get mediaItem => _audioHandler?.mediaItem;
  Stream<Track?>? get currentTrackStream => _audioHandler?.currentTrackStream;

  // Helper method to find a track by ID
  Track? findTrackById(String? trackId) {
    if (trackId == null) return null;
    try {
      return _tracks.firstWhere((track) => track.id == trackId);
    } catch (e) {
      return null;
    }
  }

  // Helper method to get image URLs from the current media service
  String getImageUrl(
    String itemId, {
    String type = 'Primary',
    int? width,
    int? height,
  }) {
    // If itemId is already a full URL (starts with http), return it as-is
    // This handles cases where Plex/Navidrome provide full URLs in imageUrl field
    if (itemId.startsWith('http://') || itemId.startsWith('https://')) {
      return itemId;
    }

    // Otherwise, construct the URL using the media service
    return _mediaServiceManager.getImageUrl(
      itemId,
      type: type,
      width: width,
      height: height,
    );
  }

  bool get normalizeVolumeEnabled => _normalizeVolumeEnabled;
  bool get gaplessPlaybackEnabled => _gaplessPlaybackEnabled;
  bool get useDynamicIsle => _useDynamicIsle;
  bool get oledDarkModeEnabled => _oledDarkModeEnabled;
  bool get showAlbumArtEnabled => _showAlbumArtEnabled;
  bool get loggingEnabled => _loggingEnabled;

  // Theme getters
  ThemeMode get themeMode => _themeMode;
  Color get accentColor => _accentColor;

  // Locale getter
  Locale? get locale => _locale;

  AppState() {
    _mediaServiceManager = MediaServiceManager.withJellyfinService(
      _jellyfinService,
    );
    _downloadService = DownloadService(_jellyfinService);
    // Forward download service notifications to AppState listeners
    _downloadService.addListener(_onDownloadServiceChanged);
    _initializeApp();
  }

  void _onDownloadServiceChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _downloadService.removeListener(_onDownloadServiceChanged);
    super.dispose();
  }

  Future<void> _initializeApp() async {
    _setLoading(true);
    try {
      await _loadUserSettings();
      await _loadSavedServer();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing app: $e');
      }
      _setError('Failed to initialize app: ${e.toString()}');
      // Even if initialization fails, mark as initialized to prevent infinite loading
      _isInitialized = true;
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  void _setupAudioHandlerListeners() {
    if (_audioHandler != null) {
      // Listen to media item changes (track changes)
      _audioHandler!.mediaItem?.listen((mediaItem) {
        // Notify listeners when the current track changes
        notifyListeners();
      });

      // Listen to current track stream changes (more reliable)
      _audioHandler!.currentTrackStream?.listen((track) {
        // Notify listeners when the current track changes directly
        notifyListeners();
      });

      // Listen to playback state changes (for playing/paused status)
      _audioHandler!.playbackState?.listen((playbackState) {
        // Notify listeners when playback state changes
        notifyListeners();
      });
    }
  }

  Future<void> _loadSavedServer() async {
    try {
      // Try to load saved credentials for any server type
      final credentials = await _loadServerCredentials();

      if (credentials != null) {
        final serverType = credentials['serverType']!;
        final serverUrl = credentials['serverUrl']!;
        final authMethod = credentials['authMethod'] ?? 'password';

        if (kDebugMode) {
          print(
            'AppState: Found saved credentials for $serverType server at $serverUrl (auth: $authMethod)',
          );
        }

        // Initialize the appropriate service
        ServerType type;
        switch (serverType) {
          case 'plex':
            type = ServerType.plex;
            break;
          case 'navidrome':
            type = ServerType.navidrome;
            break;
          default:
            type = ServerType.jellyfin;
        }

        _mediaServiceManager.initializeService(type);
        _mediaServiceManager.setServer(serverUrl);

        // Test the connection with saved credentials
        try {
          bool isValid = false;
          
          if (authMethod == 'api_key' && credentials['apiKey'] != null) {
            // API key authentication
            isValid = await _jellyfinService
                .authenticateWithApiKey(serverUrl, credentials['apiKey']!)
                .timeout(const Duration(seconds: 10));
          } else {
            // Username/password authentication
            final identifier = credentials['identifier']!;
            final credential = credentials['credential']!;
            isValid = await _mediaServiceManager
                .authenticate(serverUrl, identifier, credential)
                .timeout(const Duration(seconds: 10));
          }

          if (isValid) {
            if (kDebugMode) {
              print(
                'AppState: Saved credentials validated successfully for $serverType',
              );
            }

            _isLoggedIn = true;
            _isConnected = true;
            _isOfflineMode = false;

            // Initialize cache service first
            await _cacheService.initialize();

            // Initialize new audio system with automatic platform detection
            try {
              final audioService = AudioServiceIntegration.instance;
              await audioService.initialize(_mediaServiceManager);
              _audioHandler = audioService;

              if (kDebugMode) {
                print(
                  'New audio system initialized successfully for platform: ${audioService.platformType}',
                );
              }
            } catch (audioError) {
              if (kDebugMode) {
                print('Failed to initialize new audio system: $audioError');
              }
              // Continue without audio service
              _audioHandler = null;
            }

            notifyListeners();

            // Load initial data in background
            if (kDebugMode) {
              print(
                'Platform.isLinux: $_isLinux, Platform.isAndroid: $_isAndroid, about to load library data...',
              );
            }

            // On Linux, use refreshLibraryData to bypass cache issues that prevent UI updates
            if (_isLinux) {
              if (kDebugMode) {
                print(
                  'AppState: Using refreshLibraryData for Linux platform during initialization to ensure UI updates',
                );
              }
              try {
                await refreshLibraryData();
                if (kDebugMode) {
                  print(
                    'AppState: Linux initialization library loading completed successfully',
                  );
                }
              } catch (e) {
                if (kDebugMode) {
                  print(
                    'AppState: Error during Linux initialization library loading: $e',
                  );
                }
              }
            } else {
              await loadLibraryData();
            }
          } else {
            if (kDebugMode) {
              print(
                'AppState: Saved credentials invalid for $serverType - user needs to re-login',
              );
            }
            // Clear invalid credentials
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('${serverType}_credentials');
            if (serverType == 'jellyfin') {
              await prefs.remove('jellyfin_server'); // Legacy cleanup
            }
            _isLoggedIn = false;
            notifyListeners();
          }
        } catch (authError) {
          if (kDebugMode) {
            print(
              'AppState: Cannot connect to $serverType server, checking for offline mode: $authError',
            );
          }

          // Server is unreachable, but we have credentials - check for offline capability
          if (await _hasDownloadedContent() && serverType == 'jellyfin') {
            // Offline mode only supported for Jellyfin currently
            // Set up server for offline mode using available credentials
            JellyfinServer? server;
            
            if (authMethod == 'api_key' && credentials['apiKey'] != null) {
              // API key auth - create minimal server config
              server = JellyfinServer(
                serverUrl: serverUrl,
                accessToken: credentials['apiKey'],
                apiKey: credentials['apiKey'],
              );
            } else if (credentials['credential'] != null) {
              // Username/password auth - try to parse legacy format
              try {
                final serverData = jsonDecode(credentials['credential']!);
                server = JellyfinServer.fromJson(serverData);
              } catch (_) {
                // Not JSON, just create basic server
                server = JellyfinServer(
                  serverUrl: serverUrl,
                  username: credentials['identifier'],
                );
              }
            }
            
            if (server != null) {
              _jellyfinService.setJellyfinServer(server);

              // Enter offline mode with saved credentials
              _isLoggedIn = true;
              _isConnected = false;
              await _enterOfflineMode();

              // Initialize cache service for offline mode
              await _cacheService.initialize();

              // Initialize new audio system with automatic platform detection
              try {
                final audioService = AudioServiceIntegration.instance;
                await audioService.initialize(_mediaServiceManager);
                _audioHandler = audioService;

                // Apply user settings to the audio handler
                _audioHandler?.setGaplessPlayback(_gaplessPlaybackEnabled);

                // Set up listeners for automatic UI updates
                _setupAudioHandlerListeners();

                if (kDebugMode) {
                  print(
                    'Audio system initialized successfully for offline mode, platform: ${audioService.platformType}',
                  );
                }
              } catch (audioError) {
                if (kDebugMode) {
                  print(
                    'Failed to initialize audio system in offline mode: $audioError',
                  );
                }
                // Continue without audio service
                _audioHandler = null;
              }

              if (kDebugMode) {
                print('Entered offline mode with saved $serverType credentials');
              }
              notifyListeners();
            }
          } else {
            // No downloads available or server type doesn't support offline, clear invalid credentials
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('${serverType}_credentials');
            if (serverType == 'jellyfin') {
              await prefs.remove('jellyfin_server'); // Legacy cleanup
            }
            _isLoggedIn = false;
            notifyListeners();
          }
        }
      } else {
        // Fallback: Try legacy Jellyfin server loading for backward compatibility
        final prefs = await SharedPreferences.getInstance();
        final serverJson = prefs.getString('jellyfin_server');

        if (serverJson != null) {
          if (kDebugMode) {
            print(
              'AppState: Found legacy Jellyfin server data, attempting to restore...',
            );
          }

          final serverData = jsonDecode(serverJson);
          final server = JellyfinServer.fromJson(serverData);
          _jellyfinService.setJellyfinServer(server);

          // Test the connection with saved credentials
          try {
            final isValid = await _jellyfinService
                .validateCredentials()
                .timeout(const Duration(seconds: 10));

            if (isValid) {
              if (kDebugMode) {
                print(
                  'AppState: Legacy Jellyfin credentials validated successfully',
                );
              }

              _isLoggedIn = true;
              _isConnected = true;
              _isOfflineMode = false;

              // Initialize cache service first
              await _cacheService.initialize();

              // Initialize new audio system with automatic platform detection
              try {
                final audioService = AudioServiceIntegration.instance;
                await audioService.initialize(_mediaServiceManager);
                _audioHandler = audioService;

                if (kDebugMode) {
                  print(
                    'Audio system initialized successfully, platform: ${audioService.platformType}',
                  );
                }
              } catch (audioError) {
                if (kDebugMode) {
                  print('Failed to initialize audio system: $audioError');
                }
                // Continue without audio service
                _audioHandler = null;
              }

              // Load library data
              await loadLibraryData();

              if (kDebugMode) {
                print(
                  'AppState: Successfully restored legacy Jellyfin session',
                );
              }
            } else {
              if (kDebugMode) {
                print('AppState: Legacy Jellyfin credentials invalid');
              }
              await prefs.remove('jellyfin_server');
              _isLoggedIn = false;
            }
          } catch (e) {
            if (kDebugMode) {
              print(
                'AppState: Failed to validate legacy Jellyfin credentials: $e',
              );
            }
            _isLoggedIn = false;
          }
        } else {
          if (kDebugMode) {
            print('AppState: No saved server credentials found');
          }
          _isLoggedIn = false;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('AppState: Error loading saved server: $e');
      }
      _isLoggedIn = false;
    }
  }

  Future<bool> login(String serverUrl, String username, String password) async {
    _setLoading(true);
    _clearError();

    try {
      // Ensure serverUrl has protocol
      if (!serverUrl.startsWith('http://') &&
          !serverUrl.startsWith('https://')) {
        serverUrl = 'http://$serverUrl';
      }

      final success = await _jellyfinService.authenticate(
        serverUrl,
        username,
        password,
      );

      if (success) {
        if (kDebugMode) {
          print('AppState: Authentication success, setting up login state...');
        }

        try {
          _isLoggedIn = true;

          // Initialize cache service first
          if (kDebugMode) {
            print('AppState: Initializing cache service...');
          }
          await _cacheService.initialize();
          if (kDebugMode) {
            print('AppState: Cache service initialized successfully');
          }

          // Initialize new audio system with automatic platform detection
          try {
            final audioService = AudioServiceIntegration.instance;
            await audioService.initialize(_mediaServiceManager);
            _audioHandler = audioService;

            // Apply user settings to the audio handler
            _audioHandler?.setGaplessPlayback(_gaplessPlaybackEnabled);

            // Set up listeners for automatic UI updates
            _setupAudioHandlerListeners();

            // Notify listeners after audio handler is ready
            notifyListeners();

            if (kDebugMode) {
              print(
                'Audio system initialized successfully after login, platform: ${audioService.platformType}',
              );
            }
          } catch (audioError) {
            if (kDebugMode) {
              print(
                'Failed to initialize audio system after login: $audioError',
              );
            }
            // Continue without audio service
            _audioHandler = null;
            notifyListeners();
          }

          if (kDebugMode) {
            print('AppState: About to save server and load library data...');
          }

          await _saveServer();

          if (kDebugMode) {
            print(
              'AppState: About to call loadLibraryData after successful login...',
            );
          }

          try {
            // On Linux, use refreshLibraryData to bypass cache issues that prevent UI updates
            if (_isLinux) {
              if (kDebugMode) {
                print(
                  'AppState: Using refreshLibraryData for Linux platform to ensure UI updates',
                );
              }
              await refreshLibraryData();
              if (kDebugMode) {
                print(
                  'AppState: refreshLibraryData completed successfully for Linux',
                );
              }
            } else {
              await loadLibraryData();
              if (kDebugMode) {
                print(
                  'AppState: loadLibraryData completed successfully for non-Linux platforms',
                );
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print('AppState: Exception during library loading: $e');
              print('Stack trace: ${StackTrace.current}');
            }
          }

          _setLoading(false);
          return true;
        } catch (setupError) {
          if (kDebugMode) {
            print('AppState: Exception during login setup: $setupError');
            print('Stack trace: ${StackTrace.current}');
          }
          _setError('Login setup failed: ${setupError.toString()}');
          _setLoading(false);
          return false;
        }
      } else {
        _setError('Authentication failed. Please check your credentials.');
        _setLoading(false);
        return false;
      }
    } on DioException catch (e) {
      // Handle network errors - check if we should enter offline mode
      if (e.error is NetworkException) {
        final networkError = e.error as NetworkException;

        // If we have saved credentials and downloads, offer offline mode
        if (await _hasSavedCredentials() && await _hasDownloadedContent()) {
          await _enterOfflineMode();
          _isLoggedIn = true;
          _setLoading(false);
          return true;
        } else {
          _setError(networkError.message);
        }
      } else {
        // Check for offline mode possibility
        if (await _hasSavedCredentials() && await _hasDownloadedContent()) {
          await _enterOfflineMode();
          _isLoggedIn = true;
          _setLoading(false);
          return true;
        } else {
          _setError(
            'Network error. Please check your connection and try again.',
          );
        }
      }
      _setLoading(false);
      return false;
    } catch (e) {
      // Handle any other unexpected errors
      String errorMessage = 'An unexpected error occurred. Please try again.';

      // Provide more specific error messages for common issues
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('timeout')) {
        errorMessage =
            'Connection timeout. Please check your network and server availability.';
      } else if (errorString.contains('certificate') ||
          errorString.contains('ssl')) {
        errorMessage =
            'SSL certificate error. Please check your server configuration.';
      } else if (errorString.contains('host')) {
        errorMessage =
            'Cannot reach server. Please check the server URL and your network connection.';
      }

      // Check for offline mode possibility
      if (await _hasSavedCredentials() && await _hasDownloadedContent()) {
        await _enterOfflineMode();
        _isLoggedIn = true;
        _setLoading(false);
        return true;
      } else {
        _setError(errorMessage);
        _setLoading(false);
        return false;
      }
    }
  }

  /// Login to Jellyfin using an API key instead of username/password
  Future<bool> loginWithApiKey(String serverUrl, String apiKey) async {
    _setLoading(true);
    _clearError();

    try {
      // Ensure serverUrl has protocol
      if (!serverUrl.startsWith('http://') && !serverUrl.startsWith('https://')) {
        serverUrl = 'http://$serverUrl';
      }

      // Initialize Jellyfin service
      _mediaServiceManager.initializeService(ServerType.jellyfin);

      final success = await _jellyfinService.authenticateWithApiKey(serverUrl, apiKey);

      if (success) {
        if (kDebugMode) {
          print('AppState: API key authentication success for Jellyfin');
        }

        _isLoggedIn = true;

        // Initialize cache service
        await _cacheService.initialize();

        // Initialize new audio system with automatic platform detection
        try {
          final audioService = AudioServiceIntegration.instance;
          await audioService.initialize(_mediaServiceManager);
          _audioHandler = audioService;

          _audioHandler?.setGaplessPlayback(_gaplessPlaybackEnabled);
          _setupAudioHandlerListeners();

          if (kDebugMode) {
            print('Audio system initialized for Jellyfin API key auth');
          }
        } catch (e) {
          if (kDebugMode) {
            print('Failed to initialize audio system: $e');
          }
          _audioHandler = null;
        }

        await _saveServerType('jellyfin');
        await _saveApiKeyCredentials(serverUrl, apiKey);
        await _saveServer();

        // Load library data
        try {
          await loadLibraryData();
        } catch (e) {
          if (kDebugMode) {
            print('Exception during library loading: $e');
          }
        }

        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        _setError('API key authentication failed. Please check your API key.');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      String errorMessage = 'An unexpected error occurred. Please try again.';

      if (e.toString().toLowerCase().contains('timeout')) {
        errorMessage = 'Connection timeout. Please check your network and server availability.';
      } else if (e.toString().toLowerCase().contains('certificate')) {
        errorMessage = 'SSL certificate error. Please check your server configuration.';
      }

      _setError(errorMessage);
      _setLoading(false);
      return false;
    }
  }

  /// Save API key credentials
  Future<void> _saveApiKeyCredentials(String serverUrl, String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_type', 'jellyfin');
    await prefs.setString('server_url', serverUrl);
    await prefs.setString('server_api_key', apiKey);
    await prefs.setString('auth_method', 'api_key');
    
    // Clear any old username/password credentials
    await prefs.remove('server_identifier');
    await prefs.remove('server_credential');

    if (kDebugMode) {
      print('AppState: Saved API key credentials for Jellyfin at $serverUrl');
    }
  }

  Future<bool> loginWithServerType(
    String serverType,
    String serverUrl,
    String identifier,
    String credential,
  ) async {
    _setLoading(true);
    _clearError();

    try {
      // Convert string server type to enum
      ServerType type;
      switch (serverType) {
        case 'plex':
          type = ServerType.plex;
          break;
        case 'navidrome':
          type = ServerType.navidrome;
          break;
        case 'jellyfin':
        default:
          type = ServerType.jellyfin;
          break;
      }

      // Initialize the appropriate service
      _mediaServiceManager.initializeService(type);

      // Ensure serverUrl has protocol for non-Plex services
      if (type != ServerType.plex &&
          !serverUrl.startsWith('http://') &&
          !serverUrl.startsWith('https://')) {
        serverUrl = 'http://$serverUrl';
      }

      final success = await _mediaServiceManager.authenticate(
        serverUrl,
        identifier,
        credential,
      );

      if (success) {
        if (kDebugMode) {
          print(
            'AppState: Multi-service authentication success for $serverType',
          );
        }

        _isLoggedIn = true;

        // Initialize cache service
        await _cacheService.initialize();

        // Initialize new audio system with automatic platform detection
        try {
          final audioService = AudioServiceIntegration.instance;
          await audioService.initialize(_mediaServiceManager);
          _audioHandler = audioService;

          _audioHandler?.setGaplessPlayback(_gaplessPlaybackEnabled);
          _setupAudioHandlerListeners();

          if (kDebugMode) {
            print(
              'Audio system initialized for $serverType, platform: ${audioService.platformType}',
            );
          }
        } catch (e) {
          if (kDebugMode) {
            print('Failed to initialize audio system: $e');
          }
          _audioHandler = null;
        }

        await _saveServerType(serverType);
        await _saveServerCredentials(
          serverType,
          serverUrl,
          identifier,
          credential,
        );
        await _saveServer();

        // Load library data
        try {
          await loadLibraryData();
        } catch (e) {
          if (kDebugMode) {
            print('Exception during library loading: $e');
          }
        }

        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        _setError('Authentication failed. Please check your credentials.');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      String errorMessage = 'An unexpected error occurred. Please try again.';

      if (e.toString().toLowerCase().contains('timeout')) {
        errorMessage =
            'Connection timeout. Please check your network and server availability.';
      } else if (e.toString().toLowerCase().contains('certificate')) {
        errorMessage =
            'SSL certificate error. Please check your server configuration.';
      }

      _setError(errorMessage);
      _setLoading(false);
      return false;
    }
  }

  Future<void> _saveServerType(String serverType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_type', serverType);
  }

  Future<void> _saveServerCredentials(
    String serverType,
    String serverUrl,
    String identifier,
    String credential,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    // Save common server info
    await prefs.setString('server_type', serverType);
    await prefs.setString('server_url', serverUrl);
    await prefs.setString('server_identifier', identifier);
    await prefs.setString('server_credential', credential);

    if (kDebugMode) {
      print('AppState: Saved server credentials for $serverType at $serverUrl');
    }
  }

  Future<Map<String, String>?> _loadServerCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final serverType = prefs.getString('server_type');
      final serverUrl = prefs.getString('server_url');
      final authMethod = prefs.getString('auth_method');
      
      // Check for API key authentication first
      if (authMethod == 'api_key') {
        final apiKey = prefs.getString('server_api_key');
        if (serverType != null && serverUrl != null && apiKey != null) {
          return {
            'serverType': serverType,
            'serverUrl': serverUrl,
            'authMethod': 'api_key',
            'apiKey': apiKey,
          };
        }
      }
      
      // Fall back to username/password authentication
      final identifier = prefs.getString('server_identifier');
      final credential = prefs.getString('server_credential');

      if (serverType != null &&
          serverUrl != null &&
          identifier != null &&
          credential != null) {
        return {
          'serverType': serverType,
          'serverUrl': serverUrl,
          'authMethod': 'password',
          'identifier': identifier,
          'credential': credential,
        };
      }

      if (kDebugMode) {
        print('AppState: No complete server credentials found in storage');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('AppState: Error loading server credentials: $e');
      }
      return null;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    // Clear all server credentials
    await prefs.remove('jellyfin_server'); // Legacy Jellyfin
    await prefs.remove('jellyfin_credentials');
    await prefs.remove('navidrome_credentials');
    await prefs.remove('plex_credentials');

    if (kDebugMode) {
      print('AppState: Cleared all server credentials during logout');
    }

    // Dispose audio handler
    try {
      await _audioHandler?.dispose();
    } catch (e) {
      // Handle platform-specific limitations (e.g., MissingPluginException on Linux)
      if (kDebugMode) {
        print(
          'Audio handler disposal error during logout (this may be expected on some platforms): $e',
        );
      }
    }
    _audioHandler = null;

    _isLoggedIn = false;
    _albums.clear();
    _artists.clear();
    _tracks.clear();
    _playlists.clear();
    _clearError();

    notifyListeners();
  }

  /// Attempt to refresh authentication token and retry failed operations
  Future<bool> _attemptTokenRefresh() async {
    if (!_isLoggedIn) return false;

    final server = _jellyfinService.currentServer;
    if (server == null || server.username == null || server.password == null) {
      if (kDebugMode) {
        print('AppState: Cannot refresh token - missing credentials');
      }
      return false;
    }

    try {
      if (kDebugMode) {
        print('AppState: Attempting to refresh authentication token...');
      }

      final success = await _jellyfinService.reauthenticateWithCredentials(
        server.username!,
        server.password!,
      );

      if (success) {
        // Save the updated server with new token
        await _saveServer();
        if (kDebugMode) {
          print('AppState: Token refresh successful');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('AppState: Token refresh failed');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('AppState: Token refresh error: $e');
      }
      return false;
    }
  }

  /// Handle network reconnection (e.g., after VPN change, network switch)
  Future<void> handleNetworkReconnection() async {
    if (!_isLoggedIn) return;

    if (kDebugMode) {
      print('AppState: Handling network reconnection...');
    }

    try {
      // First, try to validate current credentials
      final isValid = await _jellyfinService.validateCredentials().timeout(
        const Duration(seconds: 15),
      );

      if (isValid) {
        if (kDebugMode) {
          print(
            'AppState: Network reconnection successful - credentials still valid',
          );
        }

        // Credentials are still valid, refresh data
        _isConnected = true;
        _isOfflineMode = false;

        // Reload library data in background
        _loadFreshDataInBackground();
      } else {
        // Credentials invalid, try to refresh token
        if (kDebugMode) {
          print(
            'AppState: Credentials invalid after network change, attempting refresh...',
          );
        }

        final refreshSuccess = await _attemptTokenRefresh();

        if (refreshSuccess) {
          _isConnected = true;
          _isOfflineMode = false;

          // Reload library data in background
          _loadFreshDataInBackground();
        } else {
          if (kDebugMode) {
            print('AppState: Failed to refresh token after network change');
          }

          // Check if we can fall back to offline mode
          if (await _hasDownloadedContent()) {
            _isConnected = false;
            _isOfflineMode = true;
            await _enterOfflineMode();
          } else {
            // No offline content available, user needs to re-login
            logout();
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('AppState: Network reconnection failed: $e');
      }

      // Network still unreachable, check if we can go offline
      if (await _hasDownloadedContent()) {
        _isConnected = false;
        _isOfflineMode = true;
        await _enterOfflineMode();
      }
      // If no offline content, stay in current state and let user retry manually
    }

    notifyListeners();
  }

  Future<void> loadLibraryData() async {
    if (!_isLoggedIn) {
      if (kDebugMode) {
        print('AppState: Cannot load library data - user not logged in');
      }
      return;
    }

    if (kDebugMode) {
      print('AppState: Starting loadLibraryData...');
    }

    _setLoading(true);
    _clearError();

    try {
      if (kDebugMode) {
        print('AppState: Loading cached data...');
      }

      // Try to load from cache first to provide immediate data
      final cachedAlbums = await _cacheService.getCachedAlbums();
      final cachedArtists = await _cacheService.getCachedArtists();
      final cachedTracks = await _cacheService.getCachedTracks();
      final cachedPlaylists = await _cacheService.getCachedPlaylists();

      bool hasValidCache =
          cachedAlbums != null &&
          cachedArtists != null &&
          cachedTracks != null &&
          cachedPlaylists != null;

      if (kDebugMode) {
        print(
          'AppState: Cache check - Albums: ${cachedAlbums?.length}, Artists: ${cachedArtists?.length}, Tracks: ${cachedTracks?.length}, Playlists: ${cachedPlaylists?.length}',
        );
        print('AppState: hasValidCache: $hasValidCache');
      }

      if (hasValidCache) {
        // Use cached data immediately for better user experience
        _albums = cachedAlbums;
        _artists = cachedArtists;
        _tracks = cachedTracks;
        _playlists = cachedPlaylists;

        // Update audio handler with cached media library for Android Auto
        try {
          _audioHandler?.updateMediaLibrary(
            _tracks,
            _albums,
            _artists,
            _playlists,
          );
        } catch (e) {
          if (kDebugMode) {
            print(
              'Warning: Failed to update AudioHandler with cached data: $e',
            );
          }
          // Don't fail completely - UI still works with cached data
        }

        // Load recent tracks now that we have track data
        await _loadRecentTracks();

        _setLoading(false);

        if (kDebugMode) {
          print(
            'Loaded library data from cache - Albums: ${_albums.length}, Artists: ${_artists.length}, Tracks: ${_tracks.length}, Playlists: ${_playlists.length}',
          );
        }

        // Load fresh data in background and update cache
        _loadFreshDataInBackground();
      } else {
        if (kDebugMode) {
          print('AppState: No valid cache found, loading fresh data...');
        }
        // No cache available - must load fresh data
        await _loadFreshData();
      }
    } catch (e) {
      if (kDebugMode) {
        print('AppState: Error in loadLibraryData: $e');
      }

      // Provide user-friendly error messages based on error type
      String userMessage = 'Failed to load library';
      if (e.toString().contains('401') ||
          e.toString().contains('unauthorized')) {
        // Attempt token refresh before giving up
        if (kDebugMode) {
          print(
            'AppState: Authentication error loading library, attempting token refresh...',
          );
        }

        final refreshSuccess = await _attemptTokenRefresh();
        if (refreshSuccess) {
          // Token refresh successful, try loading library again
          try {
            await _loadFreshData();
            _setLoading(false);
            return; // Success, exit without error
          } catch (retryError) {
            if (kDebugMode) {
              print('AppState: Retry after token refresh failed: $retryError');
            }
            // Fall through to handle as normal error
          }
        }

        userMessage = 'Authentication failed. Please log in again.';
        // Only logout if token refresh fails
        if (!refreshSuccess) {
          logout();
        }
      } else if (e.toString().contains('timeout') ||
          e.toString().contains('connection')) {
        userMessage =
            'Connection timeout. Please check your network and server.';
      } else if (e.toString().contains('404') ||
          e.toString().contains('not found')) {
        userMessage = 'Server not found. Please check your server URL.';
      } else if (e.toString().contains('500') ||
          e.toString().contains('server error')) {
        userMessage = 'Server error. Please try again later.';
      }

      _setError(userMessage);
      _setLoading(false);

      // For Android Auto safety, ensure we have empty but valid collections
      if (_albums.isEmpty &&
          _artists.isEmpty &&
          _tracks.isEmpty &&
          _playlists.isEmpty) {
        _albums = <Album>[];
        _artists = <Artist>[];
        _tracks = <Track>[];
        _playlists = <Playlist>[];

        // Update audio handler with empty but safe data
        try {
          _audioHandler?.updateMediaLibrary(
            _tracks,
            _albums,
            _artists,
            _playlists,
          );
        } catch (audioError) {
          if (kDebugMode) {
            print(
              'Warning: Failed to update AudioHandler with empty data: $audioError',
            );
          }
        }
      }
    }
  }

  /// Force refresh library data from server, bypassing cache
  Future<void> refreshLibraryData() async {
    if (!_isLoggedIn) {
      if (kDebugMode) {
        print('AppState: Cannot refresh library data - user not logged in');
      }
      return;
    }

    if (kDebugMode) {
      print('AppState: Force refreshing library data from server...');
    }

    _setLoading(true);
    _clearError();

    try {
      // Skip cache and load fresh data directly
      await _loadFreshData();
      _setLoading(false);
    } catch (e) {
      if (kDebugMode) {
        print('AppState: Error during force refresh: $e');
      }

      // Provide user-friendly error messages based on error type
      String userMessage = 'Failed to refresh library';
      if (e.toString().contains('401') ||
          e.toString().contains('unauthorized')) {
        // Attempt token refresh before giving up
        if (kDebugMode) {
          print(
            'AppState: Authentication error during refresh, attempting token refresh...',
          );
        }

        final refreshSuccess = await _attemptTokenRefresh();
        if (refreshSuccess) {
          // Token refresh successful, try refreshing library again
          try {
            await _loadFreshData();
            _setLoading(false);
            return; // Success, exit without error
          } catch (retryError) {
            if (kDebugMode) {
              print('AppState: Retry after token refresh failed: $retryError');
            }
            // Fall through to handle as normal error
          }
        }

        userMessage = 'Authentication failed. Please log in again.';
        // Only logout if token refresh fails
        if (!refreshSuccess) {
          logout();
        }
      } else if (e.toString().contains('timeout') ||
          e.toString().contains('connection')) {
        userMessage =
            'Connection timeout. Please check your network and server.';
      } else if (e.toString().contains('404') ||
          e.toString().contains('not found')) {
        userMessage = 'Server not found. Please check your server URL.';
      } else if (e.toString().contains('500') ||
          e.toString().contains('server error')) {
        userMessage = 'Server error. Please try again later.';
      }

      _setError(userMessage);
      _setLoading(false);

      // Re-throw the error so the UI can handle it
      rethrow;
    }
  }

  Future<void> _loadFreshData() async {
    try {
      if (kDebugMode) {
        print('AppState: Loading fresh library data from server...');
      }

      // Load all library data concurrently with individual error handling
      final List<Future> futures = [
        _mediaServiceManager.getAlbums().catchError((e) {
          if (kDebugMode) {
            print('Warning: Failed to load albums: $e');
          }
          return <Album>[];
        }),
        _mediaServiceManager.getArtists().catchError((e) {
          if (kDebugMode) {
            print('Warning: Failed to load artists: $e');
          }
          return <Artist>[];
        }),
        _mediaServiceManager.getTracks(limit: 1000).catchError((e) {
          if (kDebugMode) {
            print('Warning: Failed to load tracks: $e');
          }
          return <Track>[];
        }),
        _mediaServiceManager.getPlaylists().catchError((e) {
          if (kDebugMode) {
            print('Warning: Failed to load playlists: $e');
          }
          return <Playlist>[];
        }),
      ];

      final results = await Future.wait(futures);

      _albums = results[0] as List<Album>;
      _artists = results[1] as List<Artist>;
      _tracks = results[2] as List<Track>;
      _playlists = results[3] as List<Playlist>;

      if (kDebugMode) {
        print(
          'AppState: Loaded fresh data - Albums: ${_albums.length}, Artists: ${_artists.length}, Tracks: ${_tracks.length}, Playlists: ${_playlists.length}',
        );
      }

      // Update audio handler with media library for Android Auto browsing
      try {
        _audioHandler?.updateMediaLibrary(
          _tracks,
          _albums,
          _artists,
          _playlists,
        );

        if (kDebugMode) {
          print(
            'AppState: Updated AudioHandler MediaBrowser with fresh library data',
          );
        }
      } catch (e) {
        if (kDebugMode) {
          print('Warning: Failed to update AudioHandler: $e');
        }
        // Don't fail completely - the data is still loaded in AppState
      }

      // Cache the fresh data with individual error handling
      final cacheFutures = [
        _cacheService.cacheAlbums(_albums).catchError((e) {
          if (kDebugMode) {
            print('Warning: Failed to cache albums: $e');
          }
        }),
        _cacheService.cacheArtists(_artists).catchError((e) {
          if (kDebugMode) {
            print('Warning: Failed to cache artists: $e');
          }
        }),
        _cacheService.cacheTracks(_tracks).catchError((e) {
          if (kDebugMode) {
            print('Warning: Failed to cache tracks: $e');
          }
        }),
        _cacheService.cachePlaylists(_playlists).catchError((e) {
          if (kDebugMode) {
            print('Warning: Failed to cache playlists: $e');
          }
        }),
      ];

      await Future.wait(cacheFutures);

      // Load recent tracks now that we have fresh track data
      await _loadRecentTracks();

      _setLoading(false);

      if (kDebugMode) {
        print('AppState: Successfully loaded and cached fresh library data');
      }
    } catch (e) {
      if (kDebugMode) {
        print('AppState: Critical error in _loadFreshData: $e');
      }

      _setLoading(false);

      // Ensure we have safe empty collections for Android Auto
      if (_albums.isEmpty &&
          _artists.isEmpty &&
          _tracks.isEmpty &&
          _playlists.isEmpty) {
        _albums = <Album>[];
        _artists = <Artist>[];
        _tracks = <Track>[];
        _playlists = <Playlist>[];

        try {
          _audioHandler?.updateMediaLibrary(
            _tracks,
            _albums,
            _artists,
            _playlists,
          );
        } catch (audioError) {
          if (kDebugMode) {
            print(
              'Warning: Failed to update AudioHandler with empty collections: $audioError',
            );
          }
        }
      }

      // Re-throw for parent error handling
      rethrow;
    }
  }

  Future<void> _loadFreshDataInBackground() async {
    try {
      if (kDebugMode) {
        print('AppState: Loading fresh data in background...');
      }

      await _loadFreshData();

      // Notify listeners to update UI with fresh data
      notifyListeners();

      if (kDebugMode) {
        print('AppState: Background data refresh completed successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('AppState: Background data refresh failed: $e');
      }

      // Handle specific error types for background refresh
      if (e.toString().contains('401') ||
          e.toString().contains('unauthorized')) {
        if (kDebugMode) {
          print(
            'AppState: Authentication error in background refresh - attempting token refresh',
          );
        }

        // Attempt token refresh in background
        final refreshSuccess = await _attemptTokenRefresh();
        if (refreshSuccess) {
          if (kDebugMode) {
            print(
              'AppState: Token refresh successful, retrying background data load',
            );
          }
          // Try loading fresh data again after token refresh
          try {
            await _loadFreshData();
            notifyListeners();
            return; // Success, exit early
          } catch (retryError) {
            if (kDebugMode) {
              print(
                'AppState: Retry after token refresh failed in background: $retryError',
              );
            }
          }
        } else {
          if (kDebugMode) {
            print(
              'AppState: Token refresh failed in background - user may need to re-login',
            );
          }
        }
        // Don't logout in background refresh - let user discover the issue naturally
      }

      // Don't show error to user since we have cached data and this is background
      // But do set connection status if it's a network issue
      if (e.toString().contains('timeout') ||
          e.toString().contains('connection')) {
        _isConnected = false;
        notifyListeners();

        // Try to restore connection status after some time
        Future.delayed(const Duration(minutes: 1), () {
          _isConnected = true;
          notifyListeners();
        });
      }
    }
  }

  /// Refresh tracks in background to sync favorite status
  Future<void> _refreshTracksInBackground() async {
    try {
      if (kDebugMode) {
        print(
          'AppState: Refreshing tracks in background to sync favorite status...',
        );
      }

      // Get fresh tracks from the media service
      final freshTracks = await _mediaServiceManager.getTracks();

      if (freshTracks.isNotEmpty) {
        // Update tracks with fresh data (including favorite status)
        _tracks = freshTracks;

        // Update cache
        await _cacheService.cacheTracks(freshTracks);

        // Notify listeners to update UI
        notifyListeners();

        if (kDebugMode) {
          print(
            'AppState: Tracks refreshed successfully with ${freshTracks.length} tracks',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('AppState: Failed to refresh tracks in background: $e');
      }
      // Don't show error to user - this is a background operation
    }
  }

  Future<List<Track>> getAlbumTracks(String albumId) async {
    try {
      if (kDebugMode) {
        print('AppState.getAlbumTracks called for albumId: $albumId');
        print(
          'MediaServiceManager type: ${_mediaServiceManager.currentServerType}',
        );
      }

      // Try cache first
      final cachedTracks = await _cacheService.getCachedAlbumTracks(albumId);
      if (cachedTracks != null) {
        if (kDebugMode) {
          print(
            'Loaded ${cachedTracks.length} album tracks from cache for album: $albumId',
          );
        }

        // Load fresh data in background and update cache
        _loadAlbumTracksInBackground(albumId);

        return cachedTracks;
      }

      if (kDebugMode) {
        print(
          'No cached tracks found, calling MediaServiceManager.getTracks for albumId: $albumId',
        );
      }

      // Load fresh data
      final tracks = await _mediaServiceManager.getTracks(parentId: albumId);

      if (kDebugMode) {
        print(
          'MediaServiceManager returned ${tracks.length} tracks for albumId: $albumId',
        );
        if (tracks.isNotEmpty) {
          print('Sample track from service: ${tracks.first.name}');
        }
      }

      // Cache the tracks
      await _cacheService.cacheAlbumTracks(albumId, tracks);

      return tracks;
    } catch (e) {
      if (kDebugMode) {
        print('ERROR in AppState.getAlbumTracks for albumId $albumId: $e');
      }
      _setError('Failed to load tracks: ${e.toString()}');
      return [];
    }
  }

  Future<void> _loadAlbumTracksInBackground(String albumId) async {
    try {
      final tracks = await _mediaServiceManager.getTracks(parentId: albumId);
      await _cacheService.cacheAlbumTracks(albumId, tracks);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to refresh album tracks in background: $e');
      }
    }
  }

  Future<List<Track>> getPlaylistTracks(String playlistId) async {
    try {
      if (kDebugMode) {
        print('getPlaylistTracks called for playlist: $playlistId');
      }

      // Try cache first
      final cachedTracks = await _cacheService.getCachedPlaylistTracks(
        playlistId,
      );
      if (cachedTracks != null) {
        if (kDebugMode) {
          print(
            'Loaded ${cachedTracks.length} playlist tracks from cache for playlist: $playlistId',
          );
        }

        // Load fresh data in background and update cache
        _loadPlaylistTracksInBackground(playlistId);

        return cachedTracks;
      }

      if (kDebugMode) {
        print(
          'No cached playlist tracks found, loading fresh data for playlist: $playlistId',
        );
      }

      // Load fresh data
      final tracks = await _mediaServiceManager.getPlaylistTracks(playlistId);

      if (kDebugMode) {
        print(
          'Loaded ${tracks.length} fresh playlist tracks for playlist: $playlistId',
        );
      }

      // Cache the tracks
      await _cacheService.cachePlaylistTracks(playlistId, tracks);

      return tracks;
    } catch (e) {
      if (kDebugMode) {
        print('Error in getPlaylistTracks: $e');
      }
      _setError('Failed to load playlist tracks: ${e.toString()}');
      return [];
    }
  }

  Future<void> _loadPlaylistTracksInBackground(String playlistId) async {
    try {
      if (kDebugMode) {
        print(
          'Loading fresh playlist tracks in background for playlist: $playlistId',
        );
      }

      final tracks = await _mediaServiceManager.getPlaylistTracks(playlistId);
      await _cacheService.cachePlaylistTracks(playlistId, tracks);

      if (kDebugMode) {
        print(
          'Successfully refreshed ${tracks.length} playlist tracks in background for playlist: $playlistId',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print(
          'Failed to refresh playlist tracks in background for playlist $playlistId: $e',
        );
      }
    }
  }

  // Audio playback methods
  Future<void> playTrack(Track track) async {
    if (kDebugMode) {
      print('AppState.playTrack called for: ${track.name} (ID: ${track.id})');
      print('AudioHandler available: ${_audioHandler != null}');
      print(
        'MediaServiceManager current service: ${_mediaServiceManager.currentService}',
      );
      print(
        'MediaServiceManager server type: ${_mediaServiceManager.currentServerType}',
      );
    }

    if (_audioHandler != null) {
      await _audioHandler!.playTrack(track);
      _addToRecentTracks(track);
      notifyListeners();
    } else {
      if (kDebugMode) {
        print('ERROR: AudioHandler is null, cannot play track');
      }
    }
  }

  Future<void> playPlaylist(List<Track> tracks, int startIndex) async {
    if (kDebugMode) {
      print('=== APP_STATE.playPlaylist() CALLED ===');
      print('Tracks: ${tracks.length}');
      print('Start index: $startIndex');
      print('Current service: ${_mediaServiceManager.currentServerType}');
      if (tracks.isNotEmpty) {
        print('First track: ${tracks[0].name} (ID: ${tracks[0].id})');
      }
      print('AudioHandler exists: ${_audioHandler != null}');
    }

    if (_audioHandler != null) {
      await _audioHandler!.playPlaylist(tracks, startIndex);
      notifyListeners();

      if (kDebugMode) {
        print('=== APP_STATE.playPlaylist() COMPLETED ===');
      }
    } else {
      if (kDebugMode) {
        print('ERROR: AudioHandler is null in AppState.playPlaylist()');
      }
    }
  }

  Future<void> playPause() async {
    if (kDebugMode) {
      print('=== AppState.playPause() called ===');
    }

    // Debounce rapid play/pause commands to prevent deadlocks
    final now = DateTime.now();
    if (_lastPlayPauseCommand != null &&
        now.difference(_lastPlayPauseCommand!) < _playPauseDebounceDelay) {
      if (kDebugMode) {
        print(
          'Play/pause command debounced - too recent (${now.difference(_lastPlayPauseCommand!).inMilliseconds}ms ago)',
        );
      }
      return;
    }
    _lastPlayPauseCommand = now;

    if (_audioHandler != null) {
      // CRITICAL FIX: Use userIntendedPlaying instead of playbackState.playing to avoid race conditions
      // playbackState.playing can lag behind the actual command completion, causing double-click issues
      final userIntendedPlaying = _audioHandler!.userIntendedPlaying;

      if (kDebugMode) {
        print('Current userIntendedPlaying: $userIntendedPlaying');
        print(
          'Action: ${userIntendedPlaying ? "PAUSE" : "PLAY"} (using userIntendedPlaying to avoid race condition)',
        );
      }

      try {
        // Remove external timeout to prevent mutex interruption
        // The audio handler has its own internal timeout and error handling
        if (userIntendedPlaying) {
          if (kDebugMode) {
            print(
              'Calling audioHandler.pause() (based on userIntendedPlaying)',
            );
          }
          await _audioHandler!.pause();
        } else {
          if (kDebugMode) {
            print('Calling audioHandler.play() (based on userIntendedPlaying)');
          }
          await _audioHandler!.play();
        }
      } catch (e) {
        if (kDebugMode) {
          print('ERROR in playPause(): $e');
        }
        // Try to recover by notifying listeners anyway
      }

      notifyListeners();

      if (kDebugMode) {
        print('=== AppState.playPause() completed ===');
      }
    } else {
      if (kDebugMode) {
        print('AudioHandler is null, cannot play/pause');
      }
    }
  }

  Future<void> skipToNext() async {
    if (_audioHandler != null) {
      await _audioHandler!.skipToNext();
      notifyListeners();
    }
  }

  Future<void> skipToPrevious() async {
    if (_audioHandler != null) {
      await _audioHandler!.skipToPrevious();
      notifyListeners();
    }
  }

  Future<void> skipToIndex(int index) async {
    if (_audioHandler != null) {
      await _audioHandler!.skipToQueueItem(index);
      notifyListeners();
    }
  }

  Future<void> seekTo(Duration position) async {
    if (_audioHandler != null) {
      await _audioHandler!.seek(position);
    }
  }

  void addToQueue(Track track) {
    _audioHandler?.addToQueue(track);
    notifyListeners();
  }

  void addNextInQueue(Track track) {
    _audioHandler?.addNext(track);
    notifyListeners();
  }

  void clearQueue() {
    // Clear queue functionality would need to be added to the handler
    notifyListeners();
  }

  // Queue getters
  List<Track> get queue => _audioHandler?.queueTracks ?? [];
  List<Track> get upNext => _audioHandler?.upNext ?? [];

  // Radio mode controls
  bool get radioModeEnabled => _audioHandler?.radioModeEnabled ?? false;

  void toggleRadioMode() {
    _audioHandler?.toggleRadioMode();
    notifyListeners();
  }

  void enableRadioMode() {
    _audioHandler?.enableRadioMode();
    notifyListeners();
  }

  void disableRadioMode() {
    _audioHandler?.disableRadioMode();
    notifyListeners();
  }

  void removeFromQueue(int index) {
    // Remove from queue functionality would need to be added to the handler
    notifyListeners();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    // Reorder queue functionality would need to be added to the handler
    notifyListeners();
  }

  // Add operation tracking for shuffle operations to prevent audio bleeding
  DateTime? _lastShuffleAllOperation;
  DateTime? _lastShuffleFavoritesOperation;

  Future<void> shuffleAllTracks() async {
    if (_tracks.isNotEmpty && _audioHandler != null) {
      // CRITICAL FIX: Add aggressive debouncing for shuffle all button
      final now = DateTime.now();
      if (_lastShuffleAllOperation != null &&
          now.difference(_lastShuffleAllOperation!) <
              const Duration(milliseconds: 800)) {
        if (kDebugMode) {
          print(
            'Shuffle all debounced - ${now.difference(_lastShuffleAllOperation!).inMilliseconds}ms since last operation',
          );
        }
        return; // Ignore rapid successive taps
      }
      _lastShuffleAllOperation = now;

      if (kDebugMode) {
        print('=== SHUFFLE ALL CALLED ===');
        print('Found ${_tracks.length} total tracks');
      }

      final shuffledTracks = List<Track>.from(_tracks);
      shuffledTracks.shuffle();

      if (kDebugMode) {
        print(
          'Playing shuffled all tracks - first track: ${shuffledTracks.first.name}',
        );
      }

      await _audioHandler!.playPlaylist(shuffledTracks, 0);
      _audioHandler!.shuffle(); // Enable shuffle mode
      notifyListeners();

      if (kDebugMode) {
        print('=== SHUFFLE ALL COMPLETED ===');
      }
    }
  }

  Future<void> shuffleFavoriteTracks() async {
    final favoriteTracks = _tracks.where((track) => track.isFavorite).toList();
    if (favoriteTracks.isNotEmpty && _audioHandler != null) {
      // CRITICAL FIX: Add aggressive debouncing for shuffle favorites button
      final now = DateTime.now();
      if (_lastShuffleFavoritesOperation != null &&
          now.difference(_lastShuffleFavoritesOperation!) <
              const Duration(milliseconds: 800)) {
        if (kDebugMode) {
          print(
            'Shuffle favorites debounced - ${now.difference(_lastShuffleFavoritesOperation!).inMilliseconds}ms since last operation',
          );
        }
        return; // Ignore rapid successive taps
      }
      _lastShuffleFavoritesOperation = now;

      if (kDebugMode) {
        print('=== SHUFFLE FAVORITES CALLED ===');
        print('Found ${favoriteTracks.length} favorite tracks');
      }

      final shuffledFavorites = List<Track>.from(favoriteTracks);
      shuffledFavorites.shuffle();

      if (kDebugMode) {
        print(
          'Playing shuffled favorites - first track: ${shuffledFavorites.first.name}',
        );
      }

      await _audioHandler!.playPlaylist(shuffledFavorites, 0);
      _audioHandler!.shuffle(); // Enable shuffle mode
      notifyListeners();

      if (kDebugMode) {
        print('=== SHUFFLE FAVORITES COMPLETED ===');
      }
    }
  }

  List<Track> get favoriteTracks =>
      _tracks.where((track) => track.isFavorite).toList();

  List<Album> get favoriteAlbums =>
      _albums.where((album) => album.isFavorite).toList();

  /// Check if a track is favorited by its ID
  bool isFavorite(String trackId) {
    final track = _tracks.firstWhere(
      (t) => t.id == trackId,
      orElse: () => Track(
        id: '',
        name: '',
        albumName: '',
        artistName: '',
        albumId: '',
        duration: 0,
        trackNumber: 0,
        imageUrl: '',
        isFavorite: false,
      ),
    );
    return track.isFavorite;
  }

  Future<void> toggleFavorite(Track track) async {
    if (kDebugMode) {
      print('=== TOGGLE FAVORITE START ===');
      print('Track ID: ${track.id}');
      print('Track Name: ${track.name}');
      print('Current isFavorite: ${track.isFavorite}');
      print('Will set to: ${!track.isFavorite}');
    }

    try {
      final success = await _mediaServiceManager.toggleFavorite(
        track.id,
        track.isFavorite,
      );

      if (kDebugMode) {
        print('Server response success: $success');
      }

      if (success) {
        // Update the track in the local list
        final index = _tracks.indexWhere((t) => t.id == track.id);

        if (kDebugMode) {
          print('Track found at index: $index');
        }

        if (index != -1) {
          _tracks[index] = Track(
            id: track.id,
            name: track.name,
            albumName: track.albumName,
            artistName: track.artistName,
            albumId: track.albumId,
            duration: track.duration,
            trackNumber: track.trackNumber,
            imageUrl: track.imageUrl,
            isFavorite: !track.isFavorite,
          );

          if (kDebugMode) {
            print('Updated track isFavorite to: ${_tracks[index].isFavorite}');
            print('Calling notifyListeners()');
          }

          notifyListeners();

          if (kDebugMode) {
            print('notifyListeners() called successfully');
          }
        } else {
          if (kDebugMode) {
            print('WARNING: Track not found in _tracks list!');
            print('Adding track to _tracks list with updated favorite status');
          }

          // Track not found in main list, add it with updated favorite status
          final updatedTrack = Track(
            id: track.id,
            name: track.name,
            albumName: track.albumName,
            artistName: track.artistName,
            albumId: track.albumId,
            duration: track.duration,
            trackNumber: track.trackNumber,
            imageUrl: track.imageUrl,
            isFavorite: !track.isFavorite,
          );

          _tracks.add(updatedTrack);

          if (kDebugMode) {
            print(
              'Track added to _tracks list with isFavorite: ${updatedTrack.isFavorite}',
            );
            print('Calling notifyListeners()');
          }

          notifyListeners();

          if (kDebugMode) {
            print('notifyListeners() called successfully');
          }
        }

        // Also refresh tracks in background to ensure all tracks have correct favorite status
        if (kDebugMode) {
          print('Refreshing tracks to sync favorite status...');
        }
        _refreshTracksInBackground();
      } else {
        if (kDebugMode) {
          print('ERROR: Server returned failure for toggle favorite');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('EXCEPTION in toggleFavorite: $e');
      }
      _setError('Failed to toggle favorite: ${e.toString()}');
    }

    if (kDebugMode) {
      print('=== TOGGLE FAVORITE END ===');
    }
  }

  Future<void> toggleAlbumFavorite(Album album) async {
    try {
      final success = await _mediaServiceManager.toggleFavorite(
        album.id,
        album.isFavorite,
      );
      if (success) {
        // Update the album in the local list
        final index = _albums.indexWhere((a) => a.id == album.id);
        if (index != -1) {
          _albums[index] = album.copyWith(isFavorite: !album.isFavorite);
          notifyListeners();
        }
      }
    } catch (e) {
      _setError('Failed to toggle album favorite: ${e.toString()}');
    }
  }

  Future<bool> createPlaylist(String name) async {
    try {
      final newPlaylist = await _mediaServiceManager.createPlaylist(name);
      if (newPlaylist != null) {
        // Add the new playlist to the local list
        _playlists.add(newPlaylist);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _setError('Failed to create playlist: ${e.toString()}');
      return false;
    }
  }

  Future<bool> addToPlaylist(String playlistId, String trackId) async {
    try {
      return await _mediaServiceManager.addToPlaylist(playlistId, trackId);
    } catch (e) {
      _setError('Failed to add to playlist: ${e.toString()}');
      return false;
    }
  }

  Future<bool> renamePlaylist(String playlistId, String newName) async {
    try {
      final success = await _mediaServiceManager.renamePlaylist(
        playlistId,
        newName,
      );
      if (success) {
        // Update the local playlist list
        final index = _playlists.indexWhere((p) => p.id == playlistId);
        if (index != -1) {
          _playlists[index] = Playlist(
            id: playlistId,
            name: newName,
            imageUrl: _playlists[index].imageUrl,
            trackCount: _playlists[index].trackCount,
          );
          notifyListeners();
        }
      }
      return success;
    } catch (e) {
      _setError('Failed to rename playlist: ${e.toString()}');
      return false;
    }
  }

  Future<bool> removePlaylist(String playlistId) async {
    try {
      final success = await _mediaServiceManager.removePlaylist(playlistId);
      if (success) {
        // Remove the playlist from the local list
        _playlists.removeWhere((p) => p.id == playlistId);
        notifyListeners();
      }
      return success;
    } catch (e) {
      _setError('Failed to remove playlist: ${e.toString()}');
      return false;
    }
  }

  Future<void> _saveServer() async {
    final server = _jellyfinService.currentServer;
    if (server != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jellyfin_server', jsonEncode(server.toJson()));
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> toggleNormalizeVolume(bool enabled) async {
    _normalizeVolumeEnabled = enabled;

    // Update the audio handler with the new normalize volume setting

    // Save the setting to preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('normalize_volume_enabled', enabled);

    notifyListeners();
  }

  Future<void> toggleGaplessPlayback(bool enabled) async {
    _gaplessPlaybackEnabled = enabled;

    // Update the audio handler with the new gapless playback setting
    _audioHandler?.setGaplessPlayback(enabled);

    // Save the setting to preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('gapless_playback_enabled', enabled);

    notifyListeners();
  }

  Future<void> toggleOledDarkMode(bool enabled) async {
    _oledDarkModeEnabled = enabled;

    // Save the setting to preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('oled_dark_mode_enabled', enabled);

    notifyListeners();
  }

  Future<void> toggleShowAlbumArt(bool enabled) async {
    _showAlbumArtEnabled = enabled;

    // Save the setting to preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_album_art_enabled', enabled);

    notifyListeners();
  }

  Future<void> toggleLogging(bool enabled) async {
    _loggingEnabled = enabled;

    // Update the logging service
    await LoggingService().setLoggingEnabled(enabled);

    // Save the setting to preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('logging_enabled', enabled);

    notifyListeners();
  }

  Future<void> toggleDynamicIsle(bool enabled) async {
    _useDynamicIsle = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_dynamic_isle', enabled);
    notifyListeners();
  }

  // Recent tracks management
  void _addToRecentTracks(Track track) {
    // Remove if already exists to avoid duplicates
    _recentTracks.removeWhere((t) => t.id == track.id);

    // Add to beginning of list
    _recentTracks.insert(0, track);

    // Keep only last 50 tracks
    if (_recentTracks.length > 50) {
      _recentTracks = _recentTracks.take(50).toList();
    }

    // Save to preferences
    _saveRecentTracks();
  }

  Future<void> _saveRecentTracks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentIds = _recentTracks.map((track) => track.id).toList();
      await prefs.setStringList('recent_track_ids', recentIds);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving recent tracks: $e');
      }
    }
  }

  Future<void> _loadRecentTracks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentIds = prefs.getStringList('recent_track_ids') ?? [];

      _recentTracks = [];
      for (final id in recentIds) {
        final track = findTrackById(id);
        if (track != null) {
          _recentTracks.add(track);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading recent tracks: $e');
      }
    }
  }

  void clearRecentTracks() {
    _recentTracks.clear();
    _saveRecentTracks();
    notifyListeners();
  }

  Future<void> _loadUserSettings() async {
    final prefs = await SharedPreferences.getInstance();

    _normalizeVolumeEnabled =
        prefs.getBool('normalize_volume_enabled') ?? false;
    _gaplessPlaybackEnabled = prefs.getBool('gapless_playback_enabled') ?? true;
    _oledDarkModeEnabled = prefs.getBool('oled_dark_mode_enabled') ?? true;
    _showAlbumArtEnabled = prefs.getBool('show_album_art_enabled') ?? true;
    _loggingEnabled =
        prefs.getBool('logging_enabled') ?? false; // Disabled by default
    _useDynamicIsle =
        prefs.getBool('use_dynamic_isle') ?? true; // Enabled by default

    // Load theme settings
    final themeModeString = prefs.getString('theme_mode') ?? 'system';
    _themeMode = _parseThemeMode(themeModeString);

    final accentColorValue =
        prefs.getInt('accent_color') ?? Colors.purple.value;
    _accentColor = Color(accentColorValue);

    // Load locale settings
    final localeCode = prefs.getString('locale');
    if (localeCode != null && localeCode.isNotEmpty) {
      final parts = localeCode.split('_');
      _locale = parts.length > 1
          ? Locale(parts[0], parts[1])
          : Locale(parts[0]);
    } else {
      _locale = null; // Use system locale
    }

    // Load recent tracks (only after tracks are loaded)
    if (_tracks.isNotEmpty) {
      await _loadRecentTracks();
    }
  }

  // Theme management methods
  ThemeMode _parseThemeMode(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode != mode) {
      _themeMode = mode;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_mode', _themeModeToString(mode));
      notifyListeners();
    }
  }

  Future<void> setAccentColor(Color color) async {
    if (_accentColor != color) {
      _accentColor = color;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('accent_color', color.value);
      notifyListeners();
    }
  }

  /// Set the app locale. Pass null to use system locale.
  Future<void> setLocale(Locale? locale) async {
    if (_locale != locale) {
      _locale = locale;
      final prefs = await SharedPreferences.getInstance();
      if (locale != null) {
        final localeCode = locale.countryCode != null
            ? '${locale.languageCode}_${locale.countryCode}'
            : locale.languageCode;
        await prefs.setString('locale', localeCode);
      } else {
        await prefs.remove('locale');
      }
      notifyListeners();
    }
  }

  /// Get the effective locale (user preference or system default)
  Locale get effectiveLocale {
    return _locale ?? ui.PlatformDispatcher.instance.locale;
  }

  // Cache management methods
  Future<void> clearAllCache() async {
    try {
      await _cacheService.clearAllCache();
      await ImageCacheManager.clearCache();

      if (kDebugMode) {
        print('All cache cleared successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing cache: $e');
      }
    }
  }

  Future<void> clearDataCache() async {
    try {
      await _cacheService.clearAllCache();

      if (kDebugMode) {
        print('Data cache cleared successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing data cache: $e');
      }
    }
  }

  Future<void> clearImageCache() async {
    try {
      await ImageCacheManager.clearCache();

      if (kDebugMode) {
        print('Image cache cleared successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing image cache: $e');
      }
    }
  }

  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final dataStats = await _cacheService.getCacheStats();
      final imageSize = await ImageCacheManager.getCacheSize();

      return {'data_cache': dataStats, 'image_cache_size': imageSize};
    } catch (e) {
      if (kDebugMode) {
        print('Error getting cache stats: $e');
      }
      return {};
    }
  }

  Future<void> cleanupExpiredCache() async {
    try {
      await _cacheService.cleanupExpiredCache();

      if (kDebugMode) {
        print('Expired cache cleaned up');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error cleaning up expired cache: $e');
      }
    }
  }

  // Connectivity and Offline Mode Management
  Future<bool> _checkConnectivity() async {
    try {
      // Simple connectivity check - try to get albums with short timeout
      await _mediaServiceManager.getAlbums().timeout(
        const Duration(seconds: 5),
      );
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Connectivity check failed: $e');
      }
      return false;
    }
  }

  Future<void> _updateConnectivityState() async {
    final wasConnected = _isConnected;
    _isConnected = await _checkConnectivity();

    if (wasConnected && !_isConnected) {
      // Lost connection - enter offline mode if we have downloads and credentials
      if (_isLoggedIn && await _hasDownloadedContent()) {
        await _enterOfflineMode();
        if (kDebugMode) {
          print('Connection lost, entered offline mode');
        }
      }
      // Note: We don't log the user out anymore when losing connection
    } else if (!wasConnected && _isConnected && _isOfflineMode) {
      // Regained connection - exit offline mode and refresh data
      await _exitOfflineMode();
      if (kDebugMode) {
        print('Connection restored, exited offline mode');
      }
    }

    notifyListeners();
  }

  // New public method to enter offline mode without login
  Future<bool> enterOfflineModeWithoutLogin() async {
    if (await _hasDownloadedContent()) {
      // Set offline mode without requiring login
      _isOfflineMode = true;
      _isConnected = false;
      _isLoggedIn =
          true; // We're setting this to true to bypass the login screen

      if (kDebugMode) {
        print('Entering offline mode without login');
      }

      // Initialize cache service for offline mode
      await _cacheService.initialize();

      // Load downloaded tracks and cached data for offline access
      await _loadOfflineData();

      // Clear any previous error messages
      _clearError();

      // Filter content to show only downloaded items
      _filterContentForOfflineMode();

      // Initialize new audio system for offline playback
      try {
        final audioService = AudioServiceIntegration.instance;
        await audioService.initialize(_mediaServiceManager);
        _audioHandler = audioService;

        // Apply user settings to the audio handler
        _audioHandler?.setGaplessPlayback(_gaplessPlaybackEnabled);

        // Set up listeners for automatic UI updates
        _setupAudioHandlerListeners();

        if (kDebugMode) {
          print(
            'Audio system initialized for offline mode, platform: ${audioService.platformType}',
          );
        }
      } catch (audioError) {
        if (kDebugMode) {
          print(
            'Failed to initialize audio system for offline mode: $audioError',
          );
        }
        // Continue without audio service
        _audioHandler = null;
      }

      notifyListeners();
      return true;
    } else {
      if (kDebugMode) {
        print('No downloaded content available for offline mode');
      }
      _setError('No downloaded content available for offline mode');
      return false;
    }
  }

  Future<void> _enterOfflineMode() async {
    if (kDebugMode) {
      print('Entering offline mode');
    }

    _isOfflineMode = true;
    _isConnected = false;

    // Load downloaded tracks and cached data for offline access
    await _loadOfflineData();

    // Clear any previous error messages since we're now in a valid offline state
    _clearError();

    // Ensure we show only downloaded content
    _filterContentForOfflineMode();

    notifyListeners();
  }

  Future<void> _exitOfflineMode() async {
    if (kDebugMode) {
      print('Exiting offline mode');
    }

    _isOfflineMode = false;

    // Try to refresh library data now that we're back online
    try {
      await loadLibraryData();
    } catch (e) {
      if (kDebugMode) {
        print('Failed to refresh library data after going online: $e');
      }
    }

    notifyListeners();
  }

  Future<void> _loadOfflineData() async {
    try {
      // Load cached data
      final cachedAlbums = await _cacheService.getCachedAlbums();
      final cachedArtists = await _cacheService.getCachedArtists();
      final cachedTracks = await _cacheService.getCachedTracks();
      final cachedPlaylists = await _cacheService.getCachedPlaylists();

      if (cachedAlbums != null && cachedAlbums.isNotEmpty) {
        _albums = cachedAlbums;
      }
      if (cachedArtists != null && cachedArtists.isNotEmpty) {
        _artists = cachedArtists;
      }
      if (cachedTracks != null && cachedTracks.isNotEmpty) {
        _tracks = cachedTracks;
      }
      if (cachedPlaylists != null && cachedPlaylists.isNotEmpty) {
        _playlists = cachedPlaylists;
      }

      // Filter to only show content that's available offline
      _filterToOfflineContent();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading offline data: $e');
      }
    }
  }

  void _filterToOfflineContent() {
    // Filter tracks to only those that are downloaded
    _tracks = _tracks
        .where((track) => _downloadService.isTrackDownloaded(track.id))
        .toList();

    // Filter albums to only those with downloaded tracks
    _albums = _albums
        .where((album) => _tracks.any((track) => track.albumId == album.id))
        .toList();

    // Filter artists to only those with downloaded tracks
    _artists = _artists
        .where(
          (artist) => _tracks.any((track) => track.artistName == artist.name),
        )
        .toList();

    // Filter playlists to only those with downloaded tracks
    // Note: This is more complex as we'd need to check playlist contents
    // For now, we'll keep all playlists but they'll show filtered content
  }

  void _filterContentForOfflineMode() {
    if (!_isOfflineMode) return;

    // Filter tracks to only show downloaded ones
    final downloadedTrackIds = _downloadService.downloadedTracks.keys.toSet();
    _tracks = _tracks
        .where((track) => downloadedTrackIds.contains(track.id))
        .toList();

    // Filter albums to only show those with downloaded tracks
    _albums = _albums
        .where((album) => _tracks.any((track) => track.albumId == album.id))
        .toList();

    // Filter artists to only show those with downloaded tracks
    _artists = _artists
        .where(
          (artist) => _tracks.any((track) => track.artistName == artist.name),
        )
        .toList();

    // Keep playlists but they will show filtered content when opened
    // The playlist detail screens will handle filtering their tracks

    if (kDebugMode) {
      print(
        'Filtered content for offline mode: ${_tracks.length} tracks, ${_albums.length} albums, ${_artists.length} artists',
      );
    }
  }

  // Public method to manually check connectivity
  Future<void> checkConnectivity() async {
    await _updateConnectivityState();
  }

  // Helper methods for offline mode
  Future<bool> _hasSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serverData = prefs.getString('jellyfin_server');
      return serverData != null;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _hasDownloadedContent() async {
    try {
      final downloadedTracks = _downloadService.downloadedTracks;
      return downloadedTracks.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
