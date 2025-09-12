import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Manages app lifecycle state and provides background awareness to audio components
class AudioLifecycleManager with WidgetsBindingObserver {
  // Current app lifecycle state
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  
  // Callback for state changes
  final Function(AppLifecycleState) _onStateChanged;
  
  AudioLifecycleManager(this._onStateChanged) {
    WidgetsBinding.instance.addObserver(this);
    if (kDebugMode) {
      print('AudioLifecycleManager initialized');
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    _onStateChanged(state);
    
    if (kDebugMode) {
      print('App lifecycle state changed to: $state');
    }
  }
  
  /// Check if the app is currently in background
  bool get isInBackground => 
      _lifecycleState == AppLifecycleState.paused || 
      _lifecycleState == AppLifecycleState.detached ||
      _lifecycleState == AppLifecycleState.hidden;
  
  /// Check if the app is currently in foreground
  bool get isInForeground => 
      _lifecycleState == AppLifecycleState.resumed;
  
  /// Get the current lifecycle state
  AppLifecycleState get currentState => _lifecycleState;
  
  /// Dispose resources
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (kDebugMode) {
      print('AudioLifecycleManager disposed');
    }
  }
}
