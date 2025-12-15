/// Global Audio Manager - Singleton that manages ALL audio playback
/// 
/// This is the single source of truth for audio state across the entire app.
/// It provides a thread-safe, platform-agnostic API for audio playback.
/// 
/// ## Usage
/// 
/// ```dart
/// // Initialize at app startup
/// await AudioManager.instance.initialize();
/// 
/// // Play a track
/// await AudioManager.instance.playTrack(track);
/// 
/// // Control playback
/// await AudioManager.instance.pause();
/// await AudioManager.instance.resume();
/// await AudioManager.instance.seek(Duration(seconds: 30));
/// 
/// // Listen to state changes
/// AudioManager.instance.stateStream.listen((state) {
///   print('Now playing: ${state.currentTrack?.name}');
/// });
/// 
/// // Dispose when app closes
/// await AudioManager.instance.dispose();
/// ```
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import '../../../models/jellyfin_models.dart';
import '../../media_service_manager.dart';
import 'audio_state.dart';
import 'platform_audio_adapter.dart';
import 'audio_operation_queue.dart';

/// Global singleton AudioManager that controls all audio playback.
/// 
/// This manager:
/// - Provides a single source of truth for audio state
/// - Ensures thread-safe operations with operation queuing
/// - Handles errors gracefully with automatic recovery
/// - Works identically on all platforms
/// - Prevents race conditions through synchronized operations
class AudioManager {
  // Singleton instance
  static AudioManager? _instance;
  
  /// Get the singleton instance.
  /// 
  /// Throws if [initialize] hasn't been called yet.
  static AudioManager get instance {
    if (_instance == null) {
      throw StateError(
        'AudioManager not initialized. Call AudioManager.initialize() first.',
      );
    }
    return _instance!;
  }
  
  /// Check if the AudioManager has been initialized
  static bool get isInitialized => _instance != null;
  
  // Private constructor
  AudioManager._internal();
  
  // Dependencies
  late final PlatformAudioAdapter _adapter;
  late final MediaServiceManager _mediaServiceManager;
  
  // State management
  final BehaviorSubject<AudioState> _stateSubject = 
      BehaviorSubject<AudioState>.seeded(AudioState.initial());
  
  // Error stream
  final PublishSubject<AudioError> _errorSubject = PublishSubject<AudioError>();
  
  // Operation queue for thread safety
  late final AudioOperationQueue _operationQueue;
  
  // Subscriptions for cleanup
  final List<StreamSubscription> _subscriptions = [];
  
  // Initialization state
  bool _isDisposed = false;
  Completer<void>? _initCompleter;
  
  // Position update throttling
  Timer? _positionUpdateTimer;
  static const Duration _positionUpdateInterval = Duration(milliseconds: 200);
  
  // Operation timeout
  static const Duration _operationTimeout = Duration(seconds: 10);
  
  // Retry configuration
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(milliseconds: 500);

  // ============================================================
  // INITIALIZATION
  // ============================================================

  /// Initialize the AudioManager singleton.
  /// 
  /// Must be called once at app startup before using any audio functionality.
  /// 
  /// [adapterFactory] creates the platform-specific audio adapter.
  /// [mediaServiceManager] is used to build audio URLs.
  /// 
  /// Returns a result indicating success or failure.
  static Future<AudioResult<void>> initialize({
    required PlatformAudioAdapterFactory adapterFactory,
    required MediaServiceManager mediaServiceManager,
  }) async {
    if (_instance != null) {
      if (kDebugMode) {
        print('AudioManager: Already initialized, skipping');
      }
      return const AudioResult.success(null);
    }
    
    if (kDebugMode) {
      print('AudioManager: Initializing...');
    }
    
    final manager = AudioManager._internal();
    manager._initCompleter = Completer<void>();
    
    try {
      // Store dependencies
      manager._mediaServiceManager = mediaServiceManager;
      
      // Create platform adapter
      manager._adapter = adapterFactory.create();
      
      // Initialize operation queue
      manager._operationQueue = AudioOperationQueue(
        timeout: _operationTimeout,
        onError: manager._handleOperationError,
      );
      
      // Initialize the platform adapter
      final adapterResult = await manager._adapter.initialize();
      if (!adapterResult.isSuccess) {
        return AudioResult.failure(adapterResult.error);
      }
      
      // Set up stream subscriptions
      manager._setupStreamSubscriptions();
      
      // Start position update timer
      manager._startPositionUpdates();
      
      // Mark as initialized
      _instance = manager;
      manager._initCompleter!.complete();
      
      if (kDebugMode) {
        print('AudioManager: Initialized successfully');
      }
      
      return const AudioResult.success(null);
    } catch (e, stackTrace) {
      final error = AudioError.fromException(
        e,
        'initialize',
        stackTrace: stackTrace,
      );
      
      manager._initCompleter?.completeError(error);
      
      if (kDebugMode) {
        print('AudioManager: Initialization failed: $e');
      }
      
      return AudioResult.failure(error);
    }
  }

