import 'package:flutter/foundation.dart';
import '../../models/jellyfin_models.dart';

/// Manages the internal state of the audio player including playlist, queue, and playback settings
class AudioStateManager {
  // Playlist and queue state
  List<Track> _playlist = [];
  List<Track> _queue = [];
  int _currentIndex = 0;
  Track? _currentTrack;
  
  // Playback configuration
  bool _isShuffled = false;
  bool _smartCrossfadeEnabled = false;
  bool _normalizeVolumeEnabled = false;
  bool _gaplessPlaybackEnabled = true;
  bool _radioModeEnabled = false;
  final Duration _crossfadeDuration = const Duration(seconds: 3);
  
  // Completion tracking to prevent race conditions
  bool _isHandlingCompletion = false;
  bool _isTransitioning = false;
  
  // Skip-to-previous behavior tracking
  DateTime? _lastSkipToPreviousTime;
  static const Duration _skipToPreviousThreshold = Duration(seconds: 5);
  static const double _restartThresholdPercentage = 0.20; // 20% of song duration
  
  // Getters for playlist and queue
  Track? get currentTrack => _currentTrack;
  List<Track> get playlist => _playlist;
  List<Track> get queueTracks => _queue;
  List<Track> get upNext => _currentIndex < _queue.length - 1 
      ? _queue.sublist(_currentIndex + 1) 
      : [];
  int get currentIndex => _currentIndex;
  bool get hasNext => _currentIndex < _playlist.length - 1;
  bool get hasPrevious => _currentIndex > 0;
  bool get isShuffled => _isShuffled;
  bool get radioModeEnabled => _radioModeEnabled;
  int get queueLength => _queue.length;
  
  // Getters for playback configuration
  bool get smartCrossfadeEnabled => _smartCrossfadeEnabled;
  bool get normalizeVolumeEnabled => _normalizeVolumeEnabled;
  bool get gaplessPlaybackEnabled => _gaplessPlaybackEnabled;
  Duration get crossfadeDuration => _crossfadeDuration;
  
  // Getters for completion tracking
  bool get isHandlingCompletion => _isHandlingCompletion;
  bool get isTransitioning => _isTransitioning;
  DateTime? get lastSkipToPreviousTime => _lastSkipToPreviousTime;
  Duration get skipToPreviousThreshold => _skipToPreviousThreshold;
  double get restartThresholdPercentage => _restartThresholdPercentage;
  
  // Setters for playlist and queue
  void setPlaylist(List<Track> tracks) {
    _playlist = tracks;
    _queue = List.from(tracks);
  }
  
  void setCurrentIndex(int index) {
    if (index >= 0 && index < _playlist.length) {
      _currentIndex = index;
      _currentTrack = _playlist[index];
    }
  }
  
  void setCurrentTrack(Track? track) {
    _currentTrack = track;
  }
  
  // Setters for playback configuration
  void setShuffled(bool shuffled) {
    _isShuffled = shuffled;
  }
  
  void setSmartCrossfadeEnabled(bool enabled) {
    _smartCrossfadeEnabled = enabled;
    if (kDebugMode) {
      print('Smart crossfade ${enabled ? 'enabled' : 'disabled'}');
    }
  }
  
  void setNormalizeVolumeEnabled(bool enabled) {
    _normalizeVolumeEnabled = enabled;
    if (kDebugMode) {
      print('Volume normalization ${enabled ? 'enabled' : 'disabled'}');
    }
  }
  
  void setGaplessPlaybackEnabled(bool enabled) {
    _gaplessPlaybackEnabled = enabled;
    if (kDebugMode) {
      print('Gapless playback ${enabled ? 'enabled' : 'disabled'}');
    }
  }
  
  void setRadioModeEnabled(bool enabled) {
    _radioModeEnabled = enabled;
    if (kDebugMode) {
      print('Radio mode ${enabled ? 'enabled' : 'disabled'}');
    }
  }
  
  // Setters for completion tracking
  void setHandlingCompletion(bool handling) {
    _isHandlingCompletion = handling;
  }
  
  void setTransitioning(bool transitioning) {
    _isTransitioning = transitioning;
  }
  
  void setLastSkipToPreviousTime(DateTime? time) {
    _lastSkipToPreviousTime = time;
  }
  
  // Playlist manipulation methods
  void addToPlaylist(Track track) {
    _playlist.add(track);
    _queue.add(track);
  }
  
  void insertIntoPlaylist(int index, Track track) {
    if (index >= 0 && index <= _playlist.length) {
      _playlist.insert(index, track);
      _queue.insert(index, track);
      
      // Adjust current index if needed
      if (index <= _currentIndex) {
        _currentIndex++;
      }
    }
  }
  
  void removeFromPlaylist(int index) {
    if (index >= 0 && index < _playlist.length && index != _currentIndex) {
      _playlist.removeAt(index);
      _queue.removeAt(index);
      
      // Adjust current index if needed
      if (index < _currentIndex) {
        _currentIndex--;
      }
    }
  }
  
  void clearPlaylist() {
    _playlist.clear();
    _queue.clear();
    _currentIndex = 0;
    _currentTrack = null;
    _isShuffled = false;
  }
  
  bool incrementCurrentIndex() {
    if (_currentIndex < _playlist.length - 1) {
      _currentIndex++;
      _currentTrack = _playlist[_currentIndex];
      return true;
    }
    return false;
  }
  
  bool decrementCurrentIndex() {
    if (_currentIndex > 0) {
      _currentIndex--;
      _currentTrack = _playlist[_currentIndex];
      return true;
    }
    return false;
  }
}
