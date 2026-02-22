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
import '../models/saved_server.dart';
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
  final List<StreamSubscription<dynamic>> _audioHandlerSubscriptions = [];

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

  bool _oledDarkModeEnabled = true;
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

  // Display values for settings (server URL and username for any server type)
  String? _displayServerUrl;
  String? _displayUsername;

  // Multiple saved servers and current active server id
  List<SavedServer> _savedServers = [];
  String? _currentServerId;

  // Getters
  bool get isLoggedIn => _isLoggedIn;
  String? get displayServerUrl => _displayServerUrl;
  String? get displayUsername => _displayUsername;
  List<SavedServer> get savedServers => List.unmodifiable(_savedServers);
  String? get currentServerId => _currentServerId;
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

  Future<void> _loadSavedServer() async {
    try {
      await _loadSavedServersList();
      final credentials = await _loadServerCredentials();

      // Prefer connecting from saved servers list
      if (_savedServers.isNotEmpty && _currentServerId != null) {
        final idx = _savedServers.indexWhere((s) => s.id == _currentServerId);
        if (idx >= 0) {
          final ok = await _connectToSavedServer(_savedServers[idx]);
          if (ok) return;
        }
      }

      // Migrate legacy single-server prefs into saved list once
      if (_savedServers.isEmpty && credentials != null) {
        await _migrateLegacyToSavedServers(credentials);
        if (_savedServers.isNotEmpty && _currentServerId != null) {
          final server = _savedServers.firstWhere(
            (s) => s.id == _currentServerId,
          );
          final ok = await _connectToSavedServer(server);
          if (ok) return;
        }
      }

      // Legacy path: restore from flat credentials
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

        // Initialize the appropriate service
        ServerType type;
        switch (serverType) {
          case 'plex':
            type = ServerType.plex;
            break;
          case 'subsonic':
            type = ServerType.subsonic;
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
            _displayServerUrl = serverUrl;
            _displayUsername = authMethod == 'api_key'
                ? null
                : credentials['identifier'];

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
          _displayServerUrl = _jellyfinService.serverUrl;
          _displayUsername = _jellyfinService.username;

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
  Future<bool> loginWithApiKey(String serverUrl, String apiKey) async {
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
        _displayServerUrl = serverUrl;
        _displayUsername = _jellyfinService.username;

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

        await closePlayerAndClearQueue();

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
    JellyfinService authenticatedService,
  ) async {
    _setLoading(true);
    _clearError();

    try {
      _mediaServiceManager.initializeService(ServerType.jellyfin);
      _mediaServiceManager.setAuthenticatedJellyfinService(
        authenticatedService,
      );

      _isLoggedIn = true;
      _displayServerUrl = authenticatedService.serverUrl;
      _displayUsername = authenticatedService.username;

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

      await closePlayerAndClearQueue();

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

      // Allow connecting with empty library; user adds directories in Settings > Local Music
      _isLoggedIn = true;

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

      await closePlayerAndClearQueue();

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
        case 'subsonic':
          type = ServerType.subsonic;
          break;
        case 'local':
          type = ServerType.local;
          break;
        case 'youtubeMusic':
          type = ServerType.youtubeMusic;
          break;
        case 'jellyfin':
        default:
          type = ServerType.jellyfin;
          break;
      }

      // Initialize the appropriate service
      _mediaServiceManager.initializeService(type);

      // Ensure serverUrl has protocol for non-Plex, non-local, and non-YouTube Music services
      if (type != ServerType.plex &&
          type != ServerType.local &&
          type != ServerType.youtubeMusic &&
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
        _isLoggedIn = true;
        _displayServerUrl = serverUrl;
        _displayUsername = identifier;

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

        await closePlayerAndClearQueue();

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

    await prefs.setString('server_type', serverType);
    await prefs.setString('server_url', serverUrl);
    await prefs.setString('server_identifier', identifier);
    await prefs.setString('server_credential', credential);
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

  static const String _savedServersKey = 'saved_servers';
  static const String _currentServerIdKey = 'current_server_id';

  Future<void> _loadSavedServersList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_savedServersKey);
      if (json != null) {
        final list = jsonDecode(json) as List<dynamic>?;
        _savedServers = (list ?? [])
            .map((e) => SavedServer.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        _savedServers = [];
      }
      _currentServerId = prefs.getString(_currentServerIdKey);
    } catch (_) {
      _savedServers = [];
      _currentServerId = null;
    }
  }

  Future<void> _saveSavedServersList() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _savedServersKey,
      jsonEncode(_savedServers.map((s) => s.toJson()).toList()),
    );
    if (_currentServerId != null) {
      await prefs.setString(_currentServerIdKey, _currentServerId!);
    } else {
      await prefs.remove(_currentServerIdKey);
    }
  }

  Future<void> _migrateLegacyToSavedServers(Map<String, String> credentials) async {
    final serverType = credentials['serverType']!;
    final serverUrl = credentials['serverUrl']!;
    final authMethod = credentials['authMethod'] ?? 'password';
    final id = 'legacy_${DateTime.now().millisecondsSinceEpoch}';
    SavedServer server;
    if (serverType == 'local') {
      server = SavedServer(
        id: id,
        serverType: 'local',
        serverUrl: '',
        authMethod: 'local',
      );
    } else if (authMethod == 'api_key' && credentials['apiKey'] != null) {
      server = SavedServer(
        id: id,
        serverType: serverType,
        serverUrl: serverUrl,
        authMethod: 'api_key',
        apiKey: credentials['apiKey'],
      );
    } else if (authMethod == 'quick_connect' && credentials['userId'] != null) {
      server = SavedServer(
        id: id,
        serverType: serverType,
        serverUrl: serverUrl,
        authMethod: 'quick_connect',
        userId: credentials['userId'],
      );
    } else {
      server = SavedServer(
        id: id,
        serverType: serverType,
        serverUrl: serverUrl,
        authMethod: 'password',
        identifier: credentials['identifier'],
        credential: credentials['credential'],
      );
    }
    _savedServers = [server];
    _currentServerId = id;
    await _saveSavedServersList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('server_type');
    await prefs.remove('server_url');
    await prefs.remove('server_identifier');
    await prefs.remove('server_credential');
    await prefs.remove('server_api_key');
    await prefs.remove('auth_method');
    await prefs.remove('user_id');
  }

  Future<bool> _connectToSavedServer(SavedServer s) async {
    _setLoading(true);
    _clearError();
    try {
      if (s.serverType == 'local') {
        final ok = await loginWithLocalMusic();
        if (ok) {
          _currentServerId = s.id;
          await _saveSavedServersList();
        }
        return ok;
      }
      if (s.serverType == 'youtubeMusic') {
        final ok = await loginWithServerType('youtubeMusic', '', '', '');
        if (ok) {
          _currentServerId = s.id;
          await _saveSavedServersList();
        }
        return ok;
      }
      if (s.serverType == 'jellyfin' && s.authMethod == 'api_key' && s.apiKey != null) {
        final ok = await loginWithApiKey(s.serverUrl, s.apiKey!);
        if (ok) {
          _currentServerId = s.id;
          await _saveSavedServersList();
        }
        return ok;
      }
      if (s.serverType == 'plex' && s.credential != null) {
        final ok = await loginWithServerType('plex', s.serverUrl, '', s.credential!);
        if (ok) {
          _currentServerId = s.id;
          await _saveSavedServersList();
        }
        return ok;
      }
      if (s.serverType == 'subsonic' && s.identifier != null && s.credential != null) {
        final ok = await loginWithServerType(
          'subsonic', s.serverUrl, s.identifier!, s.credential!,
        );
        if (ok) {
          _currentServerId = s.id;
          await _saveSavedServersList();
        }
        return ok;
      }
      if (s.serverType == 'jellyfin' && s.authMethod == 'password' &&
          s.identifier != null && s.credential != null) {
        final ok = await loginWithServerType(
          'jellyfin', s.serverUrl, s.identifier!, s.credential!,
        );
        if (ok) {
          _currentServerId = s.id;
          await _saveSavedServersList();
        }
        return ok;
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addServer(SavedServer server) async {
    _savedServers = List.from(_savedServers)..add(server);
    await _saveSavedServersList();
    notifyListeners();
  }

  Future<void> updateServer(SavedServer server) async {
    final idx = _savedServers.indexWhere((s) => s.id == server.id);
    if (idx >= 0) {
      _savedServers = List.from(_savedServers)..[idx] = server;
      await _saveSavedServersList();
      notifyListeners();
    }
  }

  Future<void> removeServer(String id) async {
    final wasCurrent = _currentServerId == id;
    _savedServers = _savedServers.where((s) => s.id != id).toList();
    if (wasCurrent) {
      _currentServerId = null;
      await logout();
    }
    await _saveSavedServersList();
    notifyListeners();
  }

  Future<bool> switchToServer(String id) async {
    final idx = _savedServers.indexWhere((s) => s.id == id);
    if (idx < 0) return false;
    _currentServerId = id;
    await _saveSavedServersList();
    return _connectToSavedServer(_savedServers[idx]);
  }

  Future<bool> addServerAndConnect(SavedServer server) async {
    await addServer(server);
    _currentServerId = server.id;
    await _saveSavedServersList();
    return _connectToSavedServer(server);
  }

  Future<bool> updateServerAndConnect(SavedServer server) async {
    await updateServer(server);
    if (_currentServerId == server.id) {
      return _connectToSavedServer(server);
    }
    return true;
  }

  /// After connecting via the form, persist this server as current (add or update by id).
  Future<void> setCurrentServerAndSave(SavedServer server) async {
    final idx = _savedServers.indexWhere((s) => s.id == server.id);
    if (idx >= 0) {
      _savedServers = List.from(_savedServers)..[idx] = server;
    } else {
      _savedServers = List.from(_savedServers)..add(server);
    }
    _currentServerId = server.id;
    await _saveSavedServersList();
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    _currentServerId = null;
    await _saveSavedServersList();

    // Clear all server credentials (legacy flat keys and type-specific)
    await prefs.remove('jellyfin_server');
    await prefs.remove('jellyfin_credentials');
    await prefs.remove('subsonic_credentials');
    await prefs.remove('plex_credentials');
    await prefs.remove('saved_server_type');
    await prefs.remove('server_type');
    await prefs.remove('server_url');
    await prefs.remove('server_identifier');
    await prefs.remove('server_credential');
    await prefs.remove('server_api_key');
    await prefs.remove('auth_method');
    await prefs.remove('user_id');

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
    _displayServerUrl = null;
    _displayUsername = null;
    _albums.clear();
    _artists.clear();
    _tracks.clear();
    _playlists.clear();
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

      // Ensure we have empty but valid collections
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

      // Ensure we have safe empty collections
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
    _audioHandler?.clearQueue();
    notifyListeners();
  }

  /// Close the player bar: stop playback and clear the queue.
  Future<void> closePlayerAndClearQueue() async {
    final h = _audioHandler;
    if (h == null) return;
    await h.clearQueue();
    await h.stop();
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