  /// Set up subscriptions to the platform adapter streams
  void _setupStreamSubscriptions() {
    // Phase changes
    _subscriptions.add(
      _adapter.phaseStream.listen(
        (phase) => _updateState((state) => state.copyWith(phase: phase)),
        onError: (error) => _handleStreamError(error, 'phaseStream'),
      ),
    );
    
    // Duration changes
    _subscriptions.add(
      _adapter.durationStream.listen(
        (duration) => _updateState((state) => state.copyWith(duration: duration)),
        onError: (error) => _handleStreamError(error, 'durationStream'),
      ),
    );
    
    // Buffered position changes
    _subscriptions.add(
      _adapter.bufferedPositionStream.listen(
        (buffered) => _updateState((state) => state.copyWith(bufferedPosition: buffered)),
        onError: (error) => _handleStreamError(error, 'bufferedPositionStream'),
      ),
    );
    
    // Errors from adapter
    _subscriptions.add(
      _adapter.errorStream.listen(
        _handleAdapterError,
        onError: (error) => _handleStreamError(error, 'errorStream'),
      ),
    );
  }

  /// Start periodic position updates
  void _startPositionUpdates() {
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer = Timer.periodic(
      _positionUpdateInterval,
      (_) {
        if (!_isDisposed && _adapter.currentPhase == AudioPhase.playing) {
          final position = _adapter.currentPosition;
          _updateState((state) => state.copyWith(position: position));
        }
      },
    );
  }

  // ============================================================
  // PUBLIC API - STATE ACCESS
  // ============================================================

  /// Stream of audio state changes.
  /// 
  /// Emits whenever any part of the audio state changes.
  /// Use this to reactively update your UI.
  Stream<AudioState> get stateStream => _stateSubject.stream;
  
  /// Current audio state.
  /// 
  /// This is a snapshot of the current state. For reactive updates,
  /// use [stateStream] instead.
  AudioState get currentState => _stateSubject.value;
  
  /// Stream of position updates (throttled).
  /// 
  /// Emits every 200ms during playback.
  Stream<Duration> get positionStream => 
      _stateSubject.stream.map((s) => s.position).distinct();
  
  /// Stream of audio errors.
  /// 
  /// Listen to this to show error messages to the user.
  Stream<AudioError> get errorStream => _errorSubject.stream;
  
  /// Current playback phase
  AudioPhase get currentPhase => currentState.phase;
  
  /// Current track being played (null if none)
  Track? get currentTrack => currentState.currentTrack;
  
  /// Current position in the track
  Duration get position => currentState.position;
  
  /// Total duration of current track
  Duration get duration => currentState.duration;
  
  /// Current volume (0.0 to 1.0)
  double get volume => currentState.volume;
  
  /// Current playback queue
  List<Track> get queue => currentState.queue;
  
  /// Current index in queue
  int? get currentIndex => currentState.currentIndex;
  
  /// Whether there is a next track
  bool get hasNext => currentState.hasNext;
  
  /// Whether there is a previous track
  bool get hasPrevious => currentState.hasPrevious;
  
  /// Tracks coming up after current
  List<Track> get upNext => currentState.upNext;

  // ============================================================
  // PUBLIC API - PLAYBACK CONTROL
  // ============================================================

  /// Play a single track.
  /// 
  /// Stops any current playback and plays the specified track.
  Future<AudioResult<void>> playTrack(Track track) async {
    _assertNotDisposed();
    
    if (kDebugMode) {
      print('AudioManager: playTrack(${track.name})');
    }
    
    return _operationQueue.enqueue(
      AudioOperationType.loadTrack,
      () => _doPlayTrack(track),
    );
  }
  
