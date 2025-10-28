import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import '../../models/jellyfin_models.dart';
import 'base_audio_handler.dart';

/// Centralized audio state controller to prevent race conditions
/// and ensure consistent state management across all platforms
class AudioStateController {
  static final AudioStateController _instance = AudioStateController._internal();
  factory AudioStateController() => _instance;
  AudioStateController._internal();
  
  // State streams
  final BehaviorSubject<AudioPlayerState> _stateSubject = 
      BehaviorSubject<AudioPlayerState>.seeded(AudioPlayerState.idle);
  final BehaviorSubject<Duration> _positionSubject = 
      BehaviorSubject<Duration>.seeded(Duration.zero);
  final BehaviorSubject<Duration> _durationSubject = 
      BehaviorSubject<Duration>.seeded(Duration.zero);
  final BehaviorSubject<Track?> _currentTrackSubject = 
      BehaviorSubject<Track?>.seeded(null);
  final BehaviorSubject<List<Track>> _queueSubject = 
      BehaviorSubject<List<Track>>.seeded([]);
  final BehaviorSubject<int?> _currentIndexSubject = 
      BehaviorSubject<int?>.seeded(null);
  final BehaviorSubject<double> _volumeSubject = 
      BehaviorSubject<double>.seeded(1.0);
  final BehaviorSubject<double> _speedSubject = 
      BehaviorSubject<double>.seeded(1.0);
  final BehaviorSubject<RepeatMode> _repeatModeSubject = 
      BehaviorSubject<RepeatMode>.seeded(RepeatMode.none);
  final BehaviorSubject<bool> _shuffleEnabledSubject = 
      BehaviorSubject<bool>.seeded(false);
  final BehaviorSubject<bool> _gaplessPlaybackSubject = 
      BehaviorSubject<bool>.seeded(false);
  final BehaviorSubject<bool> _radioModeSubject = 
      BehaviorSubject<bool>.seeded(false);
  final BehaviorSubject<String?> _errorSubject = 
      BehaviorSubject<String?>.seeded(null);
  
  // Command processing queue to prevent race conditions
  final Queue<Future<void> Function()> _commandQueue = Queue();
  bool _processingCommands = false;
  
  // User intent tracking (critical for race condition prevention)
  bool _userIntendedPlaying = false;
  DateTime? _lastCommandTime;
  
  // Getters for streams
  Stream<AudioPlayerState> get stateStream => _stateSubject.stream;
  Stream<Duration> get positionStream => _positionSubject.stream;
  Stream<Duration> get durationStream => _durationSubject.stream;
  Stream<Track?> get currentTrackStream => _currentTrackSubject.stream;
  Stream<List<Track>> get queueStream => _queueSubject.stream;
  Stream<int?> get currentIndexStream => _currentIndexSubject.stream;
  Stream<double> get volumeStream => _volumeSubject.stream;
  Stream<double> get speedStream => _speedSubject.stream;
  Stream<RepeatMode> get repeatModeStream => _repeatModeSubject.stream;
  Stream<bool> get shuffleEnabledStream => _shuffleEnabledSubject.stream;
  Stream<bool> get gaplessPlaybackStream => _gaplessPlaybackSubject.stream;
  Stream<bool> get radioModeStream => _radioModeSubject.stream;
  Stream<String?> get errorStream => _errorSubject.stream;
  
  // Current values
  AudioPlayerState get currentState => _stateSubject.value;
  Duration get position => _positionSubject.value;
  Duration get duration => _durationSubject.value;
  Track? get currentTrack => _currentTrackSubject.value;
  List<Track> get queue => _queueSubject.value;
  int? get currentIndex => _currentIndexSubject.value;
  double get volume => _volumeSubject.value;
  double get speed => _speedSubject.value;
  RepeatMode get repeatMode => _repeatModeSubject.value;
  bool get shuffleEnabled => _shuffleEnabledSubject.value;
  bool get gaplessPlaybackEnabled => _gaplessPlaybackSubject.value;
  bool get radioModeEnabled => _radioModeSubject.value;
  String? get error => _errorSubject.value;
  bool get userIntendedPlaying => _userIntendedPlaying;
  
  // Computed properties
  bool get hasNext => currentIndex != null && currentIndex! < queue.length - 1;
  bool get hasPrevious => currentIndex != null && currentIndex! > 0;
  List<Track> get upNext {
    if (currentIndex == null || queue.isEmpty) return [];
    return queue.skip(currentIndex! + 1).toList();
  }
  
