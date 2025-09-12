import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/jellyfin_models.dart';
import 'audio_state_manager.dart';

/// Handles saving and loading playback state for session persistence
/// Thread-safe implementation with debouncing to prevent conflicting saves
class AudioStatePersistence {
  final AudioStateManager _stateManager;
  Timer? _saveStateTimer;
  Timer? _debounceSaveTimer;
  
  // Debouncing and conflict resolution
  bool _isSaving = false;
  Duration? _pendingPosition;
  bool? _pendingIsPlaying;
  
  AudioStatePersistence(this._stateManager);
  
  /// Thread-safe debounced save to prevent conflicting operations
  Future<void> savePlaybackState(Duration position, bool isPlaying) async {
    // Store pending values for debouncing
    _pendingPosition = position;
    _pendingIsPlaying = isPlaying;
    
    // Cancel existing debounce timer and start new one
    _debounceSaveTimer?.cancel();
    _debounceSaveTimer = Timer(const Duration(milliseconds: 300), () {
      _executeSavePlaybackState();
    });
  }
  
  /// Internal method that actually performs the save operation
  Future<void> _executeSavePlaybackState() async {
    // Prevent concurrent saves
    if (_isSaving) {
      if (kDebugMode) {
        print('Save already in progress, skipping...');
      }
      return;
    }
    
    _isSaving = true;
    
    try {
      final position = _pendingPosition ?? Duration.zero;
      final isPlaying = _pendingIsPlaying ?? false;
      
      final prefs = await SharedPreferences.getInstance();
      
      // Save current playlist
      if (_stateManager.playlist.isNotEmpty) {
        final playlistJson = _stateManager.playlist.map((track) => track.toJson()).toList();
        await prefs.setString('current_playlist', jsonEncode(playlistJson));
        await prefs.setInt('current_index', _stateManager.currentIndex);
        await prefs.setBool('is_shuffled', _stateManager.isShuffled);
        await prefs.setBool('radio_mode_enabled', _stateManager.radioModeEnabled);
        
        // Save current position and playing state
        await prefs.setInt('playback_position', position.inMilliseconds);
        await prefs.setBool('was_playing', isPlaying);
        
        if (_stateManager.currentTrack != null) {
          await prefs.setString('current_track_id', _stateManager.currentTrack!.id);
        }
        
        if (kDebugMode) {
          print('Debounced save completed: ${position.inMilliseconds}ms, playing: $isPlaying');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving playback state: $e');
      }
    } finally {
      _isSaving = false;
      // Clear pending values after successful save
      _pendingPosition = null;
      _pendingIsPlaying = null;
    }
  }
  
  Future<PlaybackStateData?> loadPlaybackState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final playlistString = prefs.getString('current_playlist');
      if (playlistString != null) {
        final playlistJson = jsonDecode(playlistString) as List;
        final playlist = playlistJson.map((json) => Track.fromJson(json)).toList();
        
        final currentIndex = prefs.getInt('current_index') ?? 0;
        final isShuffled = prefs.getBool('is_shuffled') ?? false;
        final radioModeEnabled = prefs.getBool('radio_mode_enabled') ?? false;
        final wasPlaying = prefs.getBool('was_playing') ?? false;
        final savedPosition = prefs.getInt('playback_position') ?? 0;
        
        if (playlist.isNotEmpty && currentIndex < playlist.length) {
          // Update state manager with loaded data
          _stateManager.setPlaylist(playlist);
          _stateManager.setCurrentIndex(currentIndex);
          _stateManager.setShuffled(isShuffled);
          _stateManager.setRadioModeEnabled(radioModeEnabled);
          
          return PlaybackStateData(
            playlist: playlist,
            currentIndex: currentIndex,
            isShuffled: isShuffled,
            radioModeEnabled: radioModeEnabled,
            wasPlaying: wasPlaying,
            savedPosition: Duration(milliseconds: savedPosition),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading playback state: $e');
      }
    }
    
    return null;
  }
  
  void startPeriodicSaving(Duration position, bool isPlaying) {
    stopPeriodicSaving(); // Clear any existing timer
    _saveStateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      savePlaybackState(position, isPlaying);
    });
  }
  
  void stopPeriodicSaving() {
    _saveStateTimer?.cancel();
    _saveStateTimer = null;
  }
  
  void dispose() {
    stopPeriodicSaving();
  }
}

/// Data class for holding loaded playback state
class PlaybackStateData {
  final List<Track> playlist;
  final int currentIndex;
  final bool isShuffled;
  final bool radioModeEnabled;
  final bool wasPlaying;
  final Duration savedPosition;
  
  PlaybackStateData({
    required this.playlist,
    required this.currentIndex,
    required this.isShuffled,
    required this.radioModeEnabled,
    required this.wasPlaying,
    required this.savedPosition,
  });
}