  /// Play a playlist starting at the specified index.
  /// 
  /// [tracks] is the list of tracks to play.
  /// [startIndex] is the index to start playing from (defaults to 0).
  Future<AudioResult<void>> playPlaylist(
    List<Track> tracks, {
    int startIndex = 0,
  }) async {
    _assertNotDisposed();
    
    if (tracks.isEmpty) {
      return AudioResult.failure(AudioError(
        type: AudioErrorType.state,
        message: 'Cannot play empty playlist',
        operation: 'playPlaylist',
        timestamp: DateTime.now(),
      ));
    }
    
    if (startIndex < 0 || startIndex >= tracks.length) {
      startIndex = 0;
    }
    
    if (kDebugMode) {
      print('AudioManager: playPlaylist(${tracks.length} tracks, start: $startIndex)');
    }
    
    return _operationQueue.enqueue(
      AudioOperationType.loadPlaylist,
      () => _doPlayPlaylist(tracks, startIndex),
    );
  }
  
  /// Resume playback (if paused).
  Future<AudioResult<void>> play() async {
    _assertNotDisposed();
    
    if (kDebugMode) {
      print('AudioManager: play()');
    }
    
    return _operationQueue.enqueue(
      AudioOperationType.play,
      () => _doPlay(),
    );
  }
  
  /// Pause playback.
  Future<AudioResult<void>> pause() async {
    _assertNotDisposed();
    
    if (kDebugMode) {
      print('AudioManager: pause()');
    }
    
    return _operationQueue.enqueue(
      AudioOperationType.pause,
      () => _doPause(),
    );
  }
  
  /// Stop playback and clear the current track.
  Future<AudioResult<void>> stop() async {
    _assertNotDisposed();
    
    if (kDebugMode) {
      print('AudioManager: stop()');
    }
    
    return _operationQueue.enqueue(
      AudioOperationType.stop,
      () => _doStop(),
    );
  }
  
  /// Seek to a specific position.
  Future<AudioResult<void>> seek(Duration position) async {
    _assertNotDisposed();
    
    // Validate position
    final duration = currentState.duration;
    if (position < Duration.zero) position = Duration.zero;
    if (duration > Duration.zero && position > duration) position = duration;
    
    if (kDebugMode) {
      print('AudioManager: seek($position)');
    }
    
    return _operationQueue.enqueue(
      AudioOperationType.seek,
      () => _doSeek(position),
    );
  }
  
  /// Set playback volume.
  /// 
  /// [volume] should be between 0.0 (muted) and 1.0 (full volume).
  Future<AudioResult<void>> setVolume(double volume) async {
    _assertNotDisposed();
    
    volume = volume.clamp(0.0, 1.0);
    
    if (kDebugMode) {
      print('AudioManager: setVolume($volume)');
    }
    
    return _operationQueue.enqueue(
      AudioOperationType.setVolume,
      () => _doSetVolume(volume),
    );
  }
  
  /// Set playback speed.
  /// 
  /// [speed] should be between 0.25 and 4.0.
  Future<AudioResult<void>> setSpeed(double speed) async {
    _assertNotDisposed();
    
    speed = speed.clamp(0.25, 4.0);
    
    if (kDebugMode) {
      print('AudioManager: setSpeed($speed)');
    }
    
    return _operationQueue.enqueue(
      AudioOperationType.setSpeed,
      () => _doSetSpeed(speed),
    );
  }
  
  /// Skip to the next track in the queue.
  Future<AudioResult<void>> skipToNext() async {
    _assertNotDisposed();
    
    if (!currentState.hasNext) {
      // Handle repeat mode
      if (currentState.repeatMode == AudioRepeatMode.all && 
          currentState.queue.isNotEmpty) {
        return skipToIndex(0);
      }
      
      return AudioResult.failure(AudioError(
        type: AudioErrorType.state,
        message: 'No next track available',
        operation: 'skipToNext',
        timestamp: DateTime.now(),
      ));
    }
    
    if (kDebugMode) {
      print('AudioManager: skipToNext()');
    }
    
    return _operationQueue.enqueue(
      AudioOperationType.skipNext,
      () => _doSkipToNext(),
    );
  }
  
