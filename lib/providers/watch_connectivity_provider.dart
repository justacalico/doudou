import 'package:flutter/foundation.dart';
import '../models/jellyfin_models.dart';
import '../services/watch_connectivity_service.dart';

class WatchConnectivityProvider extends ChangeNotifier {
  final WatchConnectivityService _watchService = WatchConnectivityService();
  
  bool _isWatchSupported = false;
  bool _isWatchReachable = false;
  Track? _currentTrack;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1.0;

  bool get isWatchSupported => _isWatchSupported;
  bool get isWatchReachable => _isWatchReachable;
  Track? get currentTrack => _currentTrack;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  double get volume => _volume;

  WatchConnectivityProvider() {
    _initializeWatchConnectivity();
  }

  Future<void> _initializeWatchConnectivity() async {
    await _watchService.initialize();
    
    _isWatchSupported = _watchService.isSupported;
    _isWatchReachable = _watchService.isReachable;
    
    // Listen to reachability changes
    _watchService.reachabilityStream.listen((reachable) {
      _isWatchReachable = reachable;
      notifyListeners();
    });
    
    // Listen to messages from watch
    _watchService.messageStream.listen(_handleWatchMessage);
    
    notifyListeners();
  }

  void _handleWatchMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    final action = message['action'] as String?;
    final data = message['data'];
    
    switch (type) {
      case 'playback_control':
        _handlePlaybackControl(action);
        break;
      case 'request':
        _handleRequest(data);
        break;
    }
  }

  void _handlePlaybackControl(String? action) {
    // These would typically trigger actions on your audio service
    // For now, we'll just notify listeners that a control was received
    switch (action) {
      case 'play':
        // Trigger play action in your audio service
        break;
      case 'pause':
        // Trigger pause action in your audio service
        break;
      case 'next':
        // Trigger next track action in your audio service
        break;
      case 'previous':
        // Trigger previous track action in your audio service
        break;
    }
  }

  void _handleRequest(String? data) {
    switch (data) {
      case 'current_song':
        sendCurrentTrack();
        break;
      case 'playlists':
        // You would get playlists from your data source and send them
        sendPlaylists([]);
        break;
    }
  }

  // Methods to update the watch with current app state
  
  void updateCurrentTrack(Track? track) {
    if (_currentTrack?.id != track?.id) {
      _currentTrack = track;
      sendCurrentTrack();
      notifyListeners();
    }
  }

  void updatePlaybackState({
    required bool isPlaying,
    Duration? position,
    Duration? duration,
  }) {
    bool hasChanges = false;
    
    if (_isPlaying != isPlaying) {
      _isPlaying = isPlaying;
      hasChanges = true;
    }
    
    if (position != null && _position != position) {
      _position = position;
      hasChanges = true;
    }
    
    if (duration != null && _duration != duration) {
      _duration = duration;
      hasChanges = true;
    }
    
    if (hasChanges) {
      sendPlaybackState();
      notifyListeners();
    }
  }

  void updateVolume(double volume) {
    if (_volume != volume) {
      _volume = volume;
      sendVolumeLevel();
      notifyListeners();
    }
  }

  // Methods to send data to watch
  
  Future<void> sendCurrentTrack() async {
    if (!_isWatchSupported || !_isWatchReachable) return;
    await _watchService.sendCurrentTrack(_currentTrack);
  }

  Future<void> sendPlaybackState() async {
    if (!_isWatchSupported || !_isWatchReachable) return;
    await _watchService.sendPlaybackState(
      isPlaying: _isPlaying,
      position: _position,
      duration: _duration,
    );
  }

  Future<void> sendPlaylists(List<Playlist> playlists) async {
    if (!_isWatchSupported || !_isWatchReachable) return;
    await _watchService.sendPlaylists(playlists);
  }

  Future<void> sendVolumeLevel() async {
    if (!_isWatchSupported || !_isWatchReachable) return;
    await _watchService.sendVolumeLevel(_volume);
  }

  @override
  void dispose() {
    _watchService.dispose();
    super.dispose();
  }
}