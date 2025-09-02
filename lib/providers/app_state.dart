import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'dart:io';
import '../models/jellyfin_models.dart';
import '../services/jellyfin_service.dart';
import '../services/audio_handler.dart';
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
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing app: $e');
      }
      _setError('Failed to initialize app: ${e.toString()}');
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
          // Try to validate credentials
          final isValid = await _jellyfinService.validateCredentials();
          
          if (isValid) {
            // If successful, we're logged in
            _isLoggedIn = true;
            
            // Initialize cache service first
            await _cacheService.initialize();
            
            // Try to initialize audio handler, but don't fail if it doesn't work
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
              
              // Notify listeners after audio handler is ready (this will update UI with restored state)
              notifyListeners();
            } catch (audioError) {
              if (kDebugMode) {
                print('Failed to initialize audio service: $audioError');
              }
              // Continue without audio service
            }
            
            notifyListeners();
            
            // Load initial data in background
            loadLibraryData();
          } else {
            // Clear invalid credentials
            await prefs.remove('jellyfin_server');
            _isLoggedIn = false;
            notifyListeners();
          }
        } catch (authError) {
          if (kDebugMode) {
            print('Saved credentials are invalid: $authError');
          }
          // Clear invalid credentials
          await prefs.remove('jellyfin_server');
          _isLoggedIn = false;
          notifyListeners();
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
        _isLoggedIn = true;
        
        // Initialize cache service first
        await _cacheService.initialize();
        
        // Try to initialize audio handler after successful login
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
        
        await _saveServer();
        await loadLibraryData();
        _setLoading(false);
        return true;
      } else {
        _setError('Authentication failed. Please check your credentials.');
        _setLoading(false);
        return false;
      }
    } on DioException catch (e) {
      // Handle network errors with user-friendly messages
      if (e.error is NetworkException) {
        final networkError = e.error as NetworkException;
        _setError(networkError.message);
      } else {
        _setError('Network error. Please check your connection and try again.');
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
      
      _setError(errorMessage);
      _setLoading(false);
      return false;
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

  Future<void> loadLibraryData() async {
    if (!_isLoggedIn) return;

    _setLoading(true);
    _clearError();

    try {
      // Try to load from cache first
      final cachedAlbums = await _cacheService.getCachedAlbums();
      final cachedArtists = await _cacheService.getCachedArtists();
      final cachedTracks = await _cacheService.getCachedTracks();
      final cachedPlaylists = await _cacheService.getCachedPlaylists();
      
      bool hasValidCache = cachedAlbums != null && cachedArtists != null && 
                          cachedTracks != null && cachedPlaylists != null;
      
      if (hasValidCache) {
        // Use cached data
        _albums = cachedAlbums;
        _artists = cachedArtists;
        _tracks = cachedTracks;
        _playlists = cachedPlaylists;
        
        _setLoading(false);
        
        if (kDebugMode) {
          print('Loaded library data from cache');
        }
        
        // Load fresh data in background and update cache
        _loadFreshDataInBackground();
      } else {
        // Load fresh data
        await _loadFreshData();
      }
    } catch (e) {
      _setError('Failed to load library: ${e.toString()}');
      _setLoading(false);
    }
  }
  
  Future<void> _loadFreshData() async {
    final albumsFuture = _jellyfinService.getAlbums();
    final artistsFuture = _jellyfinService.getArtists();
    final tracksFuture = _jellyfinService.getAllTracks();
    final playlistsFuture = _jellyfinService.getPlaylists();
    
    final results = await Future.wait([albumsFuture, artistsFuture, tracksFuture, playlistsFuture]);
    
    _albums = results[0] as List<Album>;
    _artists = results[1] as List<Artist>;
    _tracks = results[2] as List<Track>;
    _playlists = results[3] as List<Playlist>;
    
    // Cache the fresh data
    await Future.wait([
      _cacheService.cacheAlbums(_albums),
      _cacheService.cacheArtists(_artists),
      _cacheService.cacheTracks(_tracks),
      _cacheService.cachePlaylists(_playlists),
    ]);
    
    _setLoading(false);
    
    if (kDebugMode) {
      print('Loaded fresh library data and cached it');
    }
  }
  
  Future<void> _loadFreshDataInBackground() async {
    try {
      await _loadFreshData();
      // Notify listeners to update UI with fresh data
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load fresh data in background: $e');
      }
      // Don't show error to user since we have cached data
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
      // Lost connection - enter offline mode
      await _enterOfflineMode();
    } else if (!wasConnected && _isConnected) {
      // Regained connection - exit offline mode if possible
      await _exitOfflineMode();
    }
    
    notifyListeners();
  }

  Future<void> _enterOfflineMode() async {
    if (kDebugMode) {
      print('Entering offline mode');
    }
    
    _isOfflineMode = true;
    
    // Load downloaded tracks for offline access
    await _loadOfflineData();
    
    // Clear online-only data but keep user logged in
    // This allows access to downloads without re-authentication
    _clearError();
    
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

  // Public method to manually check connectivity
  Future<void> checkConnectivity() async {
    await _updateConnectivityState();
  }
}