  /// Skip to the previous track in the queue.
  /// 
  /// If current position is greater than 3 seconds, seeks to start instead.
  Future<AudioResult<void>> skipToPrevious() async {
    _assertNotDisposed();
    
    // If more than 3 seconds into the track, seek to start instead
    if (currentState.position > const Duration(seconds: 3)) {
      return seek(Duration.zero);
    }
    
    if (!currentState.hasPrevious) {
      // Handle repeat mode
      if (currentState.repeatMode == AudioRepeatMode.all && 
          currentState.queue.isNotEmpty) {
        return skipToIndex(currentState.queue.length - 1);
      }
      
      return AudioResult.failure(AudioError(
        type: AudioErrorType.state,
        message: 'No previous track available',
        operation: 'skipToPrevious',
        timestamp: DateTime.now(),
      ));
    }
    
    if (kDebugMode) {
      print('AudioManager: skipToPrevious()');
    }
    
    return _operationQueue.enqueue(
      AudioOperationType.skipPrevious,
      () => _doSkipToPrevious(),
    );
  }
  
  /// Skip to a specific index in the queue.
  Future<AudioResult<void>> skipToIndex(int index) async {
    _assertNotDisposed();
    
    if (index < 0 || index >= currentState.queue.length) {
      return AudioResult.failure(AudioError(
        type: AudioErrorType.state,
        message: 'Invalid queue index: $index',
        operation: 'skipToIndex',
        timestamp: DateTime.now(),
      ));
    }
    
    if (kDebugMode) {
      print('AudioManager: skipToIndex($index)');
    }
    
    return _operationQueue.enqueue(
      AudioOperationType.skipToIndex,
      () => _doSkipToIndex(index),
    );
  }

  // ============================================================
  // PUBLIC API - QUEUE MANAGEMENT
  // ============================================================

  /// Add a track to the end of the queue.
  void addToQueue(Track track) {
    _assertNotDisposed();
    
    final newQueue = List<Track>.from(currentState.queue)..add(track);
    _updateState((state) => state.copyWith(queue: newQueue));
    
    if (kDebugMode) {
      print('AudioManager: Added ${track.name} to queue');
    }
  }
  
  /// Add a track to play next (after current track).
  void addNext(Track track) {
    _assertNotDisposed();
    
    final newQueue = List<Track>.from(currentState.queue);
    final insertIndex = (currentState.currentIndex ?? -1) + 1;
    newQueue.insert(insertIndex.clamp(0, newQueue.length), track);
    
    _updateState((state) => state.copyWith(queue: newQueue));
    
    if (kDebugMode) {
      print('AudioManager: Added ${track.name} as next');
    }
  }
  
  /// Remove a track from the queue by index.
  void removeFromQueue(int index) {
    _assertNotDisposed();
    
    if (index < 0 || index >= currentState.queue.length) return;
    
    final newQueue = List<Track>.from(currentState.queue)..removeAt(index);
    int? newIndex = currentState.currentIndex;
    
    if (newIndex != null) {
      if (index < newIndex) {
        newIndex--;
      } else if (index == newIndex) {
        // Removing current track
        if (newQueue.isEmpty) {
          newIndex = null;
        } else if (newIndex >= newQueue.length) {
          newIndex = newQueue.length - 1;
        }
      }
    }
    
    _updateState((state) => state.copyWith(
      queue: newQueue,
      currentIndex: newIndex,
      clearCurrentIndex: newIndex == null,
    ));
    
    if (kDebugMode) {
      print('AudioManager: Removed track at index $index');
    }
  }
  
