/// Audio Service Integration - Bridge between new AudioManager and existing app
/// 
/// This file provides integration helpers to use the new global AudioManager
/// with the existing app architecture.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../../../models/jellyfin_models.dart';
import '../../media_service_manager.dart';
import 'global_audio.dart';

/// Abstract base interface for all audio handlers
/// Ensures consistent API across mobile, desktop, and web platforms
abstract class BaseAudioHandler {
  // Core playback streams
  Stream<AudioPlayerState> get stateStream;
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<double> get volumeStream;
  Stream<PlaybackState> get playbackState;
  Stream<MediaItem?> get mediaItem;
  Stream<List<MediaItem>> get queueStream;
  Stream<PlayerState> get playerStateStream;
  
  // Current state getters
  AudioPlayerState get currentState;
  Duration get position;
  Duration get duration;
  Track? get currentTrack;
  List<Track> get queueTracks;
  List<Track> get upNext;
  double get volume;
  double get speed;
  bool get userIntendedPlaying;
  PlayerState get playerState;
  
  // Queue management
  int? get currentIndex;
  bool get hasNext;
  bool get hasPrevious;
  
  // Playback modes
  RepeatMode get repeatMode;
  bool get shuffleEnabled;
  bool get gaplessPlaybackEnabled;
  bool get radioModeEnabled;
  
  // Core playback control
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> setVolume(double volume);
  
  // Track and playlist control
  Future<void> playTrack(Track track);
  Future<void> playPlaylist(List<Track> tracks, int startIndex);
  Future<void> skipToNext();
  Future<void> skipToPrevious();
  Future<void> skipToQueueItem(int index);
  
  // Queue management
  void addToQueue(Track track);
  void addNext(Track track);
  void removeFromQueue(int index);
  void reorderQueue(int oldIndex, int newIndex);
  void clearQueue();
  
  // Playback modes
  void setRepeatMode(RepeatMode mode);
  void toggleShuffle();
  void setGaplessPlayback(bool enabled);
  void toggleRadioMode();
  void enableRadioMode();
  void disableRadioMode();
  
  // Lifecycle management
  Future<void> dispose();
}

/// Integration class that wraps the new AudioManager and exposes
/// the old BaseAudioHandler interface for compatibility with existing code.
/// 
/// This allows gradual migration to the new audio system.
class AudioManagerIntegration implements BaseAudioHandler {
  final MediaServiceManager _mediaServiceManager;
  
  // Stream controllers for compatibility
  final _playbackStateController = StreamController<PlaybackState>.broadcast();
  final _mediaItemController = StreamController<MediaItem?>.broadcast();
  final _queueStreamController = StreamController<List<MediaItem>>.broadcast();
  final _playerStateController = StreamController<PlayerState>.broadcast();
  
  // Subscriptions
  final List<StreamSubscription> _subscriptions = [];
  
  bool _isInitialized = false;

  AudioManagerIntegration({
    required MediaServiceManager mediaServiceManager,
  }) : _mediaServiceManager = mediaServiceManager;

  /// Initialize the audio system
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      if (kDebugMode) {
        print('AudioManagerIntegration: Initializing...');
      }
      
      // Initialize the AudioManager
      final result = await AudioManager.initialize(
        adapterFactory: JustAudioAdapterFactory(
          config: PlatformAdapterConfig.defaultConfig,
        ),
        mediaServiceManager: _mediaServiceManager,
      );
      
      if (!result.isSuccess) {
        if (kDebugMode) {
          print('AudioManagerIntegration: Failed to initialize: ${result.error?.message}');
        }
        return false;
      }
      
      // Set up stream forwarding
      _setupStreamForwarding();
      
      _isInitialized = true;
      
