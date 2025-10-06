import 'dart:async';
import 'package:flutter/foundation.dart';

/// Atomic Track Transition Manager - Eliminates race conditions between track completion and manual skips
class AudioTransitionManager {
  // Atomic lock for track transitions
  Completer<void>? _transitionLock;
  String _currentOperation = 'idle';
  
  /// Acquires exclusive transition lock to prevent race conditions
  /// Returns true if lock acquired, false if another operation is in progress
  Future<bool> acquireTransitionLock(String operation) async {
    // If there's already a transition in progress, reject this request
    if (_transitionLock != null && !_transitionLock!.isCompleted) {
      if (kDebugMode) {
        print('Transition rejected: $operation ($_currentOperation in progress)');
      }
      return false;
    }
    
    // Acquire new lock
    _transitionLock = Completer<void>();
    _currentOperation = operation;
    
    // Set up automatic timeout to prevent deadlocks (30 seconds)
    Timer(const Duration(seconds: 30), () {
      if (_transitionLock != null && !_transitionLock!.isCompleted) {
        if (kDebugMode) {
          print('Transition lock timeout for: $_currentOperation - force releasing');
        }
        forceRelease();
      }
    });
    
    if (kDebugMode) {
      print('Transition lock acquired: $operation');
    }
    
    return true;
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