  /// Reorder a track in the queue.
  void reorderQueue(int oldIndex, int newIndex) {
    _assertNotDisposed();
    
    if (oldIndex < 0 || oldIndex >= currentState.queue.length ||
        newIndex < 0 || newIndex >= currentState.queue.length ||
        oldIndex == newIndex) {
      return;
    }
    
    final newQueue = List<Track>.from(currentState.queue);
    final track = newQueue.removeAt(oldIndex);
    newQueue.insert(newIndex, track);
    
    int? newCurrentIndex = currentState.currentIndex;
    if (newCurrentIndex != null) {
      if (oldIndex == newCurrentIndex) {
        newCurrentIndex = newIndex;
      } else if (oldIndex < newCurrentIndex && newIndex >= newCurrentIndex) {
        newCurrentIndex--;
      } else if (oldIndex > newCurrentIndex && newIndex <= newCurrentIndex) {
        newCurrentIndex++;
      }
    }
    
    _updateState((state) => state.copyWith(
      queue: newQueue,
      currentIndex: newCurrentIndex,
    ));
    
    if (kDebugMode) {
      print('AudioManager: Reordered queue from $oldIndex to $newIndex');
    }
  }
  
  /// Clear the playback queue.
  void clearQueue() {
    _assertNotDisposed();
    
    _updateState((state) => state.copyWith(
      queue: [],
      clearCurrentIndex: true,
    ));
    
    if (kDebugMode) {
      print('AudioManager: Cleared queue');
    }
  }

  // ============================================================
  // PUBLIC API - PLAYBACK MODES
  // ============================================================

  /// Set the repeat mode.
  void setRepeatMode(AudioRepeatMode mode) {
    _assertNotDisposed();
    _updateState((state) => state.copyWith(repeatMode: mode));
    
    if (kDebugMode) {
      print('AudioManager: Set repeat mode to $mode');
    }
  }
  
  /// Toggle through repeat modes: none → one → all → none
  void toggleRepeatMode() {
    _assertNotDisposed();
    
    final currentMode = currentState.repeatMode;
    final newMode = switch (currentMode) {
      AudioRepeatMode.none => AudioRepeatMode.one,
      AudioRepeatMode.one => AudioRepeatMode.all,
      AudioRepeatMode.all => AudioRepeatMode.none,
    };
    
    setRepeatMode(newMode);
  }
  
  /// Set the shuffle mode.
  void setShuffleMode(AudioShuffleMode mode) {
    _assertNotDisposed();
    _updateState((state) => state.copyWith(shuffleMode: mode));
    
    if (kDebugMode) {
      print('AudioManager: Set shuffle mode to $mode');
    }
  }
  
  /// Toggle shuffle on/off.
  void toggleShuffle() {
    _assertNotDisposed();
    
    final newMode = currentState.shuffleMode == AudioShuffleMode.none
        ? AudioShuffleMode.all
        : AudioShuffleMode.none;
    
    setShuffleMode(newMode);
  }
  
  /// Enable or disable gapless playback.
  void setGaplessPlayback(bool enabled) {
    _assertNotDisposed();
    _updateState((state) => state.copyWith(gaplessPlayback: enabled));
    
    if (kDebugMode) {
      print('AudioManager: Set gapless playback to $enabled');
    }
  }
  
  /// Enable or disable radio mode.
  void setRadioMode(bool enabled) {
    _assertNotDisposed();
    _updateState((state) => state.copyWith(radioMode: enabled));
    
    if (kDebugMode) {
      print('AudioManager: Set radio mode to $enabled');
    }
  }

  // ============================================================
  // DISPOSAL
  // ============================================================

  /// Dispose of the AudioManager and release all resources.
  /// 
  /// After calling this, the AudioManager cannot be used again
  /// until [initialize] is called.
  Future<void> dispose() async {
    if (_isDisposed) return;
    
    if (kDebugMode) {
      print('AudioManager: Disposing...');
    }
    
    _isDisposed = true;
    
    // Cancel timers
    _positionUpdateTimer?.cancel();
    
    // Cancel subscriptions
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    
    // Stop the operation queue
    await _operationQueue.dispose();
    
    // Dispose the adapter
    await _adapter.dispose();
    
    // Close streams
    await _stateSubject.close();
    await _errorSubject.close();
    
    // Clear singleton
    _instance = null;
    
    if (kDebugMode) {
      print('AudioManager: Disposed');
    }
  }

  // ============================================================
  // PRIVATE METHODS - OPERATIONS
  // ============================================================

