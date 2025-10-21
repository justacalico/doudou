import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../logging_service.dart';

/// Represents different player states in our state machine
enum PlayerTransitionState {
  idle,
  loading,
  ready,
  playing,
  paused,
  seeking,
  buffering,
  completed,
  stopped,
  error,
}

/// Represents player transition events
enum PlayerTransitionEvent {
  load,
  play,
  pause,
  stop,
  seek,
  complete,
  error,
  buffer,
  ready,
}

/// Player state transition validation result
class StateTransitionResult {
  final bool isValid;
  final String reason;
  final PlayerTransitionState? newState;
  
  const StateTransitionResult.valid(this.newState) 
    : isValid = true, 
      reason = '';
  
  const StateTransitionResult.invalid(this.reason) 
    : isValid = false, 
      newState = null;
}

/// Coordinates player state transitions to prevent race conditions
/// and ensure consistent state machine behavior
class PlayerStateTransitionCoordinator {
  static final _logger = LoggingService();
  
  PlayerTransitionState _currentState = PlayerTransitionState.idle;
  final StreamController<PlayerTransitionState> _stateController = 
      StreamController<PlayerTransitionState>.broadcast();
  
  /// Lock to prevent concurrent state transitions
  bool _isTransitioning = false;
  
  /// Queue for pending state transitions
  final List<_QueuedTransition> _transitionQueue = [];
  
  /// Current state stream
  Stream<PlayerTransitionState> get stateStream => _stateController.stream;
  
  /// Current player state
  PlayerTransitionState get currentState => _currentState;
  
  /// Whether a transition is currently in progress
  bool get isTransitioning => _isTransitioning;
  
  /// Initialize the coordinator
  void initialize() {
    _currentState = PlayerTransitionState.idle;
    if (kDebugMode) {
      print('PlayerStateTransitionCoordinator: Initialized in state $_currentState');
    }
  }
  
  /// Request a state transition with validation
  Future<bool> requestTransition(
    PlayerTransitionEvent event, {
    Map<String, dynamic>? context,
  }) async {
    if (_isTransitioning) {
      // Queue the transition for later processing
      _transitionQueue.add(_QueuedTransition(event, context));
      if (kDebugMode) {
        print('PlayerStateTransitionCoordinator: Queued transition $event (current: $_currentState)');
      }
      return false;
    }
    
    return await _executeTransition(event, context);
  }
  
  /// Execute a state transition atomically
  Future<bool> _executeTransition(
    PlayerTransitionEvent event, 
    Map<String, dynamic>? context,
  ) async {
    _isTransitioning = true;
    
    try {
      final validationResult = _validateTransition(event);
      
      if (!validationResult.isValid) {
        _logger.warning(
          'Invalid state transition: $_currentState -> $event (${validationResult.reason})', 
          'PlayerStateTransitionCoordinator'
        );
        return false;
      }
      
      final previousState = _currentState;
      _currentState = validationResult.newState!;
      
      if (kDebugMode) {
        print('PlayerStateTransitionCoordinator: Transition $previousState -> $_currentState via $event');
      }
      
      // Emit state change
      _stateController.add(_currentState);
      
      // Process any queued transitions
      _processQueuedTransitions();
      
      return true;
    } catch (e) {
      _logger.error('Error during state transition: $e', 'PlayerStateTransitionCoordinator');
      return false;
    } finally {
      _isTransitioning = false;
    }
  }
  
