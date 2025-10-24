import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../models/jellyfin_models.dart';
import 'media_service_manager.dart';

/// Web-compatible audio handler using just_audio
class WebAudioHandler {
  AudioPlayer? _audioPlayer;
  final List<Track> _queue = [];
  int _currentIndex = 0;
  bool _isShuffled = false;
  bool _radioModeEnabled = false;
  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;
  
  // Services
  final MediaServiceManager _mediaServiceManager;
  
  // Streams for state management
  final StreamController<Duration> _positionController = StreamController<Duration>.broadcast();
  final StreamController<PlayerState> _playbackStateController = StreamController<PlayerState>.broadcast();
  final StreamController<PlaybackState> _audioServiceStateController = StreamController<PlaybackState>.broadcast();
  final StreamController<MediaItem?> _mediaItemController = StreamController<MediaItem?>.broadcast();
  
  // Duration and position tracking
  Duration _duration = Duration.zero;
  
  // User intended playing state for race condition handling
  bool _userIntendedPlaying = false;
  
  Stream<Duration> get positionStream => _audioPlayer?.positionStream ?? Stream.value(Duration.zero);
  Stream<Duration?> get durationStream => _audioPlayer?.durationStream ?? Stream.value(null);
  Stream<double> get volumeStream => _audioPlayer?.volumeStream ?? Stream.value(1.0);
  Stream<PlaybackState> get playbackState => _audioServiceStateController.stream;
  Stream<PlayerState> get playerStateStream => _playbackStateController.stream;
  Stream<MediaItem?> get mediaItem => _mediaItemController.stream;
  
  Duration get duration => _audioPlayer?.duration ?? Duration.zero;
  Track? get currentTrack => _queue.isNotEmpty ? _queue[_currentIndex] : null;
  List<Track> get queueTracks => List.unmodifiable(_queue);
  List<Track> get upNext => _currentIndex < _queue.length - 1 
      ? List.unmodifiable(_queue.sublist(_currentIndex + 1)) 
      : [];
  
  bool get isShuffled => _isShuffled;
  bool get radioModeEnabled => _radioModeEnabled;
  bool get userIntendedPlaying => _userIntendedPlaying;
  bool get hasPrevious => _currentIndex > 0;
  bool get hasNext => _currentIndex < _queue.length - 1;
  
  PlayerState get playerState => _audioPlayer?.playerState ?? PlayerState(false, ProcessingState.idle);
  
  WebAudioHandler(
    this._mediaServiceManager,
  ) {
    _initializeAudioPlayer();
  }
  
  void _initializeAudioPlayer() {
    _audioPlayer = AudioPlayer();
    
    // Listen to player state changes
    _audioPlayer!.playerStateStream.listen((playerState) {
      _updatePlaybackState();
    });
    
    // Listen to duration changes
    _audioPlayer!.durationStream.listen((duration) {
      if (duration != null) {
        _duration = duration;
        _updateMediaItem();
      }
    });
    
    // Listen to position changes
    _audioPlayer!.positionStream.listen((position) {
      _positionController.add(position);
    });
    
    // Handle track completion
    _audioPlayer!.playerStateStream.where((state) => state.processingState == ProcessingState.completed).listen((_) {
      _handleTrackEnded();
    });
  }
  
  void _updatePlaybackState() {
    if (_audioPlayer != null) {
      final playerState = _audioPlayer!.playerState;
      _playbackStateController.add(playerState);
      
      // Convert PlayerState to PlaybackState for audio service compatibility
      final playbackState = PlaybackState(
        playing: playerState.playing,
        processingState: _convertProcessingState(playerState.processingState),
        repeatMode: _repeatMode,
        shuffleMode: _isShuffled ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
      );
      _audioServiceStateController.add(playbackState);
    }
  }
  
  AudioProcessingState _convertProcessingState(ProcessingState processingState) {
    switch (processingState) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }
  
  Future<void> _loadAudioForWeb(String streamUrl) async {
    if (kDebugMode) {
      print('WebAudioHandler: Attempting web-specific audio loading');
    }
    
    try {
      // Method 1: Try with AudioSource.uri directly (simplest approach)
      if (kDebugMode) {
        print('WebAudioHandler: Trying direct AudioSource.uri: $streamUrl');
      }
      
      await _audioPlayer!.setAudioSource(AudioSource.uri(Uri.parse(streamUrl)));
      
      if (kDebugMode) {
        print('WebAudioHandler: Direct AudioSource.uri method successful');
      }
    } catch (e) {
      if (kDebugMode) {
        print('WebAudioHandler: Direct AudioSource.uri failed: $e');
        print('WebAudioHandler: Trying with basic CORS headers...');
      }
      
      // Method 2: Try with minimal, safe CORS headers only
      try {
        final uri = Uri.parse(streamUrl);
        await _audioPlayer!.setAudioSource(
          AudioSource.uri(
            uri,
            headers: {
              // Only include browser-safe headers
              'Accept': 'audio/*,*/*',
              'Range': 'bytes=0-', // Support for range requests
            },
          ),
        );
        
        if (kDebugMode) {
          print('WebAudioHandler: Basic CORS headers method successful');
        }
      } catch (e2) {
        if (kDebugMode) {
          print('WebAudioHandler: Basic CORS headers method also failed: $e2');
          print('WebAudioHandler: All web loading methods failed');
        }
        rethrow;
      }
    }
  }