      if (kDebugMode) {
        print('AudioManagerIntegration: Initialized successfully');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('AudioManagerIntegration: Initialization error: $e');
      }
      return false;
    }
  }

  void _setupStreamForwarding() {
    // Forward state changes to playback state
    _subscriptions.add(
      AudioManager.instance.stateStream.listen((state) {
        _forwardPlaybackState(state);
        _forwardMediaItem(state);
        _forwardQueue(state);
        _forwardPlayerState(state);
      }),
    );
  }

  void _forwardPlaybackState(AudioState state) {
    AudioProcessingState processingState;
    
    switch (state.phase) {
      case AudioPhase.idle:
        processingState = AudioProcessingState.idle;
        break;
      case AudioPhase.loading:
        processingState = AudioProcessingState.loading;
        break;
      case AudioPhase.ready:
        processingState = AudioProcessingState.ready;
        break;
      case AudioPhase.playing:
      case AudioPhase.paused:
        processingState = AudioProcessingState.ready;
        break;
      case AudioPhase.completed:
        processingState = AudioProcessingState.completed;
        break;
      case AudioPhase.stopped:
        processingState = AudioProcessingState.idle;
        break;
      case AudioPhase.error:
        processingState = AudioProcessingState.error;
        break;
    }
    
    final playbackState = PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        state.phase == AudioPhase.playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      processingState: processingState,
      playing: state.phase == AudioPhase.playing,
      updatePosition: state.position,
      bufferedPosition: state.bufferedPosition,
      speed: state.speed,
      queueIndex: state.currentIndex,
    );
    
    _playbackStateController.add(playbackState);
  }

  void _forwardMediaItem(AudioState state) {
    if (state.currentTrack == null) {
      _mediaItemController.add(null);
      return;
    }
    
    final track = state.currentTrack!;
    final mediaItem = MediaItem(
      id: track.id,
      title: track.name,
      artist: track.artistName ?? 'Unknown Artist',
      album: track.albumName ?? 'Unknown Album',
      duration: state.duration,
      artUri: track.imageUrl != null ? Uri.parse(track.imageUrl!) : null,
    );
    
    _mediaItemController.add(mediaItem);
  }

  void _forwardQueue(AudioState state) {
    final mediaItems = state.queue.map((track) => MediaItem(
      id: track.id,
      title: track.name,
      artist: track.artistName ?? 'Unknown Artist',
      album: track.albumName ?? 'Unknown Album',
      artUri: track.imageUrl != null ? Uri.parse(track.imageUrl!) : null,
    )).toList();
    
    _queueStreamController.add(mediaItems);
  }

  void _forwardPlayerState(AudioState state) {
    ProcessingState processingState;
    
    switch (state.phase) {
      case AudioPhase.idle:
      case AudioPhase.stopped:
        processingState = ProcessingState.idle;
        break;
      case AudioPhase.loading:
        processingState = ProcessingState.loading;
        break;
      case AudioPhase.ready:
      case AudioPhase.playing:
      case AudioPhase.paused:
        processingState = ProcessingState.ready;
        break;
      case AudioPhase.completed:
        processingState = ProcessingState.completed;
        break;
      case AudioPhase.error:
        processingState = ProcessingState.idle;
        break;
    }
    
    final playerState = PlayerState(
      state.phase == AudioPhase.playing,
      processingState,
    );
    
    _playerStateController.add(playerState);
  }

  // ============================================================
  // BaseAudioHandler Implementation
  // ============================================================

  @override
  Stream<AudioPlayerState> get stateStream => 
      AudioManager.instance.stateStream.map((s) => _mapPhaseToState(s.phase));

  @override
  Stream<Duration> get positionStream => 
      AudioManager.instance.positionStream;

  @override
  Stream<Duration?> get durationStream => 
      AudioManager.instance.stateStream.map((s) => s.duration);

  @override
  Stream<double> get volumeStream => 
      AudioManager.instance.stateStream.map((s) => s.volume);

  @override
  Stream<PlaybackState> get playbackState => 
      _playbackStateController.stream;

  @override
  Stream<MediaItem?> get mediaItem => 
      _mediaItemController.stream;

  @override
  Stream<List<MediaItem>> get queueStream => 
      _queueStreamController.stream;

  @override
  Stream<PlayerState> get playerStateStream => 
      _playerStateController.stream;

  @override
  AudioPlayerState get currentState => 
      _mapPhaseToState(AudioManager.instance.currentPhase);

  @override
  Duration get position => AudioManager.instance.position;

  @override
  Duration get duration => AudioManager.instance.duration;

  @override
  Track? get currentTrack => AudioManager.instance.currentTrack;

  @override
  List<Track> get queueTracks => AudioManager.instance.queue;

  @override
  List<Track> get upNext => AudioManager.instance.upNext;

  @override
  double get volume => AudioManager.instance.volume;

  @override
  double get speed => AudioManager.instance.currentState.speed;

  @override
  bool get userIntendedPlaying => AudioManager.instance.currentState.userIntendedPlaying;

  @override
  PlayerState get playerState {
    final state = AudioManager.instance.currentState;
    ProcessingState processingState;
    
    switch (state.phase) {
      case AudioPhase.idle:
      case AudioPhase.stopped:
        processingState = ProcessingState.idle;
        break;
      case AudioPhase.loading:
        processingState = ProcessingState.loading;
        break;
      case AudioPhase.ready:
      case AudioPhase.playing:
      case AudioPhase.paused:
        processingState = ProcessingState.ready;
        break;
      case AudioPhase.completed:
        processingState = ProcessingState.completed;
        break;
      case AudioPhase.error:
        processingState = ProcessingState.idle;
        break;
    }
    
    return PlayerState(
      state.phase == AudioPhase.playing,
      processingState,
    );
  }

  @override
  int? get currentIndex => AudioManager.instance.currentIndex;

  @override
  bool get hasNext => AudioManager.instance.hasNext;

  @override
  bool get hasPrevious => AudioManager.instance.hasPrevious;

  @override
  RepeatMode get repeatMode => _mapRepeatMode(AudioManager.instance.currentState.repeatMode);

  @override
  bool get shuffleEnabled => AudioManager.instance.currentState.shuffleMode != AudioShuffleMode.none;

  @override
  bool get gaplessPlaybackEnabled => AudioManager.instance.currentState.gaplessPlayback;

  @override
  bool get radioModeEnabled => AudioManager.instance.currentState.radioMode;

  @override
  Future<void> play() async {
    await AudioManager.instance.play();
  }

  @override
  Future<void> pause() async {
    await AudioManager.instance.pause();
  }

  @override
  Future<void> stop() async {
    await AudioManager.instance.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await AudioManager.instance.seek(position);
  }

  @override
  Future<void> setSpeed(double speed) async {
    await AudioManager.instance.setSpeed(speed);
  }

  @override
  Future<void> setVolume(double volume) async {
    await AudioManager.instance.setVolume(volume);
  }

  @override
  Future<void> playTrack(Track track) async {
    await AudioManager.instance.playTrack(track);
  }

  @override
  Future<void> playPlaylist(List<Track> tracks, int startIndex) async {
    await AudioManager.instance.playPlaylist(tracks, startIndex: startIndex);
  }

  @override
  Future<void> skipToNext() async {
    await AudioManager.instance.skipToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    await AudioManager.instance.skipToPrevious();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    await AudioManager.instance.skipToIndex(index);
  }

  @override
  void addToQueue(Track track) {
    AudioManager.instance.addToQueue(track);
  }

  @override
  void addNext(Track track) {
    AudioManager.instance.addNext(track);
  }

  @override
  void removeFromQueue(int index) {
    AudioManager.instance.removeFromQueue(index);
  }

  @override
  void reorderQueue(int oldIndex, int newIndex) {
    AudioManager.instance.reorderQueue(oldIndex, newIndex);
  }

  @override
  void clearQueue() {
    AudioManager.instance.clearQueue();
  }

  @override
  void setRepeatMode(RepeatMode mode) {
    final newMode = switch (mode) {
      RepeatMode.none => AudioRepeatMode.none,
      RepeatMode.one => AudioRepeatMode.one,
      RepeatMode.all => AudioRepeatMode.all,
    };
    AudioManager.instance.setRepeatMode(newMode);
  }

  @override
  void toggleShuffle() {
    AudioManager.instance.toggleShuffle();
  }

  @override
  void setGaplessPlayback(bool enabled) {
    AudioManager.instance.setGaplessPlayback(enabled);
  }

  @override
  void toggleRadioMode() {
    final current = AudioManager.instance.currentState.radioMode;
    AudioManager.instance.setRadioMode(!current);
  }

  @override
  void enableRadioMode() {
    AudioManager.instance.setRadioMode(true);
  }

  @override
  void disableRadioMode() {
    AudioManager.instance.setRadioMode(false);
  }

  @override
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    
    await _playbackStateController.close();
    await _mediaItemController.close();
    await _queueStreamController.close();
    await _playerStateController.close();
    
    await AudioManager.instance.dispose();
  }

  // Helper methods
  AudioPlayerState _mapPhaseToState(AudioPhase phase) {
    return switch (phase) {
      AudioPhase.idle => AudioPlayerState.idle,
      AudioPhase.loading => AudioPlayerState.loading,
      AudioPhase.ready => AudioPlayerState.idle,
      AudioPhase.playing => AudioPlayerState.playing,
      AudioPhase.paused => AudioPlayerState.paused,
      AudioPhase.completed => AudioPlayerState.completed,
      AudioPhase.stopped => AudioPlayerState.idle,
      AudioPhase.error => AudioPlayerState.error,
    };
  }

  RepeatMode _mapRepeatMode(AudioRepeatMode mode) {
    return switch (mode) {
      AudioRepeatMode.none => RepeatMode.none,
      AudioRepeatMode.one => RepeatMode.one,
      AudioRepeatMode.all => RepeatMode.all,
    };
  }
}
