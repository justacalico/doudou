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
import '../services/audio/unified_audio_handler.dart' show RepeatMode;
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
  final List<StreamSubscription<dynamic>> _audioHandlerSubscriptions = [];

  /// Called by the shell to close the desktop Now Playing overlay. Used on server switch.
  void Function()? _closeNowPlayingOverlay;
  void setCloseNowPlayingOverlay(void Function()? fn) {
    _closeNowPlayingOverlay = fn;
  }

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
  List<YTMHomeSection> _youtubeMusicHomeSections = [];

  bool _oledDarkModeEnabled = true;
  bool _showAlbumArtEnabled = true;
  bool _loggingEnabled = false; // Disabled by default
  bool _smartBackToStartEnabled = true;

  // Debouncing for play/pause to prevent rapid-fire clicking deadlocks
  DateTime? _lastPlayPauseCommand;
  static const Duration _playPauseDebounceDelay = Duration(milliseconds: 300);

  // Theme settings
  ThemeMode _themeMode = ThemeMode.system;
  Color _accentColor = Colors.purple;

  // Locale settings
  Locale? _locale; // null means use system locale

  /// Configured servers for multi-server support. Each map: {id, type, url, displayName?}.
  List<Map<String, String>> _configuredServers = [];
  String? _activeServerId;

  // Getters
  List<Map<String, String>> get configuredServers => List.unmodifiable(_configuredServers);
  String? get activeServerId => _activeServerId;
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
  List<YTMHomeSection> get youtubeMusicHomeSections =>
      List.unmodifiable(_youtubeMusicHomeSections);

  /// Albums from recently played tracks (unique, order preserved), for "Continue listening".
  List<Album> get recentlyPlayedAlbums {
    final seen = <String>{};
    final result = <Album>[];
    for (final t in _recentTracks) {
      final id = t.albumId;
      if (id == null || id.isEmpty || seen.contains(id)) continue;
      try {
        final album = _albums.firstWhere((a) => a.id == id);
        seen.add(id);
        result.add(album);
      } catch (_) {}
    }
    return result;
  }

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
    // This handles cases where Plex/Subsonic provide full URLs in imageUrl field
    if (itemId.startsWith('http://') || itemId.startsWith('https://')) {
      return itemId;
    }

    // If itemId is a local file path (file:// URI or absolute path), return as-is
    // This handles local music files with embedded or extracted album art
    if (itemId.startsWith('file://') || itemId.startsWith('/')) {
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

  bool get oledDarkModeEnabled => _oledDarkModeEnabled;
  bool get showAlbumArtEnabled => _showAlbumArtEnabled;
  bool get loggingEnabled => _loggingEnabled;
  bool get smartBackToStartEnabled => _smartBackToStartEnabled;

  // Theme getters
  ThemeMode get themeMode => _themeMode;
  Color get accentColor => _accentColor;

  // Locale getter
  Locale? get locale => _locale;

  AppState() {
    _mediaServiceManager = MediaServiceManager.withJellyfinService(
      _jellyfinService,
    );
    _downloadService = DownloadService(_mediaServiceManager);
    // Forward download service notifications to AppState listeners
    _downloadService.addListener(_onDownloadServiceChanged);
    _initializeApp();
  }

  void _onDownloadServiceChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _clearAudioHandlerListeners();
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
      _setError('Failed to initialize app: ${e.toString()}');
      // Even if initialization fails, mark as initialized to prevent infinite loading
      _isInitialized = true;
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  void _setupAudioHandlerListeners() {
    _clearAudioHandlerListeners();
    if (_audioHandler == null) return;

    // Listen to media item changes (track changes)
    final mediaItemStream = _audioHandler!.mediaItem;
    if (mediaItemStream != null) {
      _audioHandlerSubscriptions.add(
        mediaItemStream.listen((_) {
          notifyListeners();
        }),
      );
    }

    // Listen to current track stream changes (more reliable)
    final currentTrackStream = _audioHandler!.currentTrackStream;
    if (currentTrackStream != null) {
      _audioHandlerSubscriptions.add(
        currentTrackStream.listen((_) {
          notifyListeners();
        }),
      );
    }

    // Listen to playback state changes (for playing/paused status)
    final playbackStateStream = _audioHandler!.playbackState;
    if (playbackStateStream != null) {
      _audioHandlerSubscriptions.add(
        playbackStateStream.listen((_) {
          notifyListeners();
        }),
      );
    }
  }

  void _clearAudioHandlerListeners() {
    for (final subscription in _audioHandlerSubscriptions) {
      subscription.cancel();
    }
    _audioHandlerSubscriptions.clear();
  }

  static const String _keyConfiguredServers = 'configured_servers';
  static const String _keyActiveServerId = 'active_server_id';

  Future<void> _loadSavedServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _configuredServers = await _loadConfiguredServers();
      _activeServerId = prefs.getString(_keyActiveServerId);

      if (_configuredServers.isNotEmpty && _activeServerId != null) {
        final server = _configuredServers.where((s) => s['id'] == _activeServerId).firstOrNull;
        if (server != null) {
          // YouTube Music is not available on web; do not activate
          if (server['type'] == 'youtubeMusic' && kIsWeb) {
            // Leave user logged out of YTM on web; they can switch to another server
          } else {
            final success = await _connectToServer(server);
            if (success) return;
          }
        }
      }

      // Fall back to legacy single-server format and migrate
      final credentials = await _loadServerCredentials();

      if (credentials != null) {
        final serverType = credentials['serverType']!;
        final serverUrl = credentials['serverUrl']!;
        final authMethod = credentials['authMethod'] ?? 'password';

        // Handle local music specially
        if (serverType == 'local') {
          final success = await loginWithLocalMusic();
          if (success) {
            return;
          } else {
            return;
          }
        }

        // YouTube Music is not available on web; skip restoring
        if (serverType == 'youtubeMusic' && kIsWeb) {
          _setLoading(false);
          return;
        }

        // Initialize the appropriate service
        ServerType type;
        switch (serverType) {
          case 'plex':
            type = ServerType.plex;
            break;
          case 'subsonic':
            type = ServerType.subsonic;
            break;
          case 'soundcloud':
            type = ServerType.soundcloud;
            break;
          case 'youtubeMusic':
            type = ServerType.youtubeMusic;
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
            _isLoggedIn = true;
            _isConnected = true;
            _isOfflineMode = false;

            // Migrate to multi-server format
            final serverId = 'srv_${DateTime.now().millisecondsSinceEpoch}_${serverUrl.hashCode.abs()}';
            final serverConfig = <String, String>{
              'id': serverId,
              'type': serverType,
              'url': serverUrl,
              'authMethod': authMethod,
              if (authMethod == 'api_key' && credentials['apiKey'] != null)
                'apiKey': credentials['apiKey']!,
              if (authMethod == 'password') ...{
                'identifier': credentials['identifier']!,
                'credential': credentials['credential']!,
              },
            };
            _configuredServers = [serverConfig];
            _activeServerId = serverId;
            await _saveConfiguredServers();

            // Initialize cache service first
            await _cacheService.initialize();

            try {
              final audioService = AudioServiceIntegration.instance;
              await audioService.initialize(_mediaServiceManager);
              _audioHandler = audioService;

              // Apply persisted audio behavior toggles
              audioService.audioHandler?.setSmartBackToStartEnabled(
                _smartBackToStartEnabled,
              );
            } catch (audioError) {
              _audioHandler = null;
            }

            notifyListeners();

            if (_isLinux) {
              try {
                await refreshLibraryData();
              } catch (e) {
                // Error during Linux initialization library loading
              }
            } else {
              await loadLibraryData();
            }
          } else {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('${serverType}_credentials');
            if (serverType == 'jellyfin') {
              await prefs.remove('jellyfin_server'); // Legacy cleanup
            }
            _isLoggedIn = false;
            notifyListeners();
          }
        } catch (authError) {
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

              try {
                final audioService = AudioServiceIntegration.instance;
                await audioService.initialize(_mediaServiceManager);
                _audioHandler = audioService;

                _setupAudioHandlerListeners();
              } catch (audioError) {
                _audioHandler = null;
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
        final prefs = await SharedPreferences.getInstance();
        final serverJson = prefs.getString('jellyfin_server');

        if (serverJson != null) {
          final serverData = jsonDecode(serverJson);
          final server = JellyfinServer.fromJson(serverData);
          _jellyfinService.setJellyfinServer(server);

          // Test the connection with saved credentials
          try {
            final isValid = await _jellyfinService
                .validateCredentials()
                .timeout(const Duration(seconds: 10));

            if (isValid) {
              _isLoggedIn = true;
              _isConnected = true;
              _isOfflineMode = false;

              // Initialize cache service first
              await _cacheService.initialize();

              try {
                final audioService = AudioServiceIntegration.instance;
                await audioService.initialize(_mediaServiceManager);
                _audioHandler = audioService;
              } catch (audioError) {
                _audioHandler = null;
              }

              await loadLibraryData();
            } else {
              await prefs.remove('jellyfin_server');
              _isLoggedIn = false;
            }
          } catch (e) {
            _isLoggedIn = false;
          }
        } else {
          _isLoggedIn = false;
        }
      }
    } catch (e) {
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
        try {
          _isLoggedIn = true;

          await _cacheService.initialize();

          try {
            final audioService = AudioServiceIntegration.instance;
            await audioService.initialize(_mediaServiceManager);
            _audioHandler = audioService;

            _setupAudioHandlerListeners();
            notifyListeners();
          } catch (audioError) {
            _audioHandler = null;
            notifyListeners();
          }

          await _saveServer();

          try {
            if (_isLinux) {
              await refreshLibraryData();
            } else {
              await loadLibraryData();
            }
          } catch (e) {
            // Exception during library loading
          }

          _setLoading(false);
          return true;
        } catch (setupError) {
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
  Future<bool> loginWithApiKey(
    String serverUrl,
    String apiKey, {
    String? displayName,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Ensure serverUrl has protocol
      if (!serverUrl.startsWith('http://') &&
          !serverUrl.startsWith('https://')) {
        serverUrl = 'http://$serverUrl';
      }

      // Initialize Jellyfin service
      _mediaServiceManager.initializeService(ServerType.jellyfin);

      final success = await _jellyfinService.authenticateWithApiKey(
        serverUrl,
        apiKey,
      );

      if (success) {
        _isLoggedIn = true;

        // Add to configured servers
        final serverId = 'srv_${DateTime.now().millisecondsSinceEpoch}_${serverUrl.hashCode.abs()}';
        final serverConfig = <String, String>{
          'id': serverId,
          'type': 'jellyfin',
          'url': serverUrl,
          'authMethod': 'api_key',
          'apiKey': apiKey,
          if (displayName != null && displayName.isNotEmpty) 'displayName': displayName,
        };
        _configuredServers = [..._configuredServers, serverConfig];
        _activeServerId = serverId;
        await _saveConfiguredServers();

        // Initialize cache service
        await _cacheService.initialize();

        try {
          final audioService = AudioServiceIntegration.instance;
          await audioService.initialize(_mediaServiceManager);
          _audioHandler = audioService;

          _setupAudioHandlerListeners();
        } catch (e) {
          _audioHandler = null;
        }

        await _saveServerType('jellyfin');
        await _saveApiKeyCredentials(serverUrl, apiKey);
        await _saveServer();

        try {
          await loadLibraryData();
        } catch (e) {
          // Exception during library loading
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

  /// Login to Jellyfin using Quick Connect (already authenticated service)
  Future<bool> loginWithQuickConnect(
    JellyfinService authenticatedService, {
    String? displayName,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      _mediaServiceManager.initializeService(ServerType.jellyfin);
      _mediaServiceManager.setAuthenticatedJellyfinService(
        authenticatedService,
      );

      _isLoggedIn = true;

      final serverUrl = authenticatedService.serverUrl ?? '';
      // Add to configured servers (Quick Connect - credentials from jellyfinService)
      final serverId = 'srv_${DateTime.now().millisecondsSinceEpoch}_${serverUrl.hashCode.abs()}';
      final serverConfig = <String, String>{
        'id': serverId,
        'type': 'jellyfin',
        'url': serverUrl,
        'authMethod': 'quick_connect',
        'identifier': authenticatedService.userId ?? '',
        if (displayName != null && displayName.isNotEmpty) 'displayName': displayName,
      };
      _configuredServers = [..._configuredServers, serverConfig];
      _activeServerId = serverId;
      await _saveConfiguredServers();

      // Initialize cache service
      await _cacheService.initialize();

      try {
        final audioService = AudioServiceIntegration.instance;
        await audioService.initialize(_mediaServiceManager);
        _audioHandler = audioService;

        _setupAudioHandlerListeners();
      } catch (e) {
        _audioHandler = null;
      }

      await _saveServerType('jellyfin');
      await _saveQuickConnectCredentials(
        authenticatedService.serverUrl ?? '',
        authenticatedService.userId ?? '',
      );
      await _saveServer();

      try {
        await loadLibraryData();
      } catch (e) {
        // Exception during library loading
      }

      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      String errorMessage =
          'Quick Connect authentication failed. Please try again.';
      _setError(errorMessage);
      _setLoading(false);
      return false;
    }
  }

  /// Save Quick Connect credentials (just server URL and user ID)
  Future<void> _saveQuickConnectCredentials(
    String serverUrl,
    String userId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_type', 'jellyfin');
    await prefs.setString('server_url', serverUrl);
    await prefs.setString('auth_method', 'quick_connect');
    await prefs.setString('user_id', userId);

    await prefs.remove('server_identifier');
    await prefs.remove('server_credential');
    await prefs.remove('server_api_key');
  }

  /// Set an error message (useful for external components like login screen)
  void setErrorMessage(String message) {
    _setError(message);
    notifyListeners();
  }

  /// Login with local music (no server required)
  Future<bool> loginWithLocalMusic() async {
    _setLoading(true);
    _clearError();

    try {
      // Initialize local music service
      await _mediaServiceManager.setLocalMusicService();

      final localService = _mediaServiceManager.localMusicService;
      if (localService == null) {
        _setError('Failed to initialize local music service');
        _setLoading(false);
        return false;
      }

      // Check if we have any music
      final tracks = await localService.getTracks();
      if (tracks.isEmpty) {
        _setError('No music found. Please add directories and scan for music.');
        _setLoading(false);
        return false;
      }

      _isLoggedIn = true;

      // Add to configured servers
      final serverId = 'srv_local_${DateTime.now().millisecondsSinceEpoch}';
      final serverConfig = <String, String>{
        'id': serverId,
        'type': 'local',
        'url': 'local',
        'authMethod': 'local',
      };
      _configuredServers = [..._configuredServers, serverConfig];
      _activeServerId = serverId;
      await _saveConfiguredServers();

      // Initialize cache service
      await _cacheService.initialize();

      try {
        final audioService = AudioServiceIntegration.instance;
        await audioService.initialize(_mediaServiceManager);
        _audioHandler = audioService;
        _setupAudioHandlerListeners();
      } catch (e) {
        _audioHandler = null;
      }

      await _saveServerType('local');

      try {
        await loadLibraryData();
      } catch (e) {
        // Exception during library loading
      }

      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to initialize local music: $e');
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

    await prefs.remove('server_identifier');
    await prefs.remove('server_credential');
  }

  Future<bool> loginWithServerType(
    String serverType,
    String serverUrl,
    String identifier,
    String credential, {
    String? displayName,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Convert string server type to enum
      ServerType type;
      switch (serverType) {
        case 'plex':
          type = ServerType.plex;
          break;
        case 'subsonic':
          type = ServerType.subsonic;
          break;
        case 'soundcloud':
          type = ServerType.soundcloud;
          break;
        case 'youtubeMusic':
          type = ServerType.youtubeMusic;
          break;
        case 'local':
          type = ServerType.local;
          break;
        case 'jellyfin':
        default:
          type = ServerType.jellyfin;
          break;
      }

      // Initialize the appropriate service
      _mediaServiceManager.initializeService(type);

      // Ensure serverUrl has protocol for non-Plex, non-local, non-SoundCloud, and non-YouTube Music services
      if (type != ServerType.plex &&
          type != ServerType.local &&
          type != ServerType.soundcloud &&
          type != ServerType.youtubeMusic &&
          !serverUrl.startsWith('http://') &&
          !serverUrl.startsWith('https://')) {
        serverUrl = 'http://$serverUrl';
      }

      // SoundCloud uses client_id/secret; use fixed API base as serverUrl if empty
      if (type == ServerType.soundcloud &&
          (serverUrl.isEmpty || !serverUrl.startsWith('http'))) {
        serverUrl = 'https://api.soundcloud.com';
      }

      // YouTube Music uses fixed URL
      if (type == ServerType.youtubeMusic &&
          (serverUrl.isEmpty || !serverUrl.startsWith('http'))) {
        serverUrl = 'https://music.youtube.com';
      }

      final success = await _mediaServiceManager.authenticate(
        serverUrl,
        identifier,
        credential,
      );

      if (success) {
        _isLoggedIn = true;

        // Add to configured servers
        final serverId = 'srv_${DateTime.now().millisecondsSinceEpoch}_${serverUrl.hashCode.abs()}';
        final serverConfig = <String, String>{
          'id': serverId,
          'type': serverType,
          'url': serverUrl,
          'authMethod': 'password',
          'identifier': identifier,
          'credential': credential,
          if (displayName != null && displayName.isNotEmpty) 'displayName': displayName,
        };
        _configuredServers = [..._configuredServers, serverConfig];
        _activeServerId = serverId;
        await _saveConfiguredServers();

        // Initialize cache service
        await _cacheService.initialize();

        try {
          final audioService = AudioServiceIntegration.instance;
          await audioService.initialize(_mediaServiceManager);
          _audioHandler = audioService;

          _setupAudioHandlerListeners();
        } catch (e) {
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

        try {
          await loadLibraryData();
        } catch (e) {
          // Exception during library loading
        }

        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        final detail = (serverType == 'soundcloud' || serverType == 'youtubeMusic')
            ? _mediaServiceManager.lastAuthError
            : null;
        _setError(
          detail != null && detail.isNotEmpty
              ? 'Authentication failed. $detail'
              : 'Authentication failed. Please check your credentials.',
        );
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

    await prefs.setString('server_type', serverType);
    await prefs.setString('server_url', serverUrl);
    await prefs.setString('server_identifier', identifier);
    await prefs.setString('server_credential', credential);
  }

  Future<List<Map<String, String>>> _loadConfiguredServers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_keyConfiguredServers);
      if (json == null) return [];
      final list = jsonDecode(json) as List<dynamic>? ?? [];
      return list
          .map((e) => (e as Map<String, dynamic>).map(
                (k, v) => MapEntry(k, v?.toString() ?? ''),
              ))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _saveConfiguredServers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyConfiguredServers, jsonEncode(_configuredServers));
    if (_activeServerId != null) {
      await prefs.setString(_keyActiveServerId, _activeServerId!);
    } else {
      await prefs.remove(_keyActiveServerId);
    }
  }

  /// Connect to a server config (from configured_servers with full credentials).
  Future<bool> _connectToServer(Map<String, String> server) async {
    final serverType = server['type'] ?? 'jellyfin';
    var serverUrl = server['url'] ?? '';
    final authMethod = server['authMethod'] ?? 'password';

    if (serverType == 'local') {
      return await loginWithLocalMusic();
    }

    // YouTube Music is not available on web
    if (serverType == 'youtubeMusic' && kIsWeb) {
      return false;
    }

    ServerType type;
    switch (serverType) {
      case 'plex':
        type = ServerType.plex;
        break;
      case 'subsonic':
        type = ServerType.subsonic;
        break;
      case 'soundcloud':
        type = ServerType.soundcloud;
        break;
      case 'youtubeMusic':
        type = ServerType.youtubeMusic;
        break;
      default:
        type = ServerType.jellyfin;
    }

    _mediaServiceManager.initializeService(type);
    if (type != ServerType.plex &&
        type != ServerType.local &&
        type != ServerType.soundcloud &&
        type != ServerType.youtubeMusic &&
        !serverUrl.startsWith('http://') &&
        !serverUrl.startsWith('https://')) {
      serverUrl = 'http://$serverUrl';
    }
    if (type == ServerType.soundcloud &&
        (serverUrl.isEmpty || !serverUrl.startsWith('http'))) {
      serverUrl = 'https://api.soundcloud.com';
    }
    if (type == ServerType.youtubeMusic &&
        (serverUrl.isEmpty || !serverUrl.startsWith('http'))) {
      serverUrl = 'https://music.youtube.com';
    }
    _mediaServiceManager.setServer(serverUrl);

    try {
      bool isValid = false;
      if (authMethod == 'api_key' && server['apiKey'] != null) {
        isValid = await _jellyfinService
            .authenticateWithApiKey(serverUrl, server['apiKey']!)
            .timeout(const Duration(seconds: 10));
      } else {
        final identifier = server['identifier'] ?? '';
        final credential = server['credential'] ?? '';
        isValid = await _mediaServiceManager
            .authenticate(serverUrl, identifier, credential)
            .timeout(const Duration(seconds: 10));
      }

      if (isValid) {
        _isLoggedIn = true;
        _isConnected = true;
        _isOfflineMode = false;
        await _cacheService.initialize();
        try {
          if (_audioHandler == null) {
            final audioService = AudioServiceIntegration.instance;
            await audioService.initialize(_mediaServiceManager);
            _audioHandler = audioService;
          }
          _setupAudioHandlerListeners();
          _audioHandler!.audioHandler?.setSmartBackToStartEnabled(_smartBackToStartEnabled);
        } catch (e) {
          if (_audioHandler == null) rethrow;
          _setupAudioHandlerListeners();
        }
        await loadLibraryData();
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Switch to a different configured server.
  Future<bool> switchToServer(String serverId) async {
    _setLoading(true);
    _clearError();
    try {
      final servers = await _loadConfiguredServers();
      final server = servers.where((s) => s['id'] == serverId).firstOrNull;
      if (server == null) {
        _setLoading(false);
        return false;
      }

      _closeNowPlayingOverlay?.call();

      // Keep audio handler alive so AudioService does not need re-init (not supported)
      await _disconnectWithoutClearingServers(disposeAudio: false);
      _activeServerId = serverId;
      _configuredServers = servers;
      await _saveConfiguredServers();
      final success = await _connectToServer(server);
      _setLoading(false);
      notifyListeners();
      return success;
    } catch (e) {
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Disconnect from current server without clearing configured servers.
  /// When [disposeAudio] is false (e.g. server switch), the audio handler is
  /// reset but not disposed so audio works after reconnecting.
  Future<void> _disconnectWithoutClearingServers({bool disposeAudio = true}) async {
    _mediaServiceManager.clearAuth();
    _clearAudioHandlerListeners();
    if (disposeAudio) {
      try {
        await _audioHandler?.dispose();
      } catch (_) {}
      _audioHandler = null;
    } else {
      try {
        await _audioHandler?.resetForServerSwitch();
      } catch (_) {}
    }
    _isLoggedIn = false;
    _albums.clear();
    _artists.clear();
    _tracks.clear();
    _playlists.clear();
    _recentTracks.clear();
    _youtubeMusicHomeSections = [];
    // Clear library cache so loadLibraryData fetches fresh data from new server
    try {
      await _cacheService.clearAlbumsCache();
      await _cacheService.clearArtistsCache();
      await _cacheService.clearTracksCache();
      await _cacheService.clearPlaylistsCache();
    } catch (_) {}
    _clearError();
  }

  /// Remove a server from the list. If it was active, switch to another.
  Future<void> removeServer(String serverId) async {
    _configuredServers = _configuredServers.where((s) => s['id'] != serverId).toList();
    if (_activeServerId == serverId) {
      _activeServerId = _configuredServers.isNotEmpty ? _configuredServers.first['id'] : null;
      if (_activeServerId != null) {
        await switchToServer(_activeServerId!);
      } else {
        await _disconnectWithoutClearingServers();
        await _saveConfiguredServers();
        notifyListeners();
      }
    } else {
      await _saveConfiguredServers();
      notifyListeners();
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

      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    // Clear all server credentials and multi-server data
    await prefs.remove('jellyfin_server'); // Legacy Jellyfin
    await prefs.remove('jellyfin_credentials');
    await prefs.remove('subsonic_credentials');
    await prefs.remove('plex_credentials');
    await prefs.remove('server_type');
    await prefs.remove('server_url');
    await prefs.remove('server_identifier');
    await prefs.remove('server_credential');
    await prefs.remove(_keyConfiguredServers);
    await prefs.remove(_keyActiveServerId);
    await prefs.remove('saved_server_type');
    _configuredServers = [];
    _activeServerId = null;

    // Clear local music data if using local service
    final localService = _mediaServiceManager.localMusicService;
    if (localService != null) {
      await localService.fullLogout();
    }

    // Clear all cached library data
    await prefs.remove('albums_cache');
    await prefs.remove('artists_cache');
    await prefs.remove('tracks_cache');
    await prefs.remove('playlists_cache');

    // Clear the media service manager state
    _mediaServiceManager.clearAuth();

    try {
      await _audioHandler?.dispose();
    } catch (e) {
      // Handle platform-specific limitations
    }
    _audioHandler = null;

    _isLoggedIn = false;
    _albums.clear();
    _artists.clear();
    _tracks.clear();
    _playlists.clear();
    _youtubeMusicHomeSections = [];
    _clearError();

    notifyListeners();
  }

  Future<bool> _attemptTokenRefresh() async {
    if (!_isLoggedIn) return false;

    final server = _jellyfinService.currentServer;
    if (server == null || server.username == null || server.password == null) {
      return false;
    }

    try {
      final success = await _jellyfinService.reauthenticateWithCredentials(
        server.username!,
        server.password!,
      );

      if (success) {
        await _saveServer();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<void> handleNetworkReconnection() async {
    if (!_isLoggedIn) return;

    try {
      final isValid = await _jellyfinService.validateCredentials().timeout(
        const Duration(seconds: 15),
      );

      if (isValid) {
        _isConnected = true;
        _isOfflineMode = false;
        _loadFreshDataInBackground();
      } else {
        final refreshSuccess = await _attemptTokenRefresh();

        if (refreshSuccess) {
          _isConnected = true;
          _isOfflineMode = false;
          _loadFreshDataInBackground();
        } else {
          if (await _hasDownloadedContent()) {
            _isConnected = false;
            _isOfflineMode = true;
            await _enterOfflineMode();
          } else {
            logout();
          }
        }
      }
    } catch (e) {
      if (await _hasDownloadedContent()) {
        _isConnected = false;
        _isOfflineMode = true;
        await _enterOfflineMode();
      }
    }

    notifyListeners();
  }

  /// Restore favorite status from downloaded tracks
  void _restoreFavoriteStatusFromDownloads() {
    final downloadedTracks = _downloadService.downloadedTracks;
    for (int i = 0; i < _tracks.length; i++) {
      final track = _tracks[i];
      final downloadedTrack = downloadedTracks[track.id];
      if (downloadedTrack != null && downloadedTrack.isFavorite != track.isFavorite) {
        _tracks[i] = Track(
          id: track.id,
          name: track.name,
          albumName: track.albumName,
          artistName: track.artistName,
          albumId: track.albumId,
          playlistItemId: track.playlistItemId,
          duration: track.duration,
          trackNumber: track.trackNumber,
          imageUrl: track.imageUrl,
          isFavorite: downloadedTrack.isFavorite,
          playCount: track.playCount,
        );
      }
    }
  }

  Future<void> loadLibraryData() async {
    if (!_isLoggedIn) {
      return;
    }

    _setLoading(true);
    _clearError();

    try {
      final cachedAlbums = await _cacheService.getCachedAlbums();
      final cachedArtists = await _cacheService.getCachedArtists();
      final cachedTracks = await _cacheService.getCachedTracks();
      final cachedPlaylists = await _cacheService.getCachedPlaylists();

      bool hasValidCache =
          cachedAlbums != null &&
          cachedArtists != null &&
          cachedTracks != null &&
          cachedPlaylists != null;

      if (hasValidCache) {
        // Use cached data immediately for better user experience
        _albums = cachedAlbums;
        _artists = cachedArtists;
        _tracks = cachedTracks;
        _playlists = cachedPlaylists;

        // Restore favorite status from downloaded tracks
        _restoreFavoriteStatusFromDownloads();

        try {
          _audioHandler?.updateMediaLibrary(
            _tracks,
            _albums,
            _artists,
            _playlists,
          );
        } catch (e) {
          // Failed to update AudioHandler with cached data
        }

        await _loadRecentTracks();

        _setLoading(false);

        _loadFreshDataInBackground();
      } else {
        await _loadFreshData();
      }
    } catch (e) {
      // Provide user-friendly error messages based on error type
      String userMessage = 'Failed to load library';
      if (e.toString().contains('401') ||
          e.toString().contains('unauthorized')) {
        final refreshSuccess = await _attemptTokenRefresh();
        if (refreshSuccess) {
          try {
            await _loadFreshData();
            _setLoading(false);
            return;
          } catch (retryError) {
            // Retry after token refresh failed
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

        try {
          _audioHandler?.updateMediaLibrary(
            _tracks,
            _albums,
            _artists,
            _playlists,
          );
        } catch (audioError) {
          // Failed to update AudioHandler with empty data
        }
      }
    }
  }

  Future<void> refreshLibraryData() async {
    if (!_isLoggedIn) {
      return;
    }

    _setLoading(true);
    _clearError();

    try {
      await _loadFreshData();
      _setLoading(false);
    } catch (e) {
      String userMessage = 'Failed to refresh library';
      if (e.toString().contains('401') ||
          e.toString().contains('unauthorized')) {
        final refreshSuccess = await _attemptTokenRefresh();
        if (refreshSuccess) {
          try {
            await _loadFreshData();
            _setLoading(false);
            return;
          } catch (retryError) {
            // Retry after token refresh failed
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
      final List<Future> futures = [
        _mediaServiceManager.getAlbums().catchError((e) {
          return <Album>[];
        }),
        _mediaServiceManager.getArtists().catchError((e) {
          return <Artist>[];
        }),
        _mediaServiceManager.getAllTracks().catchError((e) {
          return <Track>[];
        }),
        _mediaServiceManager.getPlaylists().catchError((e) {
          return <Playlist>[];
        }),
      ];

      final results = await Future.wait(futures);

      _albums = results[0] as List<Album>;
      _artists = results[1] as List<Artist>;
      _tracks = results[2] as List<Track>;
      _playlists = results[3] as List<Playlist>;

      _youtubeMusicHomeSections = [];
      if (_mediaServiceManager.currentServerType == ServerType.youtubeMusic) {
        try {
          _youtubeMusicHomeSections =
              await _mediaServiceManager.getYouTubeMusicHomeSections();
        } catch (_) {
          _youtubeMusicHomeSections = [];
        }
      }

      // Restore favorite status from downloaded tracks
      _restoreFavoriteStatusFromDownloads();

      try {
        _audioHandler?.updateMediaLibrary(
          _tracks,
          _albums,
          _artists,
          _playlists,
        );
      } catch (e) {
        // Failed to update AudioHandler
      }

      final cacheFutures = [
        _cacheService.cacheAlbums(_albums).catchError((e) {}),
        _cacheService.cacheArtists(_artists).catchError((e) {}),
        _cacheService.cacheTracks(_tracks).catchError((e) {}),
        _cacheService.cachePlaylists(_playlists).catchError((e) {}),
      ];

      await Future.wait(cacheFutures);

      await _loadRecentTracks();

      _setLoading(false);
    } catch (e) {
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
          // Failed to update AudioHandler with empty collections
        }
      }

      rethrow;
    }
  }

  Future<void> _loadFreshDataInBackground() async {
    try {
      await _loadFreshData();
      notifyListeners();
    } catch (e) {
      if (e.toString().contains('401') ||
          e.toString().contains('unauthorized')) {
        final refreshSuccess = await _attemptTokenRefresh();
        if (refreshSuccess) {
          try {
            await _loadFreshData();
            notifyListeners();
            return;
          } catch (retryError) {
            // Retry after token refresh failed in background
          }
        }
      }

      if (e.toString().contains('timeout') ||
          e.toString().contains('connection')) {
        _isConnected = false;
        notifyListeners();

        Future.delayed(const Duration(minutes: 1), () {
          _isConnected = true;
          notifyListeners();
        });
      }
    }
  }

  Future<void> _refreshTracksInBackground() async {
    try {
      final freshTracks = await _mediaServiceManager.getTracks();

      if (freshTracks.isNotEmpty) {
        // For Subsonic, getTracks returns random songs which may not include
        // the tracks we have locally. Merge fresh data with existing tracks
        // to preserve favorite status and ensure we don't lose tracks.
        final Map<String, Track> trackMap = {};

        // First, add all existing tracks to the map
        for (final track in _tracks) {
          trackMap[track.id] = track;
        }

        // Then, update with fresh tracks (this updates favorite status for tracks that exist in both)
        for (final freshTrack in freshTracks) {
          trackMap[freshTrack.id] = freshTrack;
        }

        // Convert back to list
        _tracks = trackMap.values.toList();

        await _cacheService.cacheTracks(_tracks);
        notifyListeners();
      }
    } catch (e) {
      // Background operation - don't show error to user
    }
  }

  Future<List<Track>> getAlbumTracks(String albumId) async {
    try {
      final cachedTracks = await _cacheService.getCachedAlbumTracks(albumId);
      if (cachedTracks != null) {
        _loadAlbumTracksInBackground(albumId);
        return cachedTracks;
      }

      final tracks = await _mediaServiceManager.getTracks(parentId: albumId);

      await _cacheService.cacheAlbumTracks(albumId, tracks);

      return tracks;
    } catch (e) {
      _setError('Failed to load tracks: ${e.toString()}');
      return [];
    }
  }

  Future<void> _loadAlbumTracksInBackground(String albumId) async {
    try {
      final tracks = await _mediaServiceManager.getTracks(parentId: albumId);
      await _cacheService.cacheAlbumTracks(albumId, tracks);
    } catch (e) {
      // Background operation - don't show error
    }
  }

  Future<List<Track>> getPlaylistTracks(String playlistId) async {
    try {
      final cachedTracks = await _cacheService.getCachedPlaylistTracks(
        playlistId,
      );
      if (cachedTracks != null) {
        _loadPlaylistTracksInBackground(playlistId);
        return cachedTracks;
      }

      final tracks = await _mediaServiceManager.getPlaylistTracks(playlistId);

      // Cache the tracks
      await _cacheService.cachePlaylistTracks(playlistId, tracks);

      return tracks;
    } catch (e) {
      _setError('Failed to load playlist tracks: ${e.toString()}');
      return [];
    }
  }

  Future<void> _loadPlaylistTracksInBackground(String playlistId) async {
    try {
      final tracks = await _mediaServiceManager.getPlaylistTracks(playlistId);
      await _cacheService.cachePlaylistTracks(playlistId, tracks);
    } catch (e) {
      // Background operation - don't show error
    }
  }

  /// Get tracks for an artist (SoundCloud only - fetches from API)
  Future<List<Track>> getArtistTracks(Artist artist) async {
    try {
      return await _mediaServiceManager.getArtistTracks(
        artist.id,
        artistName: artist.name,
      );
    } catch (e) {
      _setError('Failed to load artist tracks: ${e.toString()}');
      return [];
    }
  }

  Future<void> playTrack(Track track) async {
    if (_audioHandler != null) {
      await _audioHandler!.playTrack(track);
      _addToRecentTracks(track);
      notifyListeners();
    }
  }

  Future<void> playPlaylist(List<Track> tracks, int startIndex) async {
    if (_audioHandler != null) {
      await _audioHandler!.playPlaylist(tracks, startIndex);
      notifyListeners();
    }
  }

  Future<void> playPause() async {
    final now = DateTime.now();
    if (_lastPlayPauseCommand != null &&
        now.difference(_lastPlayPauseCommand!) < _playPauseDebounceDelay) {
      return;
    }
    _lastPlayPauseCommand = now;

    if (_audioHandler != null) {
      final userIntendedPlaying = _audioHandler!.userIntendedPlaying;

      try {
        if (userIntendedPlaying) {
          await _audioHandler!.pause();
        } else {
          await _audioHandler!.play();
        }
      } catch (e) {
        // Try to recover by notifying listeners anyway
      }

      notifyListeners();
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
  bool _isLoadingAllTracks = false;
  bool _isLoadingFavorites = false;

  /// Get loading state for shuffle all operation
  bool get isLoadingAllTracks => _isLoadingAllTracks;

  /// Get loading state for favorites operation
  bool get isLoadingFavorites => _isLoadingFavorites;

  Future<void> shuffleAllTracks() async {
    if (_audioHandler == null) return;

    // CRITICAL FIX: Add aggressive debouncing for shuffle all button
    final now = DateTime.now();
    if (_lastShuffleAllOperation != null &&
        now.difference(_lastShuffleAllOperation!) <
            const Duration(milliseconds: 800)) {
      return; // Ignore rapid successive taps
    }
    _lastShuffleAllOperation = now;

    _isLoadingAllTracks = true;
    notifyListeners();

    try {
      // Fetch ALL tracks from the server using the new getAllTracks method
      // This properly paginates for Subsonic servers
      List<Track> allTracks = await _mediaServiceManager.getAllTracks();

      if (allTracks.isEmpty) {
        // Fallback to cached tracks if getAllTracks returns nothing
        allTracks = List<Track>.from(_tracks);
      }

      if (allTracks.isEmpty) {
        return;
      }

      final shuffledTracks = List<Track>.from(allTracks);
      shuffledTracks.shuffle();

      await _audioHandler!.playPlaylist(shuffledTracks, 0);
      await _audioHandler!.shuffle(); // Enable shuffle mode
    } catch (e) {
      // Error in shuffleAllTracks
    } finally {
      _isLoadingAllTracks = false;
      notifyListeners();
    }
  }

  Future<void> shuffleFavoriteTracks() async {
    if (_audioHandler == null) return;

    // CRITICAL FIX: Add aggressive debouncing for shuffle favorites button
    final now = DateTime.now();
    if (_lastShuffleFavoritesOperation != null &&
        now.difference(_lastShuffleFavoritesOperation!) <
            const Duration(milliseconds: 800)) {
      return; // Ignore rapid successive taps
    }
    _lastShuffleFavoritesOperation = now;

    _isLoadingFavorites = true;
    notifyListeners();

    try {
      // Fetch ALL starred tracks from the server using the new getStarredTracks method
      // This uses getStarred2 API for Subsonic which returns all starred items
      List<Track> favoriteTracks = await _mediaServiceManager
          .getStarredTracks();

      if (favoriteTracks.isEmpty) {
        // Fallback to cached tracks filtered by isFavorite
        favoriteTracks = _tracks.where((track) => track.isFavorite).toList();
      }

      if (favoriteTracks.isEmpty) {
        return;
      }

      final shuffledFavorites = List<Track>.from(favoriteTracks);
      shuffledFavorites.shuffle();

      await _audioHandler!.playPlaylist(shuffledFavorites, 0);
      await _audioHandler!.shuffle(); // Enable shuffle mode
    } catch (e) {
      // Error in shuffleFavoriteTracks
    } finally {
      _isLoadingFavorites = false;
      notifyListeners();
    }
  }

  /// Get all starred tracks from the server (not cached)
  Future<List<Track>> getStarredTracksFromServer() async {
    return await _mediaServiceManager.getStarredTracks();
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
    try {
      final success = await _mediaServiceManager.toggleFavorite(
        track.id,
        track.isFavorite,
      );

      if (success) {
        // Update the track in the local list
        final index = _tracks.indexWhere((t) => t.id == track.id);

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

          notifyListeners();
        } else {
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

          notifyListeners();
        }

        // Also refresh tracks in background to ensure all tracks have correct favorite status
        _refreshTracksInBackground();
      }
    } catch (e) {
      _setError('Failed to toggle favorite: ${e.toString()}');
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

  /// Follow an artist (SoundCloud only). Their tracks show up on home/library.
  Future<bool> followArtist(Artist artist) async {
    try {
      final success = await _mediaServiceManager.followArtist(artist);
      if (success) {
        await loadLibraryData();
      }
      return success;
    } catch (e) {
      _setError('Failed to follow artist: ${e.toString()}');
      return false;
    }
  }

  /// Unfollow an artist (SoundCloud only)
  Future<bool> unfollowArtist(String artistId) async {
    try {
      final success = await _mediaServiceManager.unfollowArtist(artistId);
      if (success) {
        await loadLibraryData();
      }
      return success;
    } catch (e) {
      _setError('Failed to unfollow artist: ${e.toString()}');
      return false;
    }
  }

  /// Check if following an artist (SoundCloud only)
  bool isFollowingArtist(String artistId) {
    return _mediaServiceManager.isFollowingArtist(artistId);
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

  Future<bool> removeTrackFromPlaylist(
    String playlistId,
    Track track, {
    int? trackIndex,
    List<Track>? currentTracks,
  }) async {
    try {
      final success = await _mediaServiceManager.removeTrackFromPlaylist(
        playlistId,
        track.id,
        playlistItemId: track.playlistItemId,
        trackIndex: trackIndex,
      );

      if (!success) return false;

      final playlistIndex = _playlists.indexWhere((p) => p.id == playlistId);
      if (playlistIndex != -1) {
        final playlist = _playlists[playlistIndex];
        _playlists[playlistIndex] = Playlist(
          id: playlist.id,
          name: playlist.name,
          imageUrl: playlist.imageUrl,
          trackCount: playlist.trackCount > 0 ? playlist.trackCount - 1 : 0,
        );
      }

      if (currentTracks != null) {
        final updatedTracks = List<Track>.from(currentTracks);
        if (trackIndex != null &&
            trackIndex >= 0 &&
            trackIndex < updatedTracks.length) {
          updatedTracks.removeAt(trackIndex);
        } else if (track.playlistItemId != null) {
          updatedTracks.removeWhere(
            (t) => t.playlistItemId == track.playlistItemId,
          );
        } else {
          final index = updatedTracks.indexWhere((t) => t.id == track.id);
          if (index != -1) {
            updatedTracks.removeAt(index);
          }
        }
        await _cacheService.cachePlaylistTracks(playlistId, updatedTracks);
      } else {
        final refreshedTracks = await _mediaServiceManager.getPlaylistTracks(
          playlistId,
        );
        await _cacheService.cachePlaylistTracks(playlistId, refreshedTracks);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to remove track from playlist: ${e.toString()}');
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

  Future<void> toggleSmartBackToStart(bool enabled) async {
    _smartBackToStartEnabled = enabled;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('smart_back_to_start_enabled', enabled);

    // Forward to audio handler if available
    _audioHandler?.audioHandler?.setSmartBackToStartEnabled(enabled);

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
      // Error saving recent tracks
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
      // Error loading recent tracks
    }
  }

  void clearRecentTracks() {
    _recentTracks.clear();
    _saveRecentTracks();
    notifyListeners();
  }

  Future<void> _loadUserSettings() async {
    final prefs = await SharedPreferences.getInstance();

    _oledDarkModeEnabled = prefs.getBool('oled_dark_mode_enabled') ?? true;
    _showAlbumArtEnabled = prefs.getBool('show_album_art_enabled') ?? true;
    _loggingEnabled =
        prefs.getBool('logging_enabled') ?? false; // Disabled by default
    _smartBackToStartEnabled =
        prefs.getBool('smart_back_to_start_enabled') ?? true;

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
    } catch (e) {
      // Error clearing cache
    }
  }

  Future<void> clearDataCache() async {
    try {
      await _cacheService.clearAllCache();
    } catch (e) {
      // Error clearing data cache
    }
  }

  Future<void> clearImageCache() async {
    try {
      await ImageCacheManager.clearCache();
    } catch (e) {
      // Error clearing image cache
    }
  }

  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final dataStats = await _cacheService.getCacheStats();
      final imageSize = await ImageCacheManager.getCacheSize();

      return {'data_cache': dataStats, 'image_cache_size': imageSize};
    } catch (e) {
      return {};
    }
  }

  Future<void> cleanupExpiredCache() async {
    try {
      await _cacheService.cleanupExpiredCache();
    } catch (e) {
      // Error cleaning up expired cache
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
      }
      // Note: We don't log the user out anymore when losing connection
    } else if (!wasConnected && _isConnected && _isOfflineMode) {
      // Regained connection - exit offline mode and refresh data
      await _exitOfflineMode();
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

        // Set up listeners for automatic UI updates
        _setupAudioHandlerListeners();
      } catch (audioError) {
        // Continue without audio service
        _audioHandler = null;
      }

      notifyListeners();
      return true;
    } else {
      _setError('No downloaded content available for offline mode');
      return false;
    }
  }

  Future<void> _enterOfflineMode() async {
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

  // ============================================================================
  // VOICE COMMAND HANDLING (Google Assistant Integration)
  // ============================================================================

  /// Handle a voice command from Google Assistant
  /// This is the main entry point for all voice commands
  Future<void> handleVoiceCommand(dynamic command) async {
    // Import dynamically to avoid circular dependency
    // The command object comes from VoiceCommandService
    final commandType = command.type;

    try {
      switch (commandType.toString()) {
        case 'VoiceCommandType.play':
          await _handleVoicePlayGeneral();
          break;

        case 'VoiceCommandType.playArtist':
          await searchAndPlayArtist(command.artist ?? '');
          break;

        case 'VoiceCommandType.playAlbum':
          await searchAndPlayAlbum(command.album ?? '', artist: command.artist);
          break;

        case 'VoiceCommandType.playPlaylist':
          await searchAndPlayPlaylist(command.playlist ?? '');
          break;

        case 'VoiceCommandType.playFavorites':
          await playFavoritesFromVoice(shuffle: command.shuffle);
          break;

        case 'VoiceCommandType.shuffleAll':
          await shuffleAllTracks();
          break;

        case 'VoiceCommandType.searchAndPlay':
          await searchAndPlay(command.query ?? '');
          break;

        case 'VoiceCommandType.pause':
          await _audioHandler?.pause();
          break;

        case 'VoiceCommandType.resume':
          await _audioHandler?.play();
          break;

        case 'VoiceCommandType.stop':
          // Stop is equivalent to pause for this audio system
          await _audioHandler?.pause();
          break;

        case 'VoiceCommandType.next':
          await skipToNext();
          break;

        case 'VoiceCommandType.previous':
          await skipToPrevious();
          break;

        case 'VoiceCommandType.shuffle':
          await _audioHandler?.shuffle();
          break;

        case 'VoiceCommandType.repeat':
          // Cycle through repeat modes: none -> all -> one -> none
          await _cycleRepeatMode();
          break;

        default:
          // Unknown voice command type
          break;
      }
    } catch (e) {
      // Error handling voice command
    }
  }

  /// Cycle through repeat modes: none -> all -> one -> none
  Future<void> _cycleRepeatMode() async {
    if (_audioHandler == null) return;

    final currentMode = _audioHandler!.repeatMode;

    // Cycle: none -> all -> one -> none
    if (currentMode == RepeatMode.none) {
      await _audioHandler!.setRepeatMode(RepeatMode.all);
    } else if (currentMode == RepeatMode.all) {
      await _audioHandler!.setRepeatMode(RepeatMode.one);
    } else {
      await _audioHandler!.setRepeatMode(RepeatMode.none);
    }
    notifyListeners();
  }

  /// Handle general "play music" command - plays recently played or shuffles all
  Future<void> _handleVoicePlayGeneral() async {
    // If there's something in the queue, resume playback
    if (_audioHandler != null && queue.isNotEmpty) {
      await _audioHandler!.play();
      return;
    }

    // Otherwise, try to play recent tracks
    if (_recentTracks.isNotEmpty) {
      await _audioHandler?.playPlaylist(_recentTracks, 0);
      return;
    }

    // If no recent tracks, shuffle all
    await shuffleAllTracks();
  }

  /// Search for content and play - handles songs, albums, artists intelligently
  Future<void> searchAndPlay(String query) async {
    if (query.isEmpty) {
      await shuffleAllTracks();
      return;
    }

    try {
      final normalizedQuery = query.toLowerCase().trim();

      // First, try to find an exact or close match in tracks
      final matchingTracks = _tracks.where((track) {
        final trackName = track.name.toLowerCase();
        final artistName = track.artistName?.toLowerCase() ?? '';
        final albumName = track.albumName?.toLowerCase() ?? '';
        return trackName.contains(normalizedQuery) ||
            artistName.contains(normalizedQuery) ||
            albumName.contains(normalizedQuery);
      }).toList();

      if (matchingTracks.isNotEmpty) {
        // Sort by relevance - exact name match first
        matchingTracks.sort((a, b) {
          final aExact = a.name.toLowerCase() == normalizedQuery ? 0 : 1;
          final bExact = b.name.toLowerCase() == normalizedQuery ? 0 : 1;
          if (aExact != bExact) return aExact.compareTo(bExact);

          // Then by artist match
          final aArtist =
              (a.artistName?.toLowerCase() ?? '').contains(normalizedQuery)
              ? 0
              : 1;
          final bArtist =
              (b.artistName?.toLowerCase() ?? '').contains(normalizedQuery)
              ? 0
              : 1;
          return aArtist.compareTo(bArtist);
        });

        // Play the best match and queue similar tracks
        await _audioHandler?.playPlaylist(matchingTracks, 0);
        return;
      }

      // Try albums
      final matchingAlbum = _albums.firstWhere(
        (album) => album.name.toLowerCase().contains(normalizedQuery),
        orElse: () => Album(id: '', name: '', artistName: ''),
      );

      if (matchingAlbum.id.isNotEmpty) {
        await _playAlbumById(matchingAlbum.id);
        return;
      }

      // Try artists
      final matchingArtist = _artists.firstWhere(
        (artist) => artist.name.toLowerCase().contains(normalizedQuery),
        orElse: () => Artist(id: '', name: ''),
      );

      if (matchingArtist.id.isNotEmpty) {
        await playArtistTracks(matchingArtist);
        return;
      }

      // Try playlists
      final matchingPlaylist = _playlists.firstWhere(
        (playlist) => playlist.name.toLowerCase().contains(normalizedQuery),
        orElse: () => Playlist(id: '', name: '', trackCount: 0),
      );

      if (matchingPlaylist.id.isNotEmpty) {
        await _playPlaylistById(matchingPlaylist.id);
        return;
      }

      // Nothing found locally, try server search
      final searchResults = await _mediaServiceManager.search(query);
      if (searchResults.tracks.isNotEmpty) {
        await _audioHandler?.playPlaylist(searchResults.tracks, 0);
        return;
      }
    } catch (e) {
      // Error in searchAndPlay
    }
  }

  /// Run server-side search (e.g. SoundCloud, Jellyfin). Used by the Search page.
  Future<SearchResults> searchMedia(String query, {int? limit}) async {
    if (!_isLoggedIn) return SearchResults();
    return await _mediaServiceManager.search(
      query.trim(),
      limit: limit ?? 50,
    );
  }

  /// Search for and play music by a specific artist
  Future<void> searchAndPlayArtist(String artistName) async {
    if (artistName.isEmpty) return;

    final normalizedName = artistName.toLowerCase().trim();

    // Find matching artist
    final matchingArtist = _artists.firstWhere(
      (artist) => artist.name.toLowerCase().contains(normalizedName),
      orElse: () => Artist(id: '', name: ''),
    );

    if (matchingArtist.id.isNotEmpty) {
      await playArtistTracks(matchingArtist);
      return;
    }

    // Try tracks by artist name
    final artistTracks = _tracks
        .where(
          (track) =>
              track.artistName?.toLowerCase().contains(normalizedName) ?? false,
        )
        .toList();

    if (artistTracks.isNotEmpty) {
      artistTracks.shuffle();
      await _audioHandler?.playPlaylist(artistTracks, 0);
      return;
    }
  }

  /// Search for and play a specific album
  Future<void> searchAndPlayAlbum(String albumName, {String? artist}) async {
    if (albumName.isEmpty) return;

    final normalizedAlbum = albumName.toLowerCase().trim();
    final normalizedArtist = artist?.toLowerCase().trim();

    // Find matching album
    final matchingAlbum = _albums.firstWhere((album) {
      final nameMatch = album.name.toLowerCase().contains(normalizedAlbum);
      if (!nameMatch) return false;
      if (normalizedArtist != null) {
        return album.artistName?.toLowerCase().contains(normalizedArtist) ??
            false;
      }
      return true;
    }, orElse: () => Album(id: '', name: '', artistName: ''));

    if (matchingAlbum.id.isNotEmpty) {
      await _playAlbumById(matchingAlbum.id);
      return;
    }
  }

  /// Search for and play a playlist by name
  Future<void> searchAndPlayPlaylist(String playlistName) async {
    if (playlistName.isEmpty) return;

    final normalizedName = playlistName.toLowerCase().trim();

    // Find matching playlist
    final matchingPlaylist = _playlists.firstWhere(
      (playlist) => playlist.name.toLowerCase().contains(normalizedName),
      orElse: () => Playlist(id: '', name: '', trackCount: 0),
    );

    if (matchingPlaylist.id.isNotEmpty) {
      await _playPlaylistById(matchingPlaylist.id);
      return;
    }
  }

  /// Play favorites from voice command
  Future<void> playFavoritesFromVoice({bool shuffle = false}) async {
    if (shuffle) {
      await shuffleFavoriteTracks();
    } else {
      // Get favorites and play in order
      List<Track> favoriteTracks = await _mediaServiceManager
          .getStarredTracks();

      if (favoriteTracks.isEmpty) {
        favoriteTracks = _tracks.where((track) => track.isFavorite).toList();
      }

      if (favoriteTracks.isNotEmpty) {
        await _audioHandler?.playPlaylist(favoriteTracks, 0);
      }
    }
  }

  /// Play all tracks from an artist
  Future<void> playArtistTracks(Artist artist) async {
    try {
      // Get tracks from this artist
      final artistTracks = _tracks
          .where((track) => track.artistName == artist.name)
          .toList();

      if (artistTracks.isNotEmpty) {
        await _audioHandler?.playPlaylist(artistTracks, 0);
      }
    } catch (e) {
      // Error playing artist tracks
    }
  }

  /// Play an album by its ID (fetches tracks and plays)
  Future<void> _playAlbumById(String albumId) async {
    try {
      // Get tracks from this album from local cache
      final albumTracks = _tracks
          .where((track) => track.albumId == albumId)
          .toList();

      // Sort by track number
      albumTracks.sort(
        (a, b) => (a.trackNumber ?? 0).compareTo(b.trackNumber ?? 0),
      );

      if (albumTracks.isNotEmpty) {
        await _audioHandler?.playPlaylist(albumTracks, 0);
      }
    } catch (e) {
      // Error playing album
    }
  }

  /// Play a playlist by its ID (fetches tracks and plays)
  Future<void> _playPlaylistById(String playlistId) async {
    try {
      // Fetch tracks from the playlist
      final tracks = await _mediaServiceManager.getPlaylistTracks(playlistId);

      if (tracks.isNotEmpty) {
        await _audioHandler?.playPlaylist(tracks, 0);
      }
    } catch (e) {
      // Error playing playlist
    }
  }

  // ============================================================================
  // END VOICE COMMAND HANDLING
  // ============================================================================

  Future<void> _exitOfflineMode() async {
    _isOfflineMode = false;

    // Try to refresh library data now that we're back online
    try {
      await loadLibraryData();
    } catch (e) {
      // Failed to refresh library data after going online
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
      // Error loading offline data
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

    // Restore favorite status from downloaded tracks
    _restoreFavoriteStatusFromDownloads();

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
