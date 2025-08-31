import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audio_service/audio_service.dart';
import 'dart:convert';
import '../models/jellyfin_models.dart';
import '../services/jellyfin_service.dart';
import '../services/audio_handler.dart';

class AppState extends ChangeNotifier {
  final JellyfinService _jellyfinService = JellyfinService();
  DoudouAudioHandler? _audioHandler;
  
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _errorMessage;
  List<Album> _albums = [];
  List<Artist> _artists = [];
  List<Track> _tracks = [];
  List<Playlist> _playlists = [];
  bool _smartCrossfadeEnabled = false;
  bool _normalizeVolumeEnabled = false;
  bool _oledDarkModeEnabled = true;
  bool _showAlbumArtEnabled = true;
  
  // Getters
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Album> get albums => _albums;
  List<Artist> get artists => _artists;
  List<Track> get tracks => _tracks;
  List<Playlist> get playlists => _playlists;
  JellyfinService get jellyfinService => _jellyfinService;
  DoudouAudioHandler? get audioHandler => _audioHandler;
  bool get smartCrossfadeEnabled => _smartCrossfadeEnabled;

  AppState() {
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _loadUserSettings();
    await _loadSavedServer();
  }

  Future<void> _loadSavedServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serverJson = prefs.getString('jellyfin_server');
      
      if (serverJson != null) {
        final serverData = jsonDecode(serverJson);
        final server = JellyfinServer.fromJson(serverData);
        _jellyfinService.setServer(server);
        _isLoggedIn = true;
        
        // Initialize audio handler
        _audioHandler = await AudioService.init(
          builder: () => DoudouAudioHandler(_jellyfinService),
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'com.example.doudou.channel.audio',
            androidNotificationChannelName: 'Doudou Music',
            androidNotificationOngoing: true,
          ),
        );
        
        // Apply user settings to the audio handler
        _audioHandler?.setSmartCrossfade(_smartCrossfadeEnabled);
        
        notifyListeners();
        
        // Load initial data
        await loadLibraryData();
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
        
        // Initialize audio handler after successful login
        _audioHandler = await AudioService.init(
          builder: () => DoudouAudioHandler(_jellyfinService),
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'com.example.doudou.channel.audio',
            androidNotificationChannelName: 'Doudou Music',
            androidNotificationOngoing: true,
          ),
        );
        
        // Apply user settings to the audio handler
        _audioHandler?.setSmartCrossfade(_smartCrossfadeEnabled);
        
        await _saveServer();
        await loadLibraryData();
        _setLoading(false);
        return true;
      } else {
        _setError('Authentication failed. Please check your credentials.');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('Connection failed: ${e.toString()}');
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
      final albumsFuture = _jellyfinService.getAlbums();
      final artistsFuture = _jellyfinService.getArtists();
      final tracksFuture = _jellyfinService.getAllTracks();
      final playlistsFuture = _jellyfinService.getPlaylists();
      
      final results = await Future.wait([albumsFuture, artistsFuture, tracksFuture, playlistsFuture]);
      
      _albums = results[0] as List<Album>;
      _artists = results[1] as List<Artist>;
      _tracks = results[2] as List<Track>;
      _playlists = results[3] as List<Playlist>;
      
      _setLoading(false);
    } catch (e) {
      _setError('Failed to load library: ${e.toString()}');
      _setLoading(false);
    }
  }

  Future<List<Track>> getAlbumTracks(String albumId) async {
    try {
      return await _jellyfinService.getAlbumTracks(albumId);
    } catch (e) {
      _setError('Failed to load tracks: ${e.toString()}');
      return [];
    }
  }

  Future<List<Track>> getPlaylistTracks(String playlistId) async {
    try {
      return await _jellyfinService.getPlaylistTracks(playlistId);
    } catch (e) {
      _setError('Failed to load playlist tracks: ${e.toString()}');
      return [];
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
    _audioHandler?.addToQueue(track); // Add next functionality in handler if needed
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

  Future<void> _loadUserSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _smartCrossfadeEnabled = prefs.getBool('smart_crossfade_enabled') ?? false;
  }
}