  /// Validate if a state transition is allowed
  StateTransitionResult _validateTransition(PlayerTransitionEvent event) {
    switch (_currentState) {
      case PlayerTransitionState.idle:
        switch (event) {
          case PlayerTransitionEvent.load:
            return StateTransitionResult.valid(PlayerTransitionState.loading);
          case PlayerTransitionEvent.stop:
            return StateTransitionResult.valid(PlayerTransitionState.idle); // Allow stop from idle (no-op)
          case PlayerTransitionEvent.error:
            return StateTransitionResult.valid(PlayerTransitionState.error);
          default:
            return StateTransitionResult.invalid('Cannot $event from idle state');
        }
        
      case PlayerTransitionState.loading:
        switch (event) {
          case PlayerTransitionEvent.ready:
            return StateTransitionResult.valid(PlayerTransitionState.ready);
          case PlayerTransitionEvent.buffer:
            return StateTransitionResult.valid(PlayerTransitionState.buffering);
          case PlayerTransitionEvent.error:
            return StateTransitionResult.valid(PlayerTransitionState.error);
          case PlayerTransitionEvent.stop:
            return StateTransitionResult.valid(PlayerTransitionState.stopped);
          default:
            return StateTransitionResult.invalid('Cannot $event from loading state');
        }
        
      case PlayerTransitionState.ready:
        switch (event) {
          case PlayerTransitionEvent.play:
            return StateTransitionResult.valid(PlayerTransitionState.playing);
          case PlayerTransitionEvent.ready:
            return StateTransitionResult.valid(PlayerTransitionState.ready); // Allow repeated ready events
          case PlayerTransitionEvent.buffer:
            return StateTransitionResult.valid(PlayerTransitionState.buffering);
          case PlayerTransitionEvent.seek:
            return StateTransitionResult.valid(PlayerTransitionState.seeking);
          case PlayerTransitionEvent.stop:
            return StateTransitionResult.valid(PlayerTransitionState.stopped);
          case PlayerTransitionEvent.error:
            return StateTransitionResult.valid(PlayerTransitionState.error);
          default:
            return StateTransitionResult.invalid('Cannot $event from ready state');
        }
        
      case PlayerTransitionState.playing:
        switch (event) {
          case PlayerTransitionEvent.pause:
            return StateTransitionResult.valid(PlayerTransitionState.paused);
          case PlayerTransitionEvent.seek:
            return StateTransitionResult.valid(PlayerTransitionState.seeking);
          case PlayerTransitionEvent.complete:
            return StateTransitionResult.valid(PlayerTransitionState.completed);
          case PlayerTransitionEvent.buffer:
            return StateTransitionResult.valid(PlayerTransitionState.buffering);
          case PlayerTransitionEvent.stop:
            return StateTransitionResult.valid(PlayerTransitionState.stopped);
          case PlayerTransitionEvent.error:
            return StateTransitionResult.valid(PlayerTransitionState.error);
          default:
            return StateTransitionResult.invalid('Cannot $event from playing state');
        }
        
      case PlayerTransitionState.paused:
        switch (event) {
          case PlayerTransitionEvent.play:
            return StateTransitionResult.valid(PlayerTransitionState.playing);
          case PlayerTransitionEvent.seek:
            return StateTransitionResult.valid(PlayerTransitionState.seeking);
          case PlayerTransitionEvent.stop:
            return StateTransitionResult.valid(PlayerTransitionState.stopped);
          case PlayerTransitionEvent.error:
            return StateTransitionResult.valid(PlayerTransitionState.error);
          default:
            return StateTransitionResult.invalid('Cannot $event from paused state');
        }
        
      case PlayerTransitionState.seeking:
        switch (event) {
          case PlayerTransitionEvent.ready:
            return StateTransitionResult.valid(PlayerTransitionState.ready);
          case PlayerTransitionEvent.play:
            return StateTransitionResult.valid(PlayerTransitionState.playing);
          case PlayerTransitionEvent.pause:
            return StateTransitionResult.valid(PlayerTransitionState.paused);
          case PlayerTransitionEvent.error:
            return StateTransitionResult.valid(PlayerTransitionState.error);
          default:
            return StateTransitionResult.invalid('Cannot $event from seeking state');
        }
        
      case PlayerTransitionState.buffering:
        switch (event) {
          case PlayerTransitionEvent.ready:
            return StateTransitionResult.valid(PlayerTransitionState.ready); // Return to ready, not playing
          case PlayerTransitionEvent.play:
            return StateTransitionResult.valid(PlayerTransitionState.playing); // Allow play during buffering
          case PlayerTransitionEvent.pause:
            return StateTransitionResult.valid(PlayerTransitionState.paused);
          case PlayerTransitionEvent.buffer:
            return StateTransitionResult.valid(PlayerTransitionState.buffering); // Allow repeated buffering
          case PlayerTransitionEvent.error:
            return StateTransitionResult.valid(PlayerTransitionState.error);
          case PlayerTransitionEvent.stop:
            return StateTransitionResult.valid(PlayerTransitionState.stopped);
          default:
            return StateTransitionResult.invalid('Cannot $event from buffering state');
        }
        
      case PlayerTransitionState.completed:
        switch (event) {
          case PlayerTransitionEvent.load:
            return StateTransitionResult.valid(PlayerTransitionState.loading);
          case PlayerTransitionEvent.seek:
            return StateTransitionResult.valid(PlayerTransitionState.seeking);
          case PlayerTransitionEvent.stop:
            return StateTransitionResult.valid(PlayerTransitionState.stopped);
          case PlayerTransitionEvent.error:
            return StateTransitionResult.valid(PlayerTransitionState.error);
          default:
            return StateTransitionResult.invalid('Cannot $event from completed state');
        }
        
      case PlayerTransitionState.stopped:
        switch (event) {
          case PlayerTransitionEvent.load:
            return StateTransitionResult.valid(PlayerTransitionState.loading);
          case PlayerTransitionEvent.error:
            return StateTransitionResult.valid(PlayerTransitionState.error);
          default:
            return StateTransitionResult.invalid('Cannot $event from stopped state');
        }
        
      case PlayerTransitionState.error:
        switch (event) {
          case PlayerTransitionEvent.load:
            return StateTransitionResult.valid(PlayerTransitionState.loading);
          case PlayerTransitionEvent.stop:
            return StateTransitionResult.valid(PlayerTransitionState.stopped);
          default:
            return StateTransitionResult.invalid('Cannot $event from error state');
        }
    }
  }
  