  void _updateMediaItem() {
    final track = currentTrack;
    if (kDebugMode) {
      print('WebAudioHandler: _updateMediaItem called');
      print('WebAudioHandler: Current track: ${track?.name ?? "null"}');
      print('WebAudioHandler: Duration: $_duration');
    }
    
    if (track != null) {
      final mediaItem = MediaItem(
        id: track.id,
        title: track.name,
        artist: track.artistName,
        album: track.albumName,
        duration: _duration,
        artUri: track.imageUrl != null ? Uri.parse(track.imageUrl!) : null,
      );
      
      if (kDebugMode) {
        print('WebAudioHandler: Created MediaItem: ${mediaItem.title} by ${mediaItem.artist}');
      }
      
      _mediaItemController.add(mediaItem);
      
      if (kDebugMode) {
        print('WebAudioHandler: MediaItem added to stream');
      }
    } else {
      if (kDebugMode) {
        print('WebAudioHandler: Adding null MediaItem to stream');
      }
      _mediaItemController.add(null);
    }
  }
  
  Future<void> playTrack(Track track) async {
    try {
      if (kDebugMode) {
        print('WebAudioHandler: Playing track ${track.name}');
      }
      
      _queue.clear();
      _queue.add(track);
      _currentIndex = 0;
      
      await _loadAndPlayCurrentTrack();
    } catch (e) {
      if (kDebugMode) {
        print('WebAudioHandler: Error playing track: $e');
      }
    }
  }
  
  Future<void> playPlaylist(List<Track> tracks, int startIndex) async {
    try {
      if (kDebugMode) {
        print('WebAudioHandler: Playing playlist with ${tracks.length} tracks, starting at $startIndex');
      }
      
      _queue.clear();
      _queue.addAll(tracks);
      _currentIndex = startIndex.clamp(0, tracks.length - 1);
      
      await _loadAndPlayCurrentTrack();
    } catch (e) {
      if (kDebugMode) {
        print('WebAudioHandler: Error playing playlist: $e');
      }
    }
  }
  
  Future<void> _loadAndPlayCurrentTrack() async {
    final track = currentTrack;
    if (kDebugMode) {
      print('WebAudioHandler: _loadAndPlayCurrentTrack called');
      print('WebAudioHandler: Queue length: ${_queue.length}');
      print('WebAudioHandler: Current index: $_currentIndex');
      print('WebAudioHandler: Current track: ${track?.name ?? "null"}');
    }
    
    if (track == null || _audioPlayer == null) {
      if (kDebugMode) {
        print('WebAudioHandler: Cannot load - track: ${track != null}, audioPlayer: ${_audioPlayer != null}');
      }
      return;
    }

    // Set the MediaItem first, before trying to load audio
    // This ensures the UI updates even if audio loading fails
    if (kDebugMode) {
      print('WebAudioHandler: Setting MediaItem before audio loading');
    }
    _updateMediaItem();

    try {
      // Get the stream URL from the media service
      final streamUrl = _mediaServiceManager.getStreamUrl(track.id);
      
      if (kDebugMode) {
        print('WebAudioHandler: Loading audio from: $streamUrl');
      }
      
      // Try multiple approaches for web CORS handling
      if (kIsWeb) {
        // For web, try to create an audio source with multiple fallbacks
        await _loadAudioForWeb(streamUrl, track);
      } else {
        // Load the audio source directly for other platforms
        await _audioPlayer!.setAudioSource(AudioSource.uri(Uri.parse(streamUrl)));
      }
      
      if (kDebugMode) {
        print('WebAudioHandler: Audio source set successfully');
      }      // For web, don't auto-play immediately due to browser policies
      if (kIsWeb) {
        if (kDebugMode) {
          print('WebAudioHandler: Audio loaded, ready to play (web)');
        }
        // We'll start playback when user explicitly calls play()
      } else {
        // Auto-play for other platforms
        await _audioPlayer!.play();
        _userIntendedPlaying = true;
      }
      
      if (kDebugMode) {
        print('WebAudioHandler: Successfully started playback');
      }
    } catch (e) {
      if (kDebugMode) {
        print('WebAudioHandler: Error loading track: $e');
        print('WebAudioHandler: Trying fallback method...');
      }
      
      // Fallback: try without web-specific handling
      try {
        await _audioPlayer!.setAudioSource(AudioSource.uri(Uri.parse(_mediaServiceManager.getStreamUrl(track.id))));
        await _audioPlayer!.play();
        _userIntendedPlaying = true;
        
        if (kDebugMode) {
          print('WebAudioHandler: Fallback successful');
        }
      } catch (fallbackError) {
        if (kDebugMode) {
          print('WebAudioHandler: Fallback also failed: $fallbackError');
          print('WebAudioHandler: Keeping MediaItem set even though audio failed to load');
        }
        // Don't clear the MediaItem even if audio loading fails
        // The UI should still show the track information
      }
    }
  }
  