  /// Internal method to play a track with retry logic
  Future<AudioResult<void>> _doPlayTrack(Track track) async {
    // Update state to loading
    _updateState((state) => state.copyWith(
      phase: AudioPhase.loading,
      currentTrack: track,
      userIntendedPlaying: true,
      clearErrorMessage: true,
    ));
    
    // Get alternative audio URLs (includes fallback URLs)
    final urls = _getAlternativeAudioUrls(track);
    if (urls.isEmpty) {
      final error = AudioError(
        type: AudioErrorType.notFound,
        message: 'Could not get audio URL for track',
        operation: 'playTrack',
        track: track,
        timestamp: DateTime.now(),
      );
      _handleError(error);
      return AudioResult.failure(error);
    }
    
    // Try each URL until one works
    AudioError? lastError;
    for (int i = 0; i < urls.length; i++) {
      final url = urls[i];
      
      if (kDebugMode) {
        print('AudioManager: Trying URL ${i + 1}/${urls.length}: $url');
      }
      
      try {
        // Load the track
        final loadResult = await _adapter.load(url, track);
        if (!loadResult.isSuccess) {
          lastError = loadResult.error;
          if (kDebugMode) {
            print('AudioManager: URL $i failed: ${loadResult.error?.message}');
          }
          continue; // Try next URL
        }
        
        // Update duration
        final duration = loadResult.valueOr(Duration.zero);
        _updateState((state) => state.copyWith(
          duration: duration,
          position: Duration.zero,
        ));
        
        // Start playback
        final playResult = await _adapter.play();
        if (!playResult.isSuccess) {
          lastError = playResult.error;
          if (kDebugMode) {
            print('AudioManager: Play failed for URL $i: ${playResult.error?.message}');
          }
          continue; // Try next URL
        }
        
        // Success! Update state to playing
        _updateState((state) => state.copyWith(
          phase: AudioPhase.playing,
          queue: [track],
          currentIndex: 0,
        ));
        
        if (kDebugMode) {
          print('AudioManager: Successfully playing URL ${i + 1}');
        }
        
        return const AudioResult.success(null);
      } catch (e) {
        if (kDebugMode) {
          print('AudioManager: Exception for URL $i: $e');
        }
        lastError = AudioError.fromException(e, 'playTrack', track: track);
        continue; // Try next URL
      }
    }
    
    // All URLs failed
    final error = lastError ?? AudioError(
      type: AudioErrorType.player,
      message: 'All audio URLs failed',
      operation: 'playTrack',
      track: track,
      timestamp: DateTime.now(),
    );
    _handleError(error);
    return AudioResult.failure(error);
  }

  /// Internal method to play a playlist
  Future<AudioResult<void>> _doPlayPlaylist(
    List<Track> tracks,
    int startIndex,
  ) async {
    // Update queue first
    _updateState((state) => state.copyWith(
      queue: List.unmodifiable(tracks),
      currentIndex: startIndex,
      userIntendedPlaying: true,
    ));
    
    // Play the track at startIndex
    return _doPlayTrack(tracks[startIndex]);
  }

  /// Internal method to resume playback
  Future<AudioResult<void>> _doPlay() async {
    final state = currentState;
    
    if (state.phase == AudioPhase.playing) {
      return const AudioResult.success(null); // Already playing
    }
    
    if (!state.canResume) {
      return AudioResult.failure(AudioError(
        type: AudioErrorType.state,
        message: 'Cannot resume from state ${state.phase}',
        operation: 'play',
        timestamp: DateTime.now(),
      ));
    }
    
    _updateState((s) => s.copyWith(userIntendedPlaying: true));
    
    final result = await _adapter.play();
    if (result.isSuccess) {
      _updateState((s) => s.copyWith(phase: AudioPhase.playing));
    }
    
    return result;
  }

  /// Internal method to pause playback
  Future<AudioResult<void>> _doPause() async {
    final state = currentState;
    
    if (state.phase != AudioPhase.playing) {
      return const AudioResult.success(null); // Not playing
    }
    
    _updateState((s) => s.copyWith(userIntendedPlaying: false));
    
    final result = await _adapter.pause();
    if (result.isSuccess) {
      _updateState((s) => s.copyWith(phase: AudioPhase.paused));
    }
    
    return result;
  }

