/// Immutable state management for Android AudioService behavior
/// Prevents race conditions in platform-specific service handling
library;

import 'dart:io';

/// Represents the different states of Android AudioService integration
enum AndroidServiceState {
  /// Normal operation with full AudioService integration
  normal,
  
  /// AudioService is temporarily blocked due to foreground service issues
  serviceBlocked,
  
  /// Complete bypass mode - using just_audio without AudioService
  bypassMode,
  
  /// Failed state - unable to use either AudioService or bypass mode
  failed,
}

/// Represents the reason for entering bypass mode
enum BypassReason {
  foregroundServiceError,
  playbackStateError,
  mediaNotificationError,
  audioSessionError,
  userRequested,
  unknown,
}

/// Immutable configuration for Android AudioService behavior
class AndroidServiceConfig {
  final AndroidServiceState state;
  final BypassReason? bypassReason;
  final DateTime? stateChangedAt;
  final String? errorMessage;
  final int errorCount;
  
  const AndroidServiceConfig({
    required this.state,
    this.bypassReason,
    this.stateChangedAt,
    this.errorMessage,
    this.errorCount = 0,
  });
  
  /// Create initial normal state
  factory AndroidServiceConfig.normal() {
    return AndroidServiceConfig(
      state: AndroidServiceState.normal,
      stateChangedAt: DateTime.now(),
    );
  }
  
  /// Create bypass mode state
  factory AndroidServiceConfig.bypass(BypassReason reason, [String? error]) {
    return AndroidServiceConfig(
      state: AndroidServiceState.bypassMode,
      bypassReason: reason,
      errorMessage: error,
      stateChangedAt: DateTime.now(),
    );
  }
  
  /// Create service blocked state
  factory AndroidServiceConfig.blocked(String error, [int errorCount = 1]) {
    return AndroidServiceConfig(
      state: AndroidServiceState.serviceBlocked,
      errorMessage: error,
      errorCount: errorCount,
      stateChangedAt: DateTime.now(),
    );
  }
  
  /// Create failed state
  factory AndroidServiceConfig.failed(String error) {
    return AndroidServiceConfig(
      state: AndroidServiceState.failed,
      errorMessage: error,
      stateChangedAt: DateTime.now(),
    );
  }
  
  /// Create a copy with updated state
  AndroidServiceConfig copyWith({
    AndroidServiceState? state,
    BypassReason? bypassReason,
    DateTime? stateChangedAt,
    String? errorMessage,
    int? errorCount,
  }) {
    return AndroidServiceConfig(
      state: state ?? this.state,
      bypassReason: bypassReason ?? this.bypassReason,
      stateChangedAt: stateChangedAt ?? this.stateChangedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      errorCount: errorCount ?? this.errorCount,
    );
  }
  
  /// Whether AudioService should be bypassed
  bool get shouldBypass => state == AndroidServiceState.bypassMode || 
                          state == AndroidServiceState.failed;
  
  /// Whether AudioService is completely blocked
  bool get isBlocked => state == AndroidServiceState.serviceBlocked || 
                       state == AndroidServiceState.failed;
  
  /// Whether in normal operating mode
  bool get isNormal => state == AndroidServiceState.normal;
  
  /// Whether this is an error state
  bool get isErrorState => state == AndroidServiceState.serviceBlocked || 
                          state == AndroidServiceState.failed;
  
  /// Get a human-readable description of the current state
  String get description {
    switch (state) {
      case AndroidServiceState.normal:
        return 'Normal AudioService operation';
      case AndroidServiceState.serviceBlocked:
        return 'AudioService blocked: ${errorMessage ?? 'Unknown error'}';
      case AndroidServiceState.bypassMode:
        return 'Bypass mode (${bypassReason?.toString().split('.').last ?? 'unknown reason'})';
      case AndroidServiceState.failed:
        return 'Failed: ${errorMessage ?? 'Unknown error'}';
    }
  }
  
  @override
  String toString() {
    return 'AndroidServiceConfig(state: $state, reason: $bypassReason, errors: $errorCount)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AndroidServiceConfig &&
        other.state == state &&
        other.bypassReason == bypassReason &&
        other.errorMessage == errorMessage &&
        other.errorCount == errorCount;
  }
  