  /// Queue a command for sequential processing to prevent race conditions
  Future<void> queueCommand(Future<void> Function() command) async {
    final completer = Completer<void>();
    
    _commandQueue.add(() async {
      try {
        await command();
        completer.complete();
      } catch (e) {
        completer.completeError(e);
      }
    });
    
    _processCommandQueue();
    return completer.future;
  }
  
  /// Process command queue sequentially with minimal delays
  Future<void> _processCommandQueue() async {
    if (_processingCommands || _commandQueue.isEmpty) return;
    
    _processingCommands = true;
    
    try {
      while (_commandQueue.isNotEmpty) {
        final command = _commandQueue.removeFirst();
        await command();
        
        // No delay for maximum responsiveness
        // Commands are processed as fast as possible
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error processing command queue: $e');
      }
      updateError('Command processing failed: $e');
    } finally {
      _processingCommands = false;
    }
  }
  
  /// Update user intent for play/pause operations
  void updateUserIntent(bool intendedPlaying) {
    _userIntendedPlaying = intendedPlaying;
    _lastCommandTime = DateTime.now();
  }
  
  /// Check if a command should be debounced
  bool shouldDebounceCommand([Duration? debounceTime]) {
    if (_lastCommandTime == null) return false;
    
    final threshold = debounceTime ?? const Duration(milliseconds: 300);
    return DateTime.now().difference(_lastCommandTime!) < threshold;
  }
  
  // State update methods
  void updateState(AudioPlayerState state) {
    if (_stateSubject.value != state) {
      _stateSubject.add(state);
      if (kDebugMode) {
        print('AudioState: State updated to $state');
      }
    }
  }
  
  void updatePosition(Duration position) {
    _positionSubject.add(position);
  }
  
  void updateDuration(Duration duration) {
    if (_durationSubject.value != duration) {
      _durationSubject.add(duration);
    }
  }
  
  void updateCurrentTrack(Track? track) {
    if (_currentTrackSubject.value?.id != track?.id) {
      _currentTrackSubject.add(track);
      if (kDebugMode && track != null) {
        if (kDebugMode) {
          print('AudioState: Current track updated to ${track.name}');
        }
      }
    }
  }
  
  void updateQueue(List<Track> queue, {int? currentIndex}) {
    _queueSubject.add(List.unmodifiable(queue));
    if (currentIndex != null) {
      _currentIndexSubject.add(currentIndex);
    }
    if (kDebugMode) {
      print('AudioState: Queue updated with ${queue.length} tracks, index: $currentIndex');
    }
  }
  
  /// Add track to queue (for queue management)
  void addTrackToQueue(Track track) {
    final currentQueue = List<Track>.from(_queueSubject.value);
    currentQueue.add(track);
    _queueSubject.add(List.unmodifiable(currentQueue));
  }
  
  /// Add track as next in queue
  void addTrackNext(Track track) {
    final currentQueue = List<Track>.from(_queueSubject.value);
    final currentIndex = _currentIndexSubject.value ?? 0;
    final insertPosition = (currentIndex + 1).clamp(0, currentQueue.length);
    currentQueue.insert(insertPosition, track);
    _queueSubject.add(List.unmodifiable(currentQueue));
  }
  
  /// Remove track from queue by index
  void removeTrackFromQueue(int index) {
    final currentQueue = List<Track>.from(_queueSubject.value);
    if (index >= 0 && index < currentQueue.length) {
      currentQueue.removeAt(index);
      _queueSubject.add(List.unmodifiable(currentQueue));
      
      // Update current index if needed
      final currentIndex = _currentIndexSubject.value;
      if (currentIndex != null) {
        if (index < currentIndex) {
          _currentIndexSubject.add(currentIndex - 1);
        } else if (index == currentIndex && currentIndex >= currentQueue.length) {
          _currentIndexSubject.add(currentQueue.length - 1);
        }
      }
    }
  }
  
  void updateCurrentIndex(int? index) {
    _currentIndexSubject.add(index);
  }
  
  void updateVolume(double volume) {
    _volumeSubject.add(volume.clamp(0.0, 1.0));
  }
  
  void updateSpeed(double speed) {
    _speedSubject.add(speed.clamp(0.25, 4.0));
  }
  
  void updateRepeatMode(RepeatMode mode) {
    _repeatModeSubject.add(mode);
  }
  
  void updateShuffleEnabled(bool enabled) {
    _shuffleEnabledSubject.add(enabled);
  }
  
  void updateGaplessPlayback(bool enabled) {
    _gaplessPlaybackSubject.add(enabled);
  }
  