  /// Internal method to stop playback
  Future<AudioResult<void>> _doStop() async {
    _updateState((s) => s.copyWith(userIntendedPlaying: false));
    
    final result = await _adapter.stop();
    if (result.isSuccess) {
      _updateState((s) => s.copyWith(
        phase: AudioPhase.stopped,
        position: Duration.zero,
        clearCurrentTrack: true,
        clearCurrentIndex: true,
      ));
    }
    
    return result;
  }

  /// Internal method to seek
  Future<AudioResult<void>> _doSeek(Duration position) async {
    final result = await _adapter.seek(position);
    if (result.isSuccess) {
      _updateState((s) => s.copyWith(position: position));
    }
    return result;
  }

  /// Internal method to set volume
  Future<AudioResult<void>> _doSetVolume(double volume) async {
    final result = await _adapter.setVolume(volume);
    if (result.isSuccess) {
      _updateState((s) => s.copyWith(volume: volume));
    }
    return result;
  }

  /// Internal method to set speed
  Future<AudioResult<void>> _doSetSpeed(double speed) async {
    final result = await _adapter.setSpeed(speed);
    if (result.isSuccess) {
      _updateState((s) => s.copyWith(speed: speed));
    }
    return result;
  }

  /// Internal method to skip to next track
  Future<AudioResult<void>> _doSkipToNext() async {
    final nextIndex = (currentState.currentIndex ?? 0) + 1;
    return _doSkipToIndex(nextIndex);
  }

  /// Internal method to skip to previous track
  Future<AudioResult<void>> _doSkipToPrevious() async {
    final prevIndex = (currentState.currentIndex ?? 0) - 1;
    return _doSkipToIndex(prevIndex);
  }

  /// Internal method to skip to specific index
  Future<AudioResult<void>> _doSkipToIndex(int index) async {
    final queue = currentState.queue;
    
    if (index < 0 || index >= queue.length) {
      return AudioResult.failure(AudioError(
        type: AudioErrorType.state,
        message: 'Invalid queue index',
        operation: 'skipToIndex',
        timestamp: DateTime.now(),
      ));
    }
    
    _updateState((s) => s.copyWith(currentIndex: index));
    return _doPlayTrack(queue[index]);
  }

  // ============================================================
  // PRIVATE METHODS - HELPERS
  // ============================================================

  /// Update state atomically
  void _updateState(AudioState Function(AudioState current) updater) {
    if (_isDisposed) return;
    
    final newState = updater(_stateSubject.value);
    _stateSubject.add(newState);
  }

  /// Get audio URL for a track
  String? _getAudioUrl(Track track) {
    try {
      return _mediaServiceManager.getStreamUrl(track.id);
    } catch (e) {
      if (kDebugMode) {
        print('AudioManager: Failed to get audio URL: $e');
      }
      return null;
    }
  }

  /// Get alternative audio URLs for a track (includes fallback URLs)
  List<String> _getAlternativeAudioUrls(Track track) {
    try {
      final urls = _mediaServiceManager.getAlternativeStreamUrls(track.id);
      if (kDebugMode) {
        print('AudioManager: Got ${urls.length} alternative URLs for ${track.name}');
      }
      return urls;
    } catch (e) {
      if (kDebugMode) {
        print('AudioManager: Failed to get alternative audio URLs: $e');
      }
      // Fall back to single URL
      final singleUrl = _getAudioUrl(track);
      return singleUrl != null ? [singleUrl] : [];
    }
  }

  /// Handle an error
  void _handleError(AudioError error) {
    if (_isDisposed) return;
    
    if (kDebugMode) {
      print('AudioManager: Error - ${error.message}');
    }
    
    _updateState((s) => s.copyWith(
      phase: AudioPhase.error,
      errorMessage: error.message,
    ));
    
    _errorSubject.add(error);
  }

  /// Handle operation queue errors
  void _handleOperationError(AudioError error) {
    _handleError(error);
  }

  /// Handle stream errors
  void _handleStreamError(Object error, String streamName) {
    if (_isDisposed) return;
    
    if (kDebugMode) {
      print('AudioManager: Stream error on $streamName: $error');
    }
  }

  /// Handle adapter errors
  void _handleAdapterError(AudioError error) {
    _handleError(error);
  }

  /// Assert that the manager is not disposed
  void _assertNotDisposed() {
    if (_isDisposed) {
      throw StateError('AudioManager has been disposed');
    }
  }
}
