import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/jellyfin_models.dart';
import '../services/jellyfin_service.dart';

class AppState extends ChangeNotifier {
  final JellyfinService _jellyfinService = JellyfinService();
  
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _errorMessage;
  List<Album> _albums = [];
  List<Artist> _artists = [];
  
  // Getters
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Album> get albums => _albums;
  List<Artist> get artists => _artists;
  JellyfinService get jellyfinService => _jellyfinService;

  AppState() {
    _loadSavedServer();
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
    
    _isLoggedIn = false;
    _albums.clear();
    _artists.clear();
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
      
      final results = await Future.wait([albumsFuture, artistsFuture]);
      
      _albums = results[0] as List<Album>;
      _artists = results[1] as List<Artist>;
      
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
}