  /// Process any queued transitions
  void _processQueuedTransitions() {
    if (_transitionQueue.isEmpty || _isTransitioning) {
      return;
    }
    
    // Process the first queued transition
    final queuedTransition = _transitionQueue.removeAt(0);
    
    // Execute asynchronously to avoid blocking
    Future.microtask(() async {
      await _executeTransition(queuedTransition.event, queuedTransition.context);
    });
  }
  
  /// Force a state reset (use with caution)
  void forceReset() {
    _isTransitioning = false;
    _transitionQueue.clear();
    _currentState = PlayerTransitionState.idle;
    _stateController.add(_currentState);
    
    if (kDebugMode) {
      print('PlayerStateTransitionCoordinator: Force reset to idle state');
    }
  }
  
  /// Map just_audio ProcessingState to our transition events
  PlayerTransitionEvent mapProcessingStateToEvent(ProcessingState processingState) {
    switch (processingState) {
      case ProcessingState.idle:
        return PlayerTransitionEvent.stop;
      case ProcessingState.loading:
        return PlayerTransitionEvent.load;
      case ProcessingState.buffering:
        return PlayerTransitionEvent.buffer;
      case ProcessingState.ready:
        return PlayerTransitionEvent.ready;
      case ProcessingState.completed:
        return PlayerTransitionEvent.complete;
    }
  }
  
  /// Check if a transition would be valid without executing it
  bool wouldTransitionBeValid(PlayerTransitionEvent event) {
    return _validateTransition(event).isValid;
  }
  
  /// Dispose resources
  void dispose() {
    _stateController.close();
    _transitionQueue.clear();
    if (kDebugMode) {
      print('PlayerStateTransitionCoordinator: Disposed');
    }
  }
}

/// Internal class for queued transitions
class _QueuedTransition {
  final PlayerTransitionEvent event;
  final Map<String, dynamic>? context;
  
  _QueuedTransition(this.event, this.context);
}