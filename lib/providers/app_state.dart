import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import '../models/jellyfin_models.dart';
import '../services/jellyfin_service.dart';
import '../services/audio/audio_handler.dart';
import '../services/cache_service.dart';
import '../services/image_cache_manager.dart';
import '../services/download_service.dart';

class AppState extends ChangeNotifier {
  final JellyfinService _jellyfinService = JellyfinService();
  final CacheService _cacheService = CacheService.instance;
  late final DownloadService _downloadService;
  DoudouAudioHandler? _audioHandler;
  
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
  bool _smartCrossfadeEnabled = false;
  bool _normalizeVolumeEnabled = false;
  bool _gaplessPlaybackEnabled = true;
  bool _oledDarkModeEnabled = true;
  bool _showAlbumArtEnabled = true;
  
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
  JellyfinService get jellyfinService => _jellyfinService;
  DownloadService get downloadService => _downloadService;
  DoudouAudioHandler? get audioHandler => _audioHandler;
  bool get smartCrossfadeEnabled => _smartCrossfadeEnabled;
  bool get normalizeVolumeEnabled => _normalizeVolumeEnabled;
  bool get gaplessPlaybackEnabled => _gaplessPlaybackEnabled;
  bool get oledDarkModeEnabled => _oledDarkModeEnabled;
  bool get showAlbumArtEnabled => _showAlbumArtEnabled;

