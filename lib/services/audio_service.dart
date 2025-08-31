import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/jellyfin_models.dart';
import 'jellyfin_service.dart';

class AudioPlayerService extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  final JellyfinService _jellyfinService;
  
  List<Track> _playlist = [];
  List<Track> _queue = [];
  int _currentIndex = 0;
  Track? _currentTrack;
  bool _isShuffled = false;
  List<Track> _originalPlaylist = [];
  bool _smartCrossfadeEnabled = false;
  final Duration _crossfadeDuration = const Duration(seconds: 3);
  
  // Preloading and caching
  final Map<String, AudioPlayer> _preloadedPlayers = {};
  final Set<String> _preloadingTracks = {};
  static const int _maxPreloadedTracks = 3;

  AudioPlayerService(this._jellyfinService) {
    _init();
  }

  void _init() {
    // Listen to player state changes
    _player.playerStateStream.listen((playerState) {
      notifyListeners();
    });

    // Listen to position changes
    _player.positionStream.listen((position) {
      notifyListeners();
    });

    // Auto-play next track when current track completes
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        skipToNext();
      }
    });
  }

  Future<void> play() => _player.play();

  Future<void> pause() => _player.pause();

  Future<void> stop() => _player.stop();

  Future<void> skipToNext() async {
    if (_currentIndex < _playlist.length - 1) {
      _currentIndex++;
      await _playCurrentTrack();
    }
  }

  Future<void> skipToPrevious() async {
    if (_currentIndex > 0) {
      _currentIndex--;
      await _playCurrentTrack();
    }
  }

  Future<void> skipToIndex(int index) async {
    if (index >= 0 && index < _playlist.length) {
      _currentIndex = index;
      await _playCurrentTrack();
    }
  }

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> playTrack(Track track) async {
    _playlist = [track];
    _currentIndex = 0;
    await _playCurrentTrack();
  }

  Future<void> playPlaylist(List<Track> tracks, int startIndex) async {
    if (tracks.isEmpty) return;
    
    _playlist = tracks;
    _originalPlaylist = List.from(tracks);
    _queue = List.from(tracks);
    _currentIndex = startIndex.clamp(0, tracks.length - 1);
    _isShuffled = false;
    await _playCurrentTrack();
  }

  void addToQueue(Track track) {
    _queue.add(track);
    _playlist.add(track);
    notifyListeners();
  }

  void addNextInQueue(Track track) {
    final insertIndex = _currentIndex + 1;
    _queue.insert(insertIndex, track);
    _playlist.insert(insertIndex, track);
    notifyListeners();
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length || index == _currentIndex) return;
    
    _queue.removeAt(index);
    _playlist.removeAt(index);
    
    // Adjust current index if needed
    if (index < _currentIndex) {
      _currentIndex--;
    }
    
    notifyListeners();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length || 
        newIndex < 0 || newIndex >= _queue.length ||
        oldIndex == _currentIndex || newIndex == _currentIndex) {
      return;
    }
    
    final track = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, track);
    
    final playlistTrack = _playlist.removeAt(oldIndex);
    _playlist.insert(newIndex, playlistTrack);
    
    // Adjust current index if needed
    if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex++;
    }
    
    notifyListeners();
  }

  void shuffle() {
    if (_playlist.length <= 1) return;
    
    _isShuffled = true;
    final currentTrack = _playlist[_currentIndex];
    
    // Remove current track from shuffling
    final remainingTracks = List<Track>.from(_playlist);
    remainingTracks.removeAt(_currentIndex);
    
    // Shuffle remaining tracks
    remainingTracks.shuffle();
    
    // Create new playlist with current track first, then shuffled tracks
    _playlist = [currentTrack, ...remainingTracks];
    _queue = List.from(_playlist);
    _currentIndex = 0;
    
    notifyListeners();
  }

  void unshuffle() {
    if (!_isShuffled || _originalPlaylist.isEmpty) return;
    
    _isShuffled = false;
    final currentTrack = _currentTrack;
    
    _playlist = List.from(_originalPlaylist);
    _queue = List.from(_playlist);
    
    // Find the current track in the original playlist
    if (currentTrack != null) {
      _currentIndex = _playlist.indexWhere((track) => track.id == currentTrack.id);
      if (_currentIndex == -1) _currentIndex = 0;
    }
    
    notifyListeners();
  }

  void clearQueue() {
    _playlist.clear();
    _queue.clear();
    _originalPlaylist.clear();
    _currentIndex = 0;
    _currentTrack = null;
    _isShuffled = false;
    _player.stop();
    notifyListeners();
  }

  Future<void> _playCurrentTrack() async {
    if (_playlist.isEmpty || _currentIndex >= _playlist.length) return;

    final track = _playlist[_currentIndex];
    _currentTrack = track;
    
    // Check if we have a preloaded player for this track
    if (_preloadedPlayers.containsKey(track.id)) {
      final preloadedPlayer = _preloadedPlayers.remove(track.id);
      if (preloadedPlayer != null) {
        // Swap the preloaded player with the main player
        await _player.stop();
        await _player.setUrl(preloadedPlayer.audioSource?.audioSource.uri.toString() ?? '');
        await _player.play();
        
        // Dispose the preloaded player
        preloadedPlayer.dispose();
        
        if (kDebugMode) {
          print('Playing preloaded track: ${track.name}');
        }
        
        // Preload next tracks after successful play
        _preloadNextTracks();
        notifyListeners();
        return;
      }
    }
    
    // Fallback to normal loading if no preloaded version
    await _loadAndPlayTrack(track);
    
    // Preload next tracks after successful play
    _preloadNextTracks();
    notifyListeners();
  }

  Future<void> _loadAndPlayTrack(Track track) async {
    // Try multiple stream URLs in order of preference
    final streamUrls = [
      _jellyfinService.getStreamUrl(track.id),
      _jellyfinService.getDirectStreamUrl(track.id),
      _jellyfinService.getUniversalStreamUrl(track.id),
    ];
    
    for (int i = 0; i < streamUrls.length; i++) {
      final streamUrl = streamUrls[i];
      final streamType = ['stream', 'direct', 'universal'][i];
      
      try {
        if (kDebugMode) {
          print('Attempting to play track: ${track.name} using $streamType URL');
          print('Stream URL: $streamUrl');
        }
        
        await _player.setUrl(streamUrl);
        await _player.play();
        
        if (kDebugMode) {
          print('Successfully started playing: ${track.name} using $streamType URL');
        }
        break; // Success! Exit the loop
        
      } catch (e) {
        if (kDebugMode) {
          print('Failed to play with $streamType URL: $e');
          
          // Try to provide more specific error information
          if (e.toString().contains('Cleartext')) {
            print('SOLUTION: This is a cleartext HTTP issue. Make sure network security config allows HTTP traffic.');
          } else if (e.toString().contains('extractors')) {
            print('SOLUTION: Audio format not supported. Check Jellyfin transcoding settings.');
          } else if (e.toString().contains('Connection')) {
            print('SOLUTION: Network connection issue. Check server URL and connectivity.');
          }
        }
        
        // If this was the last URL to try, we've failed completely
        if (i == streamUrls.length - 1) {
          if (kDebugMode) {
            print('All stream URLs failed for track: ${track.name}');
          }
        }
      }
    }
  }

  void _preloadNextTracks() async {
    if (!_smartCrossfadeEnabled) return;
    
    // Clean up old preloaded players first
    _cleanupOldPreloadedPlayers();
    
    // Preload next few tracks in the queue
    for (int i = 1; i <= _maxPreloadedTracks; i++) {
      final nextIndex = _currentIndex + i;
      if (nextIndex < _playlist.length) {
        final track = _playlist[nextIndex];
        _preloadTrack(track);
      }
    }
  }

  void _preloadTrack(Track track) async {
    // Don't preload if already preloaded or currently preloading
    if (_preloadedPlayers.containsKey(track.id) || _preloadingTracks.contains(track.id)) {
      return;
    }
    
    _preloadingTracks.add(track.id);
    
    try {
      final player = AudioPlayer();
      
      // Try multiple stream URLs in order of preference
      final streamUrls = [
        _jellyfinService.getStreamUrl(track.id),
        _jellyfinService.getDirectStreamUrl(track.id),
        _jellyfinService.getUniversalStreamUrl(track.id),
      ];
      
      bool loaded = false;
      for (final streamUrl in streamUrls) {
        try {
          await player.setUrl(streamUrl);
          // Preload by seeking to the beginning but don't play
          await player.seek(Duration.zero);
          
          _preloadedPlayers[track.id] = player;
          loaded = true;
          
          if (kDebugMode) {
            print('Successfully preloaded track: ${track.name}');
          }
          break;
        } catch (e) {
          if (kDebugMode) {
            print('Failed to preload track ${track.name}: $e');
          }
        }
      }
      
      if (!loaded) {
        player.dispose();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error preloading track ${track.name}: $e');
      }
    } finally {
      _preloadingTracks.remove(track.id);
    }
  }

  void _cleanupOldPreloadedPlayers() {
    final currentTrackId = _currentTrack?.id;
    final upcomingTrackIds = <String>{};
    
    // Collect IDs of upcoming tracks
    for (int i = 1; i <= _maxPreloadedTracks; i++) {
      final nextIndex = _currentIndex + i;
      if (nextIndex < _playlist.length) {
        upcomingTrackIds.add(_playlist[nextIndex].id);
      }
    }
    
    // Remove preloaded players that are no longer needed
    final keysToRemove = <String>[];
    for (final trackId in _preloadedPlayers.keys) {
      if (trackId != currentTrackId && !upcomingTrackIds.contains(trackId)) {
        keysToRemove.add(trackId);
      }
    }
    
    for (final trackId in keysToRemove) {
      final player = _preloadedPlayers.remove(trackId);
      player?.dispose();
      if (kDebugMode) {
        print('Cleaned up preloaded player for track: $trackId');
      }
    }
  }

  // Getters
  Track? get currentTrack => _currentTrack;
  List<Track> get playlist => _playlist;
  List<Track> get queue => _queue;
  List<Track> get upNext => _currentIndex < _queue.length - 1 
      ? _queue.sublist(_currentIndex + 1) 
      : [];
  int get currentIndex => _currentIndex;
  bool get isPlaying => _player.playing;
  bool get hasNext => _currentIndex < _playlist.length - 1;
  bool get hasPrevious => _currentIndex > 0;
  bool get isShuffled => _isShuffled;
  int get queueLength => _queue.length;
  
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  PlayerState get playerState => _player.playerState;

  void setSmartCrossfade(bool enabled) {
    _smartCrossfadeEnabled = enabled;
    
    if (enabled) {
      // Enable crossfade with 3-second duration
      _player.setVolume(1.0);
      // Note: just_audio doesn't have built-in crossfade, but we can implement
      // a basic version by controlling volume during track transitions
      if (kDebugMode) {
        print('Smart crossfade enabled with ${_crossfadeDuration.inSeconds}s duration');
      }
    } else {
      // Disable crossfade
      if (kDebugMode) {
        print('Smart crossfade disabled');
      }
    }
  }

  bool get smartCrossfadeEnabled => _smartCrossfadeEnabled;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
