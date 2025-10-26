/// Atomic position updates for AudioHandler to prevent position jumps and race conditions
/// Ensures position changes are properly debounced and synchronized
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'async_mutex.dart';

/// Manages atomic position updates with debouncing and conflict resolution
class AudioPositionManager {
  final NamedMutexManager _mutexManager = NamedMutexManager();
  
  Duration _lastReportedPosition = Duration.zero;
  Duration _lastSeekPosition = Duration.zero;
  DateTime _lastSeekTime = DateTime.now();
  DateTime _lastPositionUpdate = DateTime.now();
  
  Timer? _positionDebounceTimer;
  Timer? _seekProtectionTimer;
  
  bool _isSeekInProgress = false;
  bool _isBuffering = false;
  
  /// Current position with protection against seek conflicts
  Duration get currentPosition => _lastReportedPosition;
  
  /// Whether a seek operation is in progress
  bool get isSeekInProgress => _isSeekInProgress;
  
  /// Whether buffering is in progress (positions may be unreliable)
  bool get isBuffering => _isBuffering;
  
  /// Update buffering state to protect against unreliable positions
  void setBuffering(bool buffering) {
    _isBuffering = buffering;
    if (kDebugMode) {
      print('Position manager: Buffering state changed to $buffering');
    }
  }
  
  /// Record a seek operation to protect against position conflicts
  Future<void> recordSeek(Duration seekPosition) async {
    return await _mutexManager.withLock('positionUpdate', () async {
      _isSeekInProgress = true;
      _lastSeekPosition = seekPosition;
      _lastSeekTime = DateTime.now();
      _lastReportedPosition = seekPosition;
      
      if (kDebugMode) {
        print('Position manager: Seek recorded to ${seekPosition.inSeconds}s');
      }
      
      // Clear seek protection after a reasonable time
      _seekProtectionTimer?.cancel();
      _seekProtectionTimer = Timer(const Duration(milliseconds: 500), () {
        _isSeekInProgress = false;
        if (kDebugMode) {
          print('Position manager: Seek protection cleared');
        }
      });
    });
  }
  
  /// Update position with atomic protection and debouncing
  Future<Duration?> updatePosition(Duration newPosition, {
    bool fromStream = true,
    bool forceUpdate = false,
  }) async {
    return await _mutexManager.withLock('positionUpdate', () async {
      final now = DateTime.now();
      
      // Skip position updates during buffering unless forced
      if (_isBuffering && !forceUpdate) {
        if (kDebugMode) {
          print('Position manager: Skipping position update during buffering');
        }
        return null;
      }
      
      // Protect against position updates immediately after seek
      if (_isSeekInProgress && fromStream) {
        final timeSinceSeek = now.difference(_lastSeekTime);
        if (timeSinceSeek < const Duration(milliseconds: 300)) {
          if (kDebugMode) {
            print('Position manager: Ignoring stream position ${newPosition.inSeconds}s - recent seek in progress');
          }
          return null;
        }
      }
      
      // Validate position is reasonable (not jumping backward unexpectedly)
      if (fromStream && !forceUpdate) {
        final positionDiff = newPosition.inMilliseconds - _lastReportedPosition.inMilliseconds;
        final timeDiff = now.difference(_lastPositionUpdate).inMilliseconds;
        
        // Check for unrealistic backward jumps (unless near beginning)
        if (positionDiff < -1000 && _lastReportedPosition.inSeconds > 2) {
          if (kDebugMode) {
            print('Position manager: Rejecting backward jump from ${_lastReportedPosition.inSeconds}s to ${newPosition.inSeconds}s');
          }
          return null;
        }
        
        // Check for unrealistic forward jumps
        if (positionDiff > timeDiff + 2000) {
          if (kDebugMode) {
            print('Position manager: Rejecting forward jump from ${_lastReportedPosition.inSeconds}s to ${newPosition.inSeconds}s');
          }
          return null;
        }
      }
      
      // Update stored position
      _lastReportedPosition = newPosition;
      _lastPositionUpdate = now;
      
      if (kDebugMode && !fromStream) {
        if (kDebugMode) {
          print('Position manager: Position updated to ${newPosition.inSeconds}s (${forceUpdate ? 'forced' : 'manual'})');
        }
      }
      
      return newPosition;
    });
  }
  
  /// Debounced position update to prevent excessive UI updates
  Future<Duration?> updatePositionDebounced(
    Duration newPosition, 
    Function(Duration) onPositionUpdate, {
    Duration debounceTime = const Duration(milliseconds: 100),
    bool fromStream = true,
  }) async {
    
    // Cancel existing debounce timer
    _positionDebounceTimer?.cancel();
    
    // Set new debounce timer
    _positionDebounceTimer = Timer(debounceTime, () async {
      final validatedPosition = await updatePosition(newPosition, fromStream: fromStream);
      if (validatedPosition != null) {
        onPositionUpdate(validatedPosition);
      }
    });
    
    return null; // Position will be updated via callback
  }
  
  /// Force an immediate position update (for seeks)
  Future<Duration?> forcePositionUpdate(Duration newPosition) async {
    return await updatePosition(newPosition, fromStream: false, forceUpdate: true);
  }
  
  /// Get position statistics for debugging
  Map<String, dynamic> getStatistics() {
    return {
      'currentPosition': _lastReportedPosition.inSeconds,
      'lastSeekPosition': _lastSeekPosition.inSeconds,
      'isSeekInProgress': _isSeekInProgress,
      'isBuffering': _isBuffering,
      'timeSinceLastSeek': DateTime.now().difference(_lastSeekTime).inMilliseconds,
      'timeSinceLastUpdate': DateTime.now().difference(_lastPositionUpdate).inMilliseconds,
    };
  }
  
  /// Dispose timers and cleanup
  void dispose() {
    _positionDebounceTimer?.cancel();
    _seekProtectionTimer?.cancel();
    
    if (kDebugMode) {
      print('Position manager disposed');
    }
  }
}