  AppState() {
    _downloadService = DownloadService(_jellyfinService);
    _initializeApp();
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
      _audioHandler!.mediaItem.listen((mediaItem) {
        // Notify listeners when the current track changes
        notifyListeners();
      });
      
      // Listen to playback state changes (for playing/paused status)
      _audioHandler!.playbackState.listen((playbackState) {
        // Notify listeners when playback state changes
        notifyListeners();
      });
    }
  }

  Future<void> _loadSavedServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serverJson = prefs.getString('jellyfin_server');
      
      if (serverJson != null) {
        final serverData = jsonDecode(serverJson);
        final server = JellyfinServer.fromJson(serverData);
        _jellyfinService.setServer(server);
        
        // Test the connection with saved credentials
        try {
          // Try to validate credentials with timeout
          final isValid = await _jellyfinService.validateCredentials()
              .timeout(const Duration(seconds: 10));
          
          if (isValid) {
            // If successful, we're logged in and online
            _isLoggedIn = true;
            _isConnected = true;
            _isOfflineMode = false;
            
            // Initialize cache service first
            await _cacheService.initialize();
            
            // Try to initialize audio handler with platform-specific handling
            if (Platform.isAndroid) {
              // Android: Use AudioService for background audio and Android Auto
              try {
                _audioHandler = await AudioService.init(
                  builder: () => DoudouAudioHandler(_jellyfinService, _downloadService),
                  config: const AudioServiceConfig(
                    androidNotificationChannelId: 'gitlab.openlyst.doudou.channel.audio',
                    androidNotificationChannelName: 'Doudou Music',
                    androidNotificationOngoing: true,
                  ),
                );
                
                // Apply user settings to the audio handler
                _audioHandler?.setSmartCrossfade(_smartCrossfadeEnabled);
                _audioHandler?.setNormalizeVolume(_normalizeVolumeEnabled);
                _audioHandler?.setGaplessPlayback(_gaplessPlaybackEnabled);
                
                // Set up listeners for automatic UI updates
                _setupAudioHandlerListeners();
                
                if (kDebugMode) {
                  print('Android audio service initialized successfully');
                }
              } catch (audioError) {
                if (kDebugMode) {
                  print('Failed to initialize Android audio service: $audioError');
                }
                // Continue without audio service
                _audioHandler = null;
              }
            } else if (Platform.isMacOS) {
              // macOS: Use AudioService for background audio like Android
              try {
                _audioHandler = await AudioService.init(
                  builder: () => DoudouAudioHandler(_jellyfinService, _downloadService),
                  config: const AudioServiceConfig(
                    androidNotificationChannelId: 'gitlab.openlyst.doudou.channel.audio',
                    androidNotificationChannelName: 'Doudou Music',
                    androidNotificationOngoing: true,
                  ),
                );
                
                // Apply user settings to the audio handler
                _audioHandler?.setSmartCrossfade(_smartCrossfadeEnabled);
                _audioHandler?.setNormalizeVolume(_normalizeVolumeEnabled);
                _audioHandler?.setGaplessPlayback(_gaplessPlaybackEnabled);
                
                // Set up listeners for automatic UI updates
                _setupAudioHandlerListeners();
                
                if (kDebugMode) {
                  print('macOS audio service initialized successfully');
                }
              } catch (audioError) {
                if (kDebugMode) {
                  print('Failed to initialize macOS audio service: $audioError');
                }
                // Continue without audio service
                _audioHandler = null;
              }
            } else if (Platform.isIOS) {
              // iOS: Initialize audio handler without AudioService wrapper
              try {
                _audioHandler = DoudouAudioHandler(_jellyfinService, _downloadService);
                
                // Apply user settings to the audio handler
                _audioHandler?.setSmartCrossfade(_smartCrossfadeEnabled);
                _audioHandler?.setNormalizeVolume(_normalizeVolumeEnabled);
                _audioHandler?.setGaplessPlayback(_gaplessPlaybackEnabled);
                
                // Set up listeners for automatic UI updates
                _setupAudioHandlerListeners();
                
                if (kDebugMode) {
                  print('iOS audio handler initialized successfully');
                }
              } catch (audioError) {
                if (kDebugMode) {
                  print('Failed to initialize iOS audio handler: $audioError');
                }
                // Continue without audio handler
                _audioHandler = null;
              }
            } else if (Platform.isLinux) {
              // Linux: Initialize audio handler without AudioService wrapper (like iOS)
              try {
                _audioHandler = DoudouAudioHandler(_jellyfinService, _downloadService);
                
                // Apply user settings to the audio handler
                _audioHandler?.setSmartCrossfade(_smartCrossfadeEnabled);
                _audioHandler?.setNormalizeVolume(_normalizeVolumeEnabled);
                _audioHandler?.setGaplessPlayback(_gaplessPlaybackEnabled);
                
                // Set up listeners for automatic UI updates
                _setupAudioHandlerListeners();
                
                if (kDebugMode) {
                  print('Linux audio handler initialized successfully');
                }
              } catch (audioError) {
                if (kDebugMode) {
                  print('Failed to initialize Linux audio handler: $audioError');
                }
                // Continue without audio handler
                _audioHandler = null;
              }
            } else {
              if (kDebugMode) {
                print('Audio service initialization skipped on unsupported platform');
              }
              // On other platforms, we don't use audio services
              _audioHandler = null;
            }
            
            notifyListeners();
            
            // Load initial data in background
            if (kDebugMode) {
              print('Platform.isAndroid: ${Platform.isAndroid}, about to load library data...');
            }
            
            // On Linux, use refreshLibraryData to bypass cache issues that prevent UI updates
            if (Platform.isLinux) {
              if (kDebugMode) {
                print('AppState: Using refreshLibraryData for Linux platform during initialization to ensure UI updates');
              }
              await refreshLibraryData();
            } else {
              await loadLibraryData();
            }
          } else {
            // Credentials are invalid, clear them
            await prefs.remove('jellyfin_server');
            _isLoggedIn = false;
            notifyListeners();
          }
        } catch (authError) {
          if (kDebugMode) {
            print('Cannot connect to server, checking for offline mode: $authError');
          }
          
          // Server is unreachable, but we have credentials - check for offline capability
          if (await _hasDownloadedContent()) {
            // Enter offline mode with saved credentials
            _isLoggedIn = true;
            _isConnected = false;
            await _enterOfflineMode();
            
            // Initialize cache service for offline mode
            await _cacheService.initialize();
            
            // Try to initialize audio handler for offline playback with platform-specific handling
            if (Platform.isAndroid) {
              // Android: Use AudioService for background audio and Android Auto
              try {
                _audioHandler = await AudioService.init(
                  builder: () => DoudouAudioHandler(_jellyfinService, _downloadService),
                  config: const AudioServiceConfig(
                    androidNotificationChannelId: 'gitlab.openlyst.doudou.channel.audio',
                    androidNotificationChannelName: 'Doudou Music',
                    androidNotificationOngoing: true,
                  ),
                );
                
                // Apply user settings to the audio handler
                _audioHandler?.setSmartCrossfade(_smartCrossfadeEnabled);
                _audioHandler?.setNormalizeVolume(_normalizeVolumeEnabled);
                _audioHandler?.setGaplessPlayback(_gaplessPlaybackEnabled);
                
                // Set up listeners for automatic UI updates
                _setupAudioHandlerListeners();
                
                if (kDebugMode) {
                  print('Android audio service initialized successfully (offline mode)');
                }
              } catch (audioError) {
                if (kDebugMode) {
                  print('Failed to initialize Android audio service in offline mode: $audioError');
                }
                // Continue without audio service
                _audioHandler = null;
              }
            } else if (Platform.isMacOS) {
              // macOS: Use AudioService for background audio like Android
              try {
                _audioHandler = await AudioService.init(
                  builder: () => DoudouAudioHandler(_jellyfinService, _downloadService),
                  config: const AudioServiceConfig(
                    androidNotificationChannelId: 'gitlab.openlyst.doudou.channel.audio',
                    androidNotificationChannelName: 'Doudou Music',
                    androidNotificationOngoing: true,
                  ),
                );
                
                // Apply user settings to the audio handler
                _audioHandler?.setSmartCrossfade(_smartCrossfadeEnabled);
                _audioHandler?.setNormalizeVolume(_normalizeVolumeEnabled);
                _audioHandler?.setGaplessPlayback(_gaplessPlaybackEnabled);
                
                // Set up listeners for automatic UI updates
                _setupAudioHandlerListeners();
                
                if (kDebugMode) {
                  print('macOS audio service initialized successfully (offline mode)');
                }
              } catch (audioError) {
                if (kDebugMode) {
                  print('Failed to initialize macOS audio service in offline mode: $audioError');
                }
                // Continue without audio service
                _audioHandler = null;
              }
            } else if (Platform.isIOS) {
              // iOS: Initialize audio handler without AudioService wrapper
              try {
                _audioHandler = DoudouAudioHandler(_jellyfinService, _downloadService);
                
                // Apply user settings to the audio handler
                _audioHandler?.setSmartCrossfade(_smartCrossfadeEnabled);
                _audioHandler?.setNormalizeVolume(_normalizeVolumeEnabled);
                _audioHandler?.setGaplessPlayback(_gaplessPlaybackEnabled);
                
                // Set up listeners for automatic UI updates
                _setupAudioHandlerListeners();
                
                if (kDebugMode) {
                  print('iOS audio handler initialized successfully (offline mode)');
                }
              } catch (audioError) {
                if (kDebugMode) {
                  print('Failed to initialize iOS audio handler in offline mode: $audioError');
                }
                // Continue without audio handler
                _audioHandler = null;
              }
            } else {
              if (kDebugMode) {
                print('Audio service initialization skipped on unsupported platform (offline mode)');
              }
              // On other platforms, we don't use audio services
              _audioHandler = null;
            }
            
            if (kDebugMode) {
              print('Entered offline mode with saved credentials');
            }
            notifyListeners();
          } else {
            // No downloads available, clear invalid credentials
            await prefs.remove('jellyfin_server');
            _isLoggedIn = false;
            notifyListeners();
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading saved server: $e');
      }
    }
  }

  Future<bool> login(String serverUrl, String username, String password) async {
    _setLoading(true);
    _clearError();

    try {
      // Ensure serverUrl has protocol
      if (!serverUrl.startsWith('http://') && !serverUrl.startsWith('https://')) {
        serverUrl = 'http://$serverUrl';
      }

      final success = await _jellyfinService.authenticate(serverUrl, username, password);
      
      if (success) {
        if (kDebugMode) {
          print('AppState: Authentication success, setting up login state...');
        }
        
        _isLoggedIn = true;
        
        // Initialize cache service first
        await _cacheService.initialize();
        
        // Try to initialize audio handler after successful login
        // Only initialize audio service on Android (needed for background audio and Android Auto)
        if (Platform.isAndroid) {
          try {
            _audioHandler = await AudioService.init(
              builder: () => DoudouAudioHandler(_jellyfinService, _downloadService),
              config: const AudioServiceConfig(
                androidNotificationChannelId: 'gitlab.openlyst.doudou.channel.audio',
                androidNotificationChannelName: 'Doudou Music',
                androidNotificationOngoing: true,
              ),
            );
            
            // Apply user settings to the audio handler
            _audioHandler?.setSmartCrossfade(_smartCrossfadeEnabled);
            _audioHandler?.setNormalizeVolume(_normalizeVolumeEnabled);
            _audioHandler?.setGaplessPlayback(_gaplessPlaybackEnabled);
            
            // Set up listeners for automatic UI updates
            _setupAudioHandlerListeners();
            
            // Notify listeners after audio handler is ready
            notifyListeners();
          } catch (audioError) {
            if (kDebugMode) {
              print('Failed to initialize audio service: $audioError');
            }
            // Continue without audio service
          }
        } else if (Platform.isLinux) {
          // Linux: Initialize audio handler without AudioService wrapper (like iOS)
          try {
            _audioHandler = DoudouAudioHandler(_jellyfinService, _downloadService);
            
            // Apply user settings to the audio handler
            _audioHandler?.setSmartCrossfade(_smartCrossfadeEnabled);
            _audioHandler?.setNormalizeVolume(_normalizeVolumeEnabled);
            _audioHandler?.setGaplessPlayback(_gaplessPlaybackEnabled);
            
            // Set up listeners for automatic UI updates
            _setupAudioHandlerListeners();
            
            if (kDebugMode) {
              print('Linux audio handler initialized successfully after login');
            }
            
            // Notify listeners that login is complete
            notifyListeners();
          } catch (audioError) {
            if (kDebugMode) {
              print('Failed to initialize Linux audio handler after login: $audioError');
            }
            // Continue without audio handler
            _audioHandler = null;
            notifyListeners();
          }
        } else {
          if (kDebugMode) {
            print('Audio service initialization skipped on non-Android platform');
          }
          // On other platforms, we don't use AudioService
          _audioHandler = null;
          
          // Notify listeners that login is complete
          notifyListeners();
        }
        
        if (kDebugMode) {
          print('AppState: About to save server and load library data...');
        }
        
        await _saveServer();
        
        if (kDebugMode) {
          print('AppState: About to call loadLibraryData after successful login...');
        }
        
        try {
          // On Linux, use refreshLibraryData to bypass cache issues that prevent UI updates
          if (Platform.isLinux) {
            if (kDebugMode) {
              print('AppState: Using refreshLibraryData for Linux platform to ensure UI updates');
            }
            await refreshLibraryData();
          } else {
            await loadLibraryData();
          }
        } catch (e) {
          if (kDebugMode) {
            print('AppState: Exception during loadLibraryData: $e');
          }
        }
        
        _setLoading(false);
        return true;
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
          _setError('Network error. Please check your connection and try again.');
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
        errorMessage = 'Connection timeout. Please check your network and server availability.';
      } else if (errorString.contains('certificate') || errorString.contains('ssl')) {
        errorMessage = 'SSL certificate error. Please check your server configuration.';
      } else if (errorString.contains('host')) {
        errorMessage = 'Cannot reach server. Please check the server URL and your network connection.';
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

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jellyfin_server');
    
    // Dispose audio handler
    _audioHandler?.dispose();
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

  /// Handle authentication errors with token refresh attempt
  Future<bool> _handleAuthError(String operation) async {
    if (kDebugMode) {
      print('AppState: Authentication error during $operation, attempting token refresh...');
    }

    final refreshSuccess = await _attemptTokenRefresh();
    
    if (!refreshSuccess) {
      if (kDebugMode) {
        print('AppState: Token refresh failed, user needs to log in again');
      }
      
      // Only logout if token refresh fails
      logout();
      return false;
    }

    return true;
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
      
      bool hasValidCache = cachedAlbums != null && cachedArtists != null && 
                          cachedTracks != null && cachedPlaylists != null;
      
      if (kDebugMode) {
        print('AppState: Cache check - Albums: ${cachedAlbums?.length}, Artists: ${cachedArtists?.length}, Tracks: ${cachedTracks?.length}, Playlists: ${cachedPlaylists?.length}');
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
            albums: _albums,
            artists: _artists,
            tracks: _tracks,
            playlists: _playlists,
          );
        } catch (e) {
          if (kDebugMode) {
            print('Warning: Failed to update AudioHandler with cached data: $e');
          }
          // Don't fail completely - UI still works with cached data
        }
        
        _setLoading(false);
        
        if (kDebugMode) {
          print('Loaded library data from cache - Albums: ${_albums.length}, Artists: ${_artists.length}, Tracks: ${_tracks.length}, Playlists: ${_playlists.length}');
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
      if (e.toString().contains('401') || e.toString().contains('unauthorized')) {
        // Attempt token refresh before giving up
        if (kDebugMode) {
          print('AppState: Authentication error loading library, attempting token refresh...');
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
      } else if (e.toString().contains('timeout') || e.toString().contains('connection')) {
        userMessage = 'Connection timeout. Please check your network and server.';
      } else if (e.toString().contains('404') || e.toString().contains('not found')) {
        userMessage = 'Server not found. Please check your server URL.';
      } else if (e.toString().contains('500') || e.toString().contains('server error')) {
        userMessage = 'Server error. Please try again later.';
      }
      
      _setError(userMessage);
      _setLoading(false);
      
      // For Android Auto safety, ensure we have empty but valid collections
      if (_albums.isEmpty && _artists.isEmpty && _tracks.isEmpty && _playlists.isEmpty) {
        _albums = <Album>[];
        _artists = <Artist>[];
        _tracks = <Track>[];
        _playlists = <Playlist>[];
        
        // Update audio handler with empty but safe data
        try {
          _audioHandler?.updateMediaLibrary(
            albums: _albums,
            artists: _artists,
            tracks: _tracks,
            playlists: _playlists,
          );
        } catch (audioError) {
          if (kDebugMode) {
            print('Warning: Failed to update AudioHandler with empty data: $audioError');
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
      if (e.toString().contains('401') || e.toString().contains('unauthorized')) {
        // Attempt token refresh before giving up
        if (kDebugMode) {
          print('AppState: Authentication error during refresh, attempting token refresh...');
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
      } else if (e.toString().contains('timeout') || e.toString().contains('connection')) {
        userMessage = 'Connection timeout. Please check your network and server.';
      } else if (e.toString().contains('404') || e.toString().contains('not found')) {
        userMessage = 'Server not found. Please check your server URL.';
      } else if (e.toString().contains('500') || e.toString().contains('server error')) {
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
        _jellyfinService.getAlbums().catchError((e) {
          if (kDebugMode) {
            print('Warning: Failed to load albums: $e');
          }
          return <Album>[];
        }),
        _jellyfinService.getArtists().catchError((e) {
          if (kDebugMode) {
            print('Warning: Failed to load artists: $e');
          }
          return <Artist>[];
        }),
        _jellyfinService.getAllTracks().catchError((e) {
          if (kDebugMode) {
            print('Warning: Failed to load tracks: $e');
          }
          return <Track>[];
        }),
        _jellyfinService.getPlaylists().catchError((e) {
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
        print('AppState: Loaded fresh data - Albums: ${_albums.length}, Artists: ${_artists.length}, Tracks: ${_tracks.length}, Playlists: ${_playlists.length}');
      }
      
      // Update audio handler with media library for Android Auto browsing
      try {
        _audioHandler?.updateMediaLibrary(
          albums: _albums,
          artists: _artists,
          tracks: _tracks,
          playlists: _playlists,
        );
        
        if (kDebugMode) {
          print('AppState: Updated AudioHandler MediaBrowser with fresh library data');
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
      if (_albums.isEmpty && _artists.isEmpty && _tracks.isEmpty && _playlists.isEmpty) {
        _albums = <Album>[];
        _artists = <Artist>[];
        _tracks = <Track>[];
        _playlists = <Playlist>[];
        
        try {
          _audioHandler?.updateMediaLibrary(
            albums: _albums,
            artists: _artists,
            tracks: _tracks,
            playlists: _playlists,
          );
        } catch (audioError) {
          if (kDebugMode) {
            print('Warning: Failed to update AudioHandler with empty collections: $audioError');
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
      if (e.toString().contains('401') || e.toString().contains('unauthorized')) {
        if (kDebugMode) {
          print('AppState: Authentication error in background refresh - attempting token refresh');
        }
        
        // Attempt token refresh in background
        final refreshSuccess = await _attemptTokenRefresh();
        if (refreshSuccess) {
          if (kDebugMode) {
            print('AppState: Token refresh successful, retrying background data load');
          }
          // Try loading fresh data again after token refresh
          try {
            await _loadFreshData();
            notifyListeners();
            return; // Success, exit early
          } catch (retryError) {
            if (kDebugMode) {
              print('AppState: Retry after token refresh failed in background: $retryError');
            }
          }
        } else {
          if (kDebugMode) {
            print('AppState: Token refresh failed in background - user may need to re-login');
          }
        }
        // Don't logout in background refresh - let user discover the issue naturally
      }
      
      // Don't show error to user since we have cached data and this is background
      // But do set connection status if it's a network issue
      if (e.toString().contains('timeout') || e.toString().contains('connection')) {
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

  Future<List<Track>> getAlbumTracks(String albumId) async {
    try {
      // Try cache first
      final cachedTracks = await _cacheService.getCachedAlbumTracks(albumId);
      if (cachedTracks != null) {
        if (kDebugMode) {
          print('Loaded album tracks from cache for album: $albumId');
        }
        
        // Load fresh data in background and update cache
        _loadAlbumTracksInBackground(albumId);
        
        return cachedTracks;
      }
      
      // Load fresh data
      final tracks = await _jellyfinService.getAlbumTracks(albumId);
      
      // Cache the tracks
      await _cacheService.cacheAlbumTracks(albumId, tracks);
      
      return tracks;
    } catch (e) {
      _setError('Failed to load tracks: ${e.toString()}');
      return [];
    }
  }
  
  Future<void> _loadAlbumTracksInBackground(String albumId) async {
    try {
      final tracks = await _jellyfinService.getAlbumTracks(albumId);
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
      final cachedTracks = await _cacheService.getCachedPlaylistTracks(playlistId);
      if (cachedTracks != null) {
        if (kDebugMode) {
          print('Loaded ${cachedTracks.length} playlist tracks from cache for playlist: $playlistId');
        }
        
        // Load fresh data in background and update cache
        _loadPlaylistTracksInBackground(playlistId);
        
        return cachedTracks;
      }
      
      if (kDebugMode) {
        print('No cached playlist tracks found, loading fresh data for playlist: $playlistId');
      }
      
      // Load fresh data
      final tracks = await _jellyfinService.getPlaylistTracks(playlistId);
      
      if (kDebugMode) {
        print('Loaded ${tracks.length} fresh playlist tracks for playlist: $playlistId');
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
        print('Loading fresh playlist tracks in background for playlist: $playlistId');
      }
      
      final tracks = await _jellyfinService.getPlaylistTracks(playlistId);
      await _cacheService.cachePlaylistTracks(playlistId, tracks);
      
      if (kDebugMode) {
        print('Successfully refreshed ${tracks.length} playlist tracks in background for playlist: $playlistId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to refresh playlist tracks in background for playlist $playlistId: $e');
      }
    }
  }

  // Audio playback methods
  Future<void> playTrack(Track track) async {
    if (_audioHandler != null) {
      await _audioHandler!.playTrack(track);
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
    if (_audioHandler != null) {
      // Get the current player state
      final playerState = await _audioHandler!.playerStateStream.first;
      if (playerState.playing) {
        await _audioHandler!.pause();
      } else {
        await _audioHandler!.play();
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

  Future<void> shuffleAllTracks() async {
    if (_tracks.isNotEmpty && _audioHandler != null) {
      final shuffledTracks = List<Track>.from(_tracks);
      shuffledTracks.shuffle();
      await _audioHandler!.playPlaylist(shuffledTracks, 0);
      _audioHandler!.shuffle(); // Enable shuffle mode
      notifyListeners();
    }
  }

  Future<void> shuffleFavoriteTracks() async {
    final favoriteTracks = _tracks.where((track) => track.isFavorite).toList();
    if (favoriteTracks.isNotEmpty && _audioHandler != null) {
      final shuffledFavorites = List<Track>.from(favoriteTracks);
      shuffledFavorites.shuffle();
      await _audioHandler!.playPlaylist(shuffledFavorites, 0);
      _audioHandler!.shuffle(); // Enable shuffle mode
      notifyListeners();
    }
  }

  List<Track> get favoriteTracks => _tracks.where((track) => track.isFavorite).toList();

  List<Album> get favoriteAlbums => _albums.where((album) => album.isFavorite).toList();

  Future<void> toggleFavorite(Track track) async {
    try {
      final success = await _jellyfinService.toggleFavorite(track.id, track.isFavorite);
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
        }
      }
    } catch (e) {
      _setError('Failed to toggle favorite: ${e.toString()}');
    }
  }

  Future<void> toggleAlbumFavorite(Album album) async {
    try {
      final success = await _jellyfinService.toggleFavorite(album.id, album.isFavorite);
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
      final newPlaylist = await _jellyfinService.createPlaylist(name);
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
      return await _jellyfinService.addToPlaylist(playlistId, trackId);
    } catch (e) {
      _setError('Failed to add to playlist: ${e.toString()}');
      return false;
    }
  }

  Future<bool> renamePlaylist(String playlistId, String newName) async {
    try {
      final success = await _jellyfinService.renamePlaylist(playlistId, newName);
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
      final success = await _jellyfinService.removePlaylist(playlistId);
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

  Future<void> toggleSmartCrossfade(bool enabled) async {
    _smartCrossfadeEnabled = enabled;
    
    // Update the audio handler with the new crossfade setting
    _audioHandler?.setSmartCrossfade(enabled);
    
    // Save the setting to preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('smart_crossfade_enabled', enabled);
    
    notifyListeners();
  }

  Future<void> toggleNormalizeVolume(bool enabled) async {
    _normalizeVolumeEnabled = enabled;
    
    // Update the audio handler with the new normalize volume setting
    _audioHandler?.setNormalizeVolume(enabled);
    
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

  Future<void> _loadUserSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _smartCrossfadeEnabled = prefs.getBool('smart_crossfade_enabled') ?? true;
    _normalizeVolumeEnabled = prefs.getBool('normalize_volume_enabled') ?? false;
    _gaplessPlaybackEnabled = prefs.getBool('gapless_playback_enabled') ?? true;
    _oledDarkModeEnabled = prefs.getBool('oled_dark_mode_enabled') ?? true;
    _showAlbumArtEnabled = prefs.getBool('show_album_art_enabled') ?? true;
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
      
      return {
        'data_cache': dataStats,
        'image_cache_size': imageSize,
      };
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
      await _jellyfinService.getAlbums().timeout(const Duration(seconds: 5));
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
      _isLoggedIn = true; // We're setting this to true to bypass the login screen
      
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
      
      // Try to initialize audio handler for offline playback
      // Only initialize audio service on Android (needed for background audio and Android Auto)
      if (Platform.isAndroid) {
        try {
          _audioHandler = await AudioService.init(
            builder: () => DoudouAudioHandler(_jellyfinService, _downloadService),
            config: const AudioServiceConfig(
              androidNotificationChannelId: 'gitlab.openlyst.doudou.channel.audio',
              androidNotificationChannelName: 'Doudou Music',
              androidNotificationOngoing: true,
            ),
          );
          
          // Apply user settings to the audio handler
          _audioHandler?.setSmartCrossfade(_smartCrossfadeEnabled);
          _audioHandler?.setNormalizeVolume(_normalizeVolumeEnabled);
          _audioHandler?.setGaplessPlayback(_gaplessPlaybackEnabled);
          
          // Set up listeners for automatic UI updates
          _setupAudioHandlerListeners();
          
        } catch (audioError) {
          if (kDebugMode) {
            print('Failed to initialize audio service for offline mode: $audioError');
          }
          // Continue without audio service
        }
      } else {
        if (kDebugMode) {
          print('Audio service initialization skipped on non-Android platform (offline mode)');
        }
        // On non-Android platforms, we don't use AudioService
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
      
      if (cachedAlbums != null && cachedAlbums.isNotEmpty) _albums = cachedAlbums;
      if (cachedArtists != null && cachedArtists.isNotEmpty) _artists = cachedArtists;
      if (cachedTracks != null && cachedTracks.isNotEmpty) _tracks = cachedTracks;
      if (cachedPlaylists != null && cachedPlaylists.isNotEmpty) _playlists = cachedPlaylists;
      
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
    _tracks = _tracks.where((track) => 
      _downloadService.isTrackDownloaded(track.id)
    ).toList();
    
    // Filter albums to only those with downloaded tracks
    _albums = _albums.where((album) => 
      _tracks.any((track) => track.albumId == album.id)
    ).toList();
    
    // Filter artists to only those with downloaded tracks
    _artists = _artists.where((artist) => 
      _tracks.any((track) => track.artistName == artist.name)
    ).toList();
    
    // Filter playlists to only those with downloaded tracks
    // Note: This is more complex as we'd need to check playlist contents
    // For now, we'll keep all playlists but they'll show filtered content
  }

  void _filterContentForOfflineMode() {
    if (!_isOfflineMode) return;
    
    // Filter tracks to only show downloaded ones
    final downloadedTrackIds = _downloadService.downloadedTracks.keys.toSet();
    _tracks = _tracks.where((track) => downloadedTrackIds.contains(track.id)).toList();
    
    // Filter albums to only show those with downloaded tracks
    _albums = _albums.where((album) => 
      _tracks.any((track) => track.albumId == album.id)
    ).toList();
    
    // Filter artists to only show those with downloaded tracks
    _artists = _artists.where((artist) =>
      _tracks.any((track) => track.artistName == artist.name)
    ).toList();
    
    // Keep playlists but they will show filtered content when opened
    // The playlist detail screens will handle filtering their tracks
    
    if (kDebugMode) {
      print('Filtered content for offline mode: ${_tracks.length} tracks, ${_albums.length} albums, ${_artists.length} artists');
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
