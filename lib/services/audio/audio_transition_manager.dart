import 'dart:async';
import 'package:flutter/foundation.dart';

/// Atomic Track Transition Manager - Eliminates race conditions between track completion and manual skips
class AudioTransitionManager {
  // Atomic lock for track transitions
  Completer<void>? _transitionLock;
  String _currentOperation = 'idle';
  Timer? _timeoutTimer;
  DateTime? _lockAcquiredTime;
  
  /// Acquires exclusive transition lock to prevent race conditions
  /// Returns true if lock acquired, false if another operation is in progress
  Future<bool> acquireTransitionLock(String operation) async {
    final now = DateTime.now();
    
    // If there's already a transition in progress, check if it's a skip operation
    if (_transitionLock != null && !_transitionLock!.isCompleted) {
      // For manual skip operations, interrupt automatic track completion to improve responsiveness
      if ((operation == 'skipToNext' || operation == 'skipToPrevious' || operation == 'skipToQueueItem') &&
          _currentOperation == 'trackCompletion') {
        if (kDebugMode) {
          print('Interrupting track completion for manual skip: $operation');
        }
        forceRelease();
      } else {
        // Check for deadlocks - if lock held for more than 10 seconds, force release
        if (_lockAcquiredTime != null && 
            now.difference(_lockAcquiredTime!) > const Duration(seconds: 10)) {
          if (kDebugMode) {
            print('Detected deadlock: $operation ($_currentOperation held for ${now.difference(_lockAcquiredTime!).inSeconds}s) - force releasing');
          }
          forceRelease();
        } else {
          if (kDebugMode) {
            print('Transition rejected: $operation ($_currentOperation in progress for ${_lockAcquiredTime != null ? now.difference(_lockAcquiredTime!).inSeconds : 0}s)');
          }
          return false;
        }
      }
    }
    
    // Cancel existing timeout timer
    _timeoutTimer?.cancel();
    
    // Acquire new lock
    _transitionLock = Completer<void>();
    _currentOperation = operation;
    _lockAcquiredTime = now;
    
    // Set up automatic timeout with different durations based on operation type
    final timeoutDuration = _getTimeoutForOperation(operation);
    _timeoutTimer = Timer(timeoutDuration, () {
      if (_transitionLock != null && !_transitionLock!.isCompleted) {
        if (kDebugMode) {
          print('Transition lock timeout for: $_currentOperation after ${timeoutDuration.inSeconds}s - force releasing');
        }
        forceRelease();
      }
    });
    
    if (kDebugMode) {
      print('Transition lock acquired: $operation (timeout: ${timeoutDuration.inSeconds}s)');
    }
    
    return true;
  }
  
  /// Get appropriate timeout duration based on operation type
  Duration _getTimeoutForOperation(String operation) {
    switch (operation) {
      case 'skipToNext':
      case 'skipToPrevious':
      case 'skipToQueueItem':
        return const Duration(seconds: 8); // Shorter timeout for skip operations
      case 'trackCompletion':
        return const Duration(seconds: 15); // Medium timeout for automatic transitions
      default:
        return const Duration(seconds: 20); // Default timeout
    }
  }
  
  /// Releases the current transition lock
  void releaseTransitionLock() {
    if (_transitionLock != null && !_transitionLock!.isCompleted) {
      if (kDebugMode) {
        print('Transition lock released: $_currentOperation');
      }
      
      _transitionLock!.complete();
      _currentOperation = 'idle';
    }
  }
  
  /// Checks if a transition is currently in progress
  bool get isTransitionInProgress => 
      _transitionLock != null && !_transitionLock!.isCompleted;
  
  /// Gets the current operation type
  String get currentOperation => _currentOperation;
  
  /// Waits for any current transition to complete
  Future<void> waitForTransitionComplete() async {
    if (_transitionLock != null && !_transitionLock!.isCompleted) {
      await _transitionLock!.future;
    }
  }
  
  /// Force releases lock (for error recovery)
  void forceRelease() {
    if (_transitionLock != null && !_transitionLock!.isCompleted) {
      if (kDebugMode) {
        print('Force releasing transition lock: $_currentOperation');
      }
      _transitionLock!.complete();
      _currentOperation = 'idle';
    }
  }
}