  @override
  int get hashCode {
    return state.hashCode ^ 
           bypassReason.hashCode ^ 
           errorMessage.hashCode ^ 
           errorCount.hashCode;
  }
}

/// Manager for Android AudioService state transitions
class AndroidServiceManager {
  AndroidServiceConfig _currentConfig;
  
  AndroidServiceManager() : _currentConfig = _getInitialConfig();
  
  /// Get the current immutable configuration
  AndroidServiceConfig get currentConfig => _currentConfig;
  
  /// Whether we're currently on Android
  bool get isAndroid => Platform.isAndroid;
  
  /// Get initial configuration based on platform
  static AndroidServiceConfig _getInitialConfig() {
    if (Platform.isAndroid) {
      return AndroidServiceConfig.normal();
    } else {
      // Non-Android platforms don't use AudioService
      return AndroidServiceConfig.bypass(BypassReason.userRequested, 'Non-Android platform');
    }
  }
  
  /// Attempt to transition to normal state
  AndroidServiceConfig transitionToNormal() {
    if (!isAndroid) {
      return _currentConfig; // No change for non-Android
    }
    
    _currentConfig = AndroidServiceConfig.normal();
    return _currentConfig;
  }
  
  /// Transition to bypass mode due to an error
  AndroidServiceConfig transitionToBypass(BypassReason reason, [String? errorMessage]) {
    _currentConfig = AndroidServiceConfig.bypass(reason, errorMessage);
    return _currentConfig;
  }
  
  /// Transition to blocked state due to service errors
  AndroidServiceConfig transitionToBlocked(String errorMessage) {
    final newErrorCount = _currentConfig.isErrorState ? _currentConfig.errorCount + 1 : 1;
    
    // If we've had too many errors, transition to bypass mode instead
    if (newErrorCount >= 3) {
      return transitionToBypass(BypassReason.foregroundServiceError, 
                               'Too many service errors ($newErrorCount)');
    }
    
    _currentConfig = AndroidServiceConfig.blocked(errorMessage, newErrorCount);
    return _currentConfig;
  }
  
  /// Transition to failed state
  AndroidServiceConfig transitionToFailed(String errorMessage) {
    _currentConfig = AndroidServiceConfig.failed(errorMessage);
    return _currentConfig;
  }
  
  /// Handle AudioService playback state update errors
  AndroidServiceConfig handlePlaybackStateError(dynamic error) {
    if (!isAndroid) return _currentConfig;
    
    final errorMessage = 'Playback state update failed: $error';
    
    // If already in bypass mode, stay there
    if (_currentConfig.shouldBypass) {
      return _currentConfig;
    }
    
    // For severe errors, go directly to bypass mode
    if (error.toString().contains('foreground service') || 
        error.toString().contains('notification') ||
        error.toString().contains('permission')) {
      return transitionToBypass(BypassReason.foregroundServiceError, errorMessage);
    }
    
    // For other errors, try blocked state first
    return transitionToBlocked(errorMessage);
  }
  
  /// Check if AudioService operations should be attempted
  bool shouldAttemptAudioService() {
    return isAndroid && _currentConfig.isNormal;
  }
  
  /// Check if we should skip AudioService operations entirely
  bool shouldSkipAudioService() {
    return !isAndroid || _currentConfig.shouldBypass;
  }
  
  /// Reset to normal state (for recovery attempts)
  AndroidServiceConfig reset() {
    if (isAndroid) {
      return transitionToNormal();
    }
    return _currentConfig;
  }
  
  /// Get diagnostic information
  Map<String, dynamic> getDiagnostics() {
    return {
      'platform': Platform.operatingSystem,
      'isAndroid': isAndroid,
      'currentState': _currentConfig.state.toString(),
      'bypassReason': _currentConfig.bypassReason?.toString(),
      'errorCount': _currentConfig.errorCount,
      'errorMessage': _currentConfig.errorMessage,
      'stateChangedAt': _currentConfig.stateChangedAt?.toIso8601String(),
      'shouldBypass': _currentConfig.shouldBypass,
      'isBlocked': _currentConfig.isBlocked,
      'description': _currentConfig.description,
    };
  }
}