import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/jellyfin_models.dart';
import '../services/jellyfin_service.dart';
import '../services/audio_service.dart';

class AppState extends ChangeNotifier {
  final JellyfinService _jellyfinService = JellyfinService();
  AudioPlayerService? _audioService;
  
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _errorMessage;
  List<Album> _albums = [];
  List<Artist> _artists = [];
  List<Track> _tracks = [];
  List<Playlist> _playlists = [];
  bool _smartCrossfadeEnabled = false;
  
  // Getters
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Album> get albums => _albums;
  List<Artist> get artists => _artists;
  List<Track> get tracks => _tracks;
  List<Playlist> get playlists => _playlists;
  JellyfinService get jellyfinService => _jellyfinService;
  AudioPlayerService? get audioService => _audioService;
  bool get smartCrossfadeEnabled => _smartCrossfadeEnabled;

  AppState() {
    _loadSavedServer();
    _loadUserSettings();
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
        
        // Initialize audio service
        _audioService = AudioPlayerService(_jellyfinService);
        
        // Listen to audio service changes and notify listeners
        _audioService!.addListener(() {
          notifyListeners();
        });
        
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
        
        // Initialize audio service after successful login
        _audioService = AudioPlayerService(_jellyfinService);
        
        // Listen to audio service changes and notify listeners
        _audioService!.addListener(() {
          notifyListeners();
        });
        
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
    
    // Dispose audio service
    _audioService?.dispose();
    _audioService = null;
    
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
    if (_audioService != null) {
      await _audioService!.playTrack(track);
      notifyListeners();
    }
  }

  Future<void> playPlaylist(List<Track> tracks, int startIndex) async {
    if (_audioService != null) {
      await _audioService!.playPlaylist(tracks, startIndex);
      notifyListeners();
    }
  }

  Future<void> playPause() async {
    if (_audioService != null) {
      // Get the current player state
      final playerState = await _audioService!.playerStateStream.first;
      if (playerState.playing) {
        await _audioService!.pause();
      } else {
        await _audioService!.play();
      }
      notifyListeners();
    }
  }

  Future<void> skipToNext() async {
    if (_audioService != null) {
      await _audioService!.skipToNext();
      notifyListeners();
    }
  }

  Future<void> skipToPrevious() async {
    if (_audioService != null) {
      await _audioService!.skipToPrevious();
      notifyListeners();
    }
  }

  Future<void> skipToIndex(int index) async {
    if (_audioService != null) {
      await _audioService!.skipToIndex(index);
      notifyListeners();
    }
  }

  Future<void> seekTo(Duration position) async {
    if (_audioService != null) {
      await _audioService!.seek(position);
    }
  }

  void addToQueue(Track track) {
    _audioService?.addToQueue(track);
    notifyListeners();
  }

  void addNextInQueue(Track track) {
    _audioService?.addNextInQueue(track);
    notifyListeners();
  }

  void clearQueue() {
    _audioService?.clearQueue();
    notifyListeners();
  }

  // Queue getters
  List<Track> get queue => _audioService?.queue ?? [];
  List<Track> get upNext => _audioService?.upNext ?? [];
  
  void removeFromQueue(int index) {
    _audioService?.removeFromQueue(index);
    notifyListeners();
  }
  
  void reorderQueue(int oldIndex, int newIndex) {
    _audioService?.reorderQueue(oldIndex, newIndex);
    notifyListeners();
  }

  Future<void> shuffleAllTracks() async {
    if (_tracks.isNotEmpty && _audioService != null) {
      final shuffledTracks = List<Track>.from(_tracks);
      shuffledTracks.shuffle();
      await _audioService!.playPlaylist(shuffledTracks, 0);
      _audioService!.shuffle(); // Enable shuffle mode
      notifyListeners();
    }
  }

  Future<void> shuffleFavoriteTracks() async {
    final favoriteTracks = _tracks.where((track) => track.isFavorite).toList();
    if (favoriteTracks.isNotEmpty && _audioService != null) {
      final shuffledFavorites = List<Track>.from(favoriteTracks);
      shuffledFavorites.shuffle();
      await _audioService!.playPlaylist(shuffledFavorites, 0);
      _audioService!.shuffle(); // Enable shuffle mode
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
    
    // Update the audio service with the new crossfade setting
    _audioService?.setSmartCrossfade(enabled);
    
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
