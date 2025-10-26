import 'dart:async';

/// Audio player states with clear transitions
enum AudioPlayerState {
  idle,
  loading,
  ready,
  playing,
  paused,
  buffering,
  seeking,
  error,
  completed,
  disposed,
}

/// User intent states
enum UserIntent {
  none,
  play,
  pause,
  stop,
  seek,
}

/// Audio state machine to manage player state and user intent synchronization
/// Prevents race conditions between UI state and actual player state
class AudioStateMachine {
  AudioPlayerState _currentState = AudioPlayerState.idle;
  UserIntent _currentIntent = UserIntent.none;
  
  final StreamController<AudioPlayerState> _stateController = StreamController.broadcast();
  final StreamController<UserIntent> _intentController = StreamController.broadcast();
  
  // Valid state transitions to prevent invalid state changes
  static const Map<AudioPlayerState, Set<AudioPlayerState>> _validTransitions = {
    AudioPlayerState.idle: {
      AudioPlayerState.loading,
      AudioPlayerState.disposed,
    },
    AudioPlayerState.loading: {
      AudioPlayerState.ready,
      AudioPlayerState.error,
      AudioPlayerState.idle,
      AudioPlayerState.disposed,
    },
    AudioPlayerState.ready: {
      AudioPlayerState.playing,
      AudioPlayerState.paused,
      AudioPlayerState.buffering,
      AudioPlayerState.error,
      AudioPlayerState.idle,
      AudioPlayerState.disposed,
    },
    AudioPlayerState.playing: {
      AudioPlayerState.paused,
      AudioPlayerState.buffering,
      AudioPlayerState.seeking,
      AudioPlayerState.completed,
      AudioPlayerState.error,
      AudioPlayerState.idle,
      AudioPlayerState.disposed,
    },
    AudioPlayerState.paused: {
      AudioPlayerState.playing,
      AudioPlayerState.seeking,
      AudioPlayerState.error,
      AudioPlayerState.idle,
      AudioPlayerState.disposed,
    },
    AudioPlayerState.buffering: {
      AudioPlayerState.playing,
      AudioPlayerState.paused,
      AudioPlayerState.ready,
      AudioPlayerState.error,
      AudioPlayerState.idle,
      AudioPlayerState.disposed,
    },
    AudioPlayerState.seeking: {
      AudioPlayerState.playing,
      AudioPlayerState.paused,
      AudioPlayerState.ready,
      AudioPlayerState.error,
      AudioPlayerState.disposed,
    },
    AudioPlayerState.error: {
      AudioPlayerState.idle,
      AudioPlayerState.loading,
      AudioPlayerState.disposed,
    },
    AudioPlayerState.completed: {
      AudioPlayerState.idle,
      AudioPlayerState.loading,
      AudioPlayerState.disposed,
    },
    AudioPlayerState.disposed: {
      // No transitions from disposed state
    },
  };
  
  // Getters
  AudioPlayerState get currentState => _currentState;
  UserIntent get currentIntent => _currentIntent;
  Stream<AudioPlayerState> get stateStream => _stateController.stream;
  Stream<UserIntent> get intentStream => _intentController.stream;
  
  /// Attempt to transition to a new state
  /// Returns true if transition is valid and successful
  bool transitionTo(AudioPlayerState newState) {
    if (_currentState == AudioPlayerState.disposed) {
      return false; // Cannot transition from disposed state
    }
    
    final allowedTransitions = _validTransitions[_currentState];
    if (allowedTransitions == null || !allowedTransitions.contains(newState)) {
      return false; // Invalid transition
    }
    
    _currentState = newState;
    _stateController.add(_currentState);
    return true;
  }
  
  /// Set user intent
  void setIntent(UserIntent intent) {
    _currentIntent = intent;
    _intentController.add(_currentIntent);
  }
  
  /// Check if the current state allows playback
  bool get canPlay {
    return _currentState == AudioPlayerState.ready ||
           _currentState == AudioPlayerState.paused ||
           _currentState == AudioPlayerState.buffering;
  }
  
  /// Check if the current state allows pause
  bool get canPause {
    return _currentState == AudioPlayerState.playing ||
           _currentState == AudioPlayerState.buffering;
  }
  
  /// Check if user wants to play (regardless of current state)
  bool get userWantsToPlay {
    return _currentIntent == UserIntent.play;
  }
  
  /// Check if user wants to pause (regardless of current state)
  bool get userWantsToPause {
    return _currentIntent == UserIntent.pause;
  }
  
  /// Check if state and intent are synchronized
  bool get isStateSynchronized {
    switch (_currentIntent) {
      case UserIntent.play:
        return _currentState == AudioPlayerState.playing || 
               _currentState == AudioPlayerState.buffering;
      case UserIntent.pause:
        return _currentState == AudioPlayerState.paused;
      case UserIntent.stop:
        return _currentState == AudioPlayerState.idle || 
               _currentState == AudioPlayerState.completed;
      case UserIntent.none:
      case UserIntent.seek:
        return true; // These don't require specific sync
    }
  }
  
  /// Get the state the player should be in based on user intent
  AudioPlayerState? getTargetStateForIntent() {
    switch (_currentIntent) {
      case UserIntent.play:
        return canPlay ? AudioPlayerState.playing : null;
      case UserIntent.pause:
        return canPause ? AudioPlayerState.paused : null;
      case UserIntent.stop:
        return AudioPlayerState.idle;
      case UserIntent.none:
      case UserIntent.seek:
        return null; // No specific target state
    }
  }
  
  /// Reset to initial state
  void reset() {
    _currentState = AudioPlayerState.idle;
    _currentIntent = UserIntent.none;
    _stateController.add(_currentState);
    _intentController.add(_currentIntent);
  }
  
  /// Dispose the state machine
  void dispose() {
    _currentState = AudioPlayerState.disposed;
    _stateController.close();
    _intentController.close();
  }
  
  @override
  String toString() {
    return 'AudioStateMachine(state: $_currentState, intent: $_currentIntent, synced: $isStateSynchronized)';
  }
}