  void updateRadioMode(bool enabled) {
    _radioModeSubject.add(enabled);
  }
  
  void updateError(String? error) {
    _errorSubject.add(error);
    if (error != null && kDebugMode) {
      if (kDebugMode) {
        print('AudioState: Error updated - $error');
      }
    }
  }
  
  void clearError() {
    updateError(null);
  }
  
  /// Reset all state to initial values
  void reset() {
    updateState(AudioPlayerState.idle);
    updatePosition(Duration.zero);
    updateDuration(Duration.zero);
    updateCurrentTrack(null);
    updateQueue([], currentIndex: null);
    updateVolume(1.0);
    updateSpeed(1.0);
    updateRepeatMode(RepeatMode.none);
    updateShuffleEnabled(false);
    updateRadioMode(false);
    clearError();
    _userIntendedPlaying = false;
    _lastCommandTime = null;
    
    // Clear any pending commands
    _commandQueue.clear();
    _processingCommands = false;
  }
  
  /// Dispose all streams
  void dispose() {
    _stateSubject.close();
    _positionSubject.close();
    _durationSubject.close();
    _currentTrackSubject.close();
    _queueSubject.close();
    _currentIndexSubject.close();
    _volumeSubject.close();
    _speedSubject.close();
    _repeatModeSubject.close();
    _shuffleEnabledSubject.close();
    _gaplessPlaybackSubject.close();
    _radioModeSubject.close();
    _errorSubject.close();
  }
}

/// Extensions for queue management
extension QueueManagement on AudioStateController {
  /// Add track to end of queue
  void addTrackToQueue(Track track) {
    final currentQueue = List<Track>.from(queue);
    currentQueue.add(track);
    updateQueue(currentQueue);
  }
  
  /// Add track as next in queue
  void addTrackNext(Track track) {
    final currentQueue = List<Track>.from(queue);
    final insertIndex = currentIndex != null ? currentIndex! + 1 : 0;
    currentQueue.insert(insertIndex, track);
    updateQueue(currentQueue, currentIndex: currentIndex);
  }
  
  /// Remove track from queue
  void removeTrackFromQueue(int index) {
    if (index < 0 || index >= queue.length) return;
    
    final currentQueue = List<Track>.from(queue);
    currentQueue.removeAt(index);
    
    int? newCurrentIndex = currentIndex;
    if (currentIndex != null) {
      if (index < currentIndex!) {
        newCurrentIndex = currentIndex! - 1;
      } else if (index == currentIndex!) {
        // Removing current track
        if (currentQueue.isEmpty) {
          newCurrentIndex = null;
        } else if (newCurrentIndex! >= currentQueue.length) {
          newCurrentIndex = currentQueue.length - 1;
        }
      }
    }
    
    updateQueue(currentQueue, currentIndex: newCurrentIndex);
  }
  
  /// Reorder queue
  void reorderQueueItems(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= queue.length || 
        newIndex < 0 || newIndex >= queue.length || 
        oldIndex == newIndex) {
      return;
    }
    
    final currentQueue = List<Track>.from(queue);
    final track = currentQueue.removeAt(oldIndex);
    currentQueue.insert(newIndex, track);
    
    int? newCurrentIndex = currentIndex;
    if (currentIndex != null) {
      if (oldIndex == currentIndex) {
        newCurrentIndex = newIndex;
      } else if (oldIndex < currentIndex! && newIndex >= currentIndex!) {
        newCurrentIndex = currentIndex! - 1;
      } else if (oldIndex > currentIndex! && newIndex <= currentIndex!) {
        newCurrentIndex = currentIndex! + 1;
      }
    }
    
    updateQueue(currentQueue, currentIndex: newCurrentIndex);
  }
  
  /// Shuffle queue (keeping current track in place)
  void shuffleQueue() {
    if (queue.length <= 1) return;
    
    final currentQueue = List<Track>.from(queue);
    Track? currentTrackToKeep;
    
    if (currentIndex != null && currentIndex! < currentQueue.length) {
      currentTrackToKeep = currentQueue[currentIndex!];
      currentQueue.removeAt(currentIndex!);
    }
    
    currentQueue.shuffle();
    
    if (currentTrackToKeep != null) {
      currentQueue.insert(0, currentTrackToKeep);
      updateQueue(currentQueue, currentIndex: 0);
    } else {
      updateQueue(currentQueue);
    }
  }
  
  /// Clear queue
  void clearQueue() {
    updateQueue([], currentIndex: null);
  }
}