  Future<void> play() async {
    if (_audioPlayer != null) {
      try {
        await _audioPlayer!.play();
        _userIntendedPlaying = true;
        if (kDebugMode) {
          print('WebAudioHandler: Play called');
        }
      } catch (e) {
        if (kDebugMode) {
          print('WebAudioHandler: Play failed: $e');
        }
      }
    }
  }
  
  Future<void> pause() async {
    if (_audioPlayer != null) {
      await _audioPlayer!.pause();
      _userIntendedPlaying = false;
      if (kDebugMode) {
        print('WebAudioHandler: Pause called');
      }
    }
  }
  
  Future<void> seek(Duration position) async {
    if (_audioPlayer != null) {
      await _audioPlayer!.seek(position);
    }
  }
  
  Future<void> skipToNext() async {
    if (hasNext) {
      _currentIndex++;
      await _loadAndPlayCurrentTrack();
    }
  }
  
  Future<void> skipToPrevious() async {
    if (hasPrevious) {
      _currentIndex--;
      await _loadAndPlayCurrentTrack();
    }
  }
  
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < _queue.length) {
      _currentIndex = index;
      await _loadAndPlayCurrentTrack();
    }
  }
  
  void _handleTrackEnded() {
    if (_repeatMode == AudioServiceRepeatMode.one) {
      // Repeat current track
      _audioPlayer?.seek(Duration.zero);
      _audioPlayer?.play();
    } else if (hasNext) {
      // Play next track
      skipToNext();
    } else if (_repeatMode == AudioServiceRepeatMode.all) {
      // Restart playlist
      _currentIndex = 0;
      _loadAndPlayCurrentTrack();
    } else {
      // End of playlist
      _userIntendedPlaying = false;
      _updatePlaybackState();
    }
  }
  
  void addToQueue(Track track) {
    _queue.add(track);
  }
  
  void addNext(Track track) {
    if (_currentIndex + 1 < _queue.length) {
      _queue.insert(_currentIndex + 1, track);
    } else {
      _queue.add(track);
    }
  }
  
  void shuffle() {
    if (_queue.length > 1) {
      final currentTrack = this.currentTrack;
      final remainingTracks = List<Track>.from(_queue);
      remainingTracks.removeAt(_currentIndex);
      remainingTracks.shuffle();
      
      _queue.clear();
      if (currentTrack != null) {
        _queue.add(currentTrack);
        _queue.addAll(remainingTracks);
        _currentIndex = 0;
      }
      
      _isShuffled = true;
      _updatePlaybackState();
    }
  }
  
  void unshuffle() {
    _isShuffled = false;
    _updatePlaybackState();
  }
  
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _repeatMode = repeatMode;
    _updatePlaybackState();
  }
  
  void toggleRadioMode() {
    _radioModeEnabled = !_radioModeEnabled;
  }
  
  void enableRadioMode() {
    _radioModeEnabled = true;
  }
  
  void disableRadioMode() {
    _radioModeEnabled = false;
  }
  
  Future<void> setVolume(double volume) async {
    if (_audioPlayer != null) {
      await _audioPlayer!.setVolume(volume.clamp(0.0, 1.0));
    }
  }
  
  Future<void> toggleMute() async {
    if (_audioPlayer != null) {
      final currentVolume = _audioPlayer!.volume;
      if (currentVolume > 0) {
        await _audioPlayer!.setVolume(0.0);
      } else {
        await _audioPlayer!.setVolume(1.0);
      }
    }
  }
  
  void setNormalizeVolume(bool enabled) {
    // Volume normalization not implemented for web
    if (kDebugMode) {
      print('WebAudioHandler: Volume normalization not supported on web');
    }
  }
  
  void setGaplessPlayback(bool enabled) {
    // Gapless playback not implemented for web
    if (kDebugMode) {
      print('WebAudioHandler: Gapless playback not supported on web');
    }
  }
  
  void updateMediaLibrary({
    List<Album>? albums,
    List<Artist>? artists,
    List<Track>? tracks,
    List<Playlist>? playlists,
  }) {
    // Not needed for web implementation
    if (kDebugMode) {
      print('WebAudioHandler: Media library update not needed on web');
    }
  }
  
  Future<void> dispose() async {
    await _audioPlayer?.dispose();
    _audioPlayer = null;
    
    await _positionController.close();
    await _playbackStateController.close();
    await _audioServiceStateController.close();
    await _mediaItemController.close();
  }
}