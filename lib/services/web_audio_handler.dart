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
  final StreamController<MediaItem?> _mediaItemController = StreamController<MediaItem?>.broadcast();
  
  // Duration and position tracking
  Duration _duration = Duration.zero;
  
  // User intended playing state for race condition handling
  bool _userIntendedPlaying = false;
  
  Stream<Duration> get positionStream => _audioPlayer?.positionStream ?? Stream.value(Duration.zero);
  Stream<PlayerState> get playbackState => _playbackStateController.stream;
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
  
  Stream<PlayerState> get playerStateStream => _playbackStateController.stream;
  
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
      _playbackStateController.add(_audioPlayer!.playerState);
    }
  }
  
  void _updateMediaItem() {
    final track = currentTrack;
    if (track != null) {
      final mediaItem = MediaItem(
        id: track.id,
        title: track.name,
        artist: track.artistName,
        album: track.albumName,
        duration: _duration,
        artUri: track.imageUrl != null ? Uri.parse(track.imageUrl!) : null,
      );
      _mediaItemController.add(mediaItem);
    } else {
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
    if (track == null || _audioPlayer == null) return;
    
    try {
      // Get the stream URL from the media service
      final streamUrl = _mediaServiceManager.getStreamUrl(track.id);
      
      if (kDebugMode) {
        print('WebAudioHandler: Loading audio from: $streamUrl');
      }
      
      // Load the audio source
      await _audioPlayer!.setAudioSource(AudioSource.uri(Uri.parse(streamUrl)));
      
      _updateMediaItem();
      
      // Auto-play
      await _audioPlayer!.play();
      _userIntendedPlaying = true;
      
      if (kDebugMode) {
        print('WebAudioHandler: Successfully started playback');
      }
    } catch (e) {
      if (kDebugMode) {
        print('WebAudioHandler: Error loading track: $e');
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
    await _mediaItemController.close();
  }
}