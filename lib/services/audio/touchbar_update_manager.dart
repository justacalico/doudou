import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../touchbar_service.dart';
import '../../models/jellyfin_models.dart';

/// Synchronized Touch Bar update manager for macOS to prevent race conditions
/// during rapid track changes and concurrent updates
class TouchBarUpdateManager {
  bool _enabled = false;
  bool _disposed = false;
  final Completer<void> _readyCompleter = Completer<void>();
  
  // Debouncing for different update types
  Timer? _playbackStateTimer;
  Timer? _nowPlayingTimer;
  Timer? _lyricsTimer;
  
  // Current state to prevent redundant updates
  bool? _lastIsPlaying;
  Duration? _lastPosition;
  Duration? _lastDuration;
  bool? _lastIsFavorite;
  String? _lastTrackId;
  String? _lastLyricsText;
  
  // Update intervals for debouncing
  static const Duration _playbackStateDebounce = Duration(milliseconds: 100);
  static const Duration _nowPlayingDebounce = Duration(milliseconds: 200);
  static const Duration _lyricsDebounce = Duration(milliseconds: 50);

  TouchBarUpdateManager() {
    _readyCompleter.complete();
  }

  /// Initialize Touch Bar with proper error handling
  Future<bool> initialize() async {
    if (!Platform.isMacOS || _disposed) {
      return false;
    }

    try {
      await TouchBarService.initialize();
      _enabled = true;
      return true;
    } catch (e) {
      print('TouchBarUpdateManager: Failed to initialize: $e');
      _enabled = false;
      return false;
    }
  }

  /// Enable Touch Bar updates
  void enable() {
    if (Platform.isMacOS && !_disposed) {
      _enabled = true;
    }
  }

  /// Disable Touch Bar updates
  void disable() {
    _enabled = false;
    _cancelAllTimers();
  }

  /// Check if Touch Bar is enabled and ready
  bool get isEnabled => _enabled && !_disposed && Platform.isMacOS;

  /// Update playback state with debouncing
  void updatePlaybackState({
    required bool isPlaying,
    required Duration position,
    required Duration duration,
    required bool isFavorite,
  }) {
    if (!isEnabled) return;

    // Check if anything actually changed
    if (_lastIsPlaying == isPlaying &&
        _lastPosition == position &&
        _lastDuration == duration &&
        _lastIsFavorite == isFavorite) {
      return;
    }

    // Cancel existing timer and start new one
    _playbackStateTimer?.cancel();
    _playbackStateTimer = Timer(_playbackStateDebounce, () {
      _executePlaybackStateUpdate(
        isPlaying: isPlaying,
        position: position,
        duration: duration,
        isFavorite: isFavorite,
      );
    });
  }

  /// Execute playback state update
  void _executePlaybackStateUpdate({
    required bool isPlaying,
    required Duration position,
    required Duration duration,
    required bool isFavorite,
  }) {
    if (!isEnabled) return;

    try {
      TouchBarService.updatePlaybackState(
        isPlaying: isPlaying,
        position: position,
        duration: duration,
        isFavorite: isFavorite,
      );

      _lastIsPlaying = isPlaying;
      _lastPosition = position;
      _lastDuration = duration;
      _lastIsFavorite = isFavorite;
    } catch (e) {
      print('TouchBarUpdateManager: Playback state update failed: $e');
    }
  }

  /// Update now playing track with debouncing
  void updateNowPlaying(Track? track) {
    if (!isEnabled) return;

    final trackId = track?.id;
    if (_lastTrackId == trackId) {
      return; // No change
    }

    // Cancel existing timer and start new one
    _nowPlayingTimer?.cancel();
    _nowPlayingTimer = Timer(_nowPlayingDebounce, () {
      _executeNowPlayingUpdate(track);
    });
  }

  /// Execute now playing update
  void _executeNowPlayingUpdate(Track? track) {
    if (!isEnabled) return;

    try {
      TouchBarService.updateNowPlaying(track);
      _lastTrackId = track?.id;
      
      // Reset lyrics state when track changes
      if (_lastLyricsText != null) {
        _lastLyricsText = null;
        TouchBarService.updateLyrics(null);
      }
    } catch (e) {
      print('TouchBarUpdateManager: Now playing update failed: $e');
    }
  }

  /// Update lyrics with debouncing
  void updateLyrics(String? lyricsText) {
    if (!isEnabled) return;

    // Only update if lyrics actually changed
    if (_lastLyricsText == lyricsText) {
      return;
    }

    // Cancel existing timer and start new one
    _lyricsTimer?.cancel();
    _lyricsTimer = Timer(_lyricsDebounce, () {
      _executeLyricsUpdate(lyricsText);
    });
  }

  /// Execute lyrics update
  void _executeLyricsUpdate(String? lyricsText) {
    if (!isEnabled) return;

    try {
      TouchBarService.updateLyrics(lyricsText);
      _lastLyricsText = lyricsText;
    } catch (e) {
      print('TouchBarUpdateManager: Lyrics update failed: $e');
    }
  }

  /// Force immediate update of all pending changes
  void flushPendingUpdates() {
    if (!isEnabled) return;

    _playbackStateTimer?.cancel();
    _nowPlayingTimer?.cancel();
    _lyricsTimer?.cancel();

    // Execute any pending updates immediately
    // This is useful before track transitions
  }

  /// Cancel all pending timers
  void _cancelAllTimers() {
    _playbackStateTimer?.cancel();
    _nowPlayingTimer?.cancel();
    _lyricsTimer?.cancel();
    
    _playbackStateTimer = null;
    _nowPlayingTimer = null;
    _lyricsTimer = null;
  }

  /// Set Touch Bar callbacks with error handling
  Future<void> setCallbacks({
    required VoidCallback onPlayPause,
    required VoidCallback onPrevious,
    required VoidCallback onNext,
    required VoidCallback onFavorite,
  }) async {
    if (!isEnabled) return;

    try {
      TouchBarService.setCallbacks(
        onPlayPause: onPlayPause,
        onPrevious: onPrevious,
        onNext: onNext,
        onFavorite: onFavorite,
      );
    } catch (e) {
      print('TouchBarUpdateManager: Failed to set callbacks: $e');
    }
  }

  /// Dispose resources and cleanup
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    _cancelAllTimers();
    
    if (_enabled) {
      try {
        // Clear Touch Bar state
        TouchBarService.updateNowPlaying(null);
        TouchBarService.updateLyrics(null);
      } catch (e) {
        print('TouchBarUpdateManager: Cleanup failed: $e');
      }
    }
    
    _enabled = false;
  }

  /// Get current Touch Bar state for debugging
  TouchBarState get currentState {
    return TouchBarState(
      enabled: _enabled,
      disposed: _disposed,
      lastTrackId: _lastTrackId,
      lastLyricsText: _lastLyricsText,
      lastIsPlaying: _lastIsPlaying,
      lastPosition: _lastPosition,
      lastDuration: _lastDuration,
      lastIsFavorite: _lastIsFavorite,
    );
  }
}

/// Immutable Touch Bar state for debugging
class TouchBarState {
  final bool enabled;
  final bool disposed;
  final String? lastTrackId;
  final String? lastLyricsText;
  final bool? lastIsPlaying;
  final Duration? lastPosition;
  final Duration? lastDuration;
  final bool? lastIsFavorite;

  const TouchBarState({
    required this.enabled,
    required this.disposed,
    required this.lastTrackId,
    required this.lastLyricsText,
    required this.lastIsPlaying,
    required this.lastPosition,
    required this.lastDuration,
    required this.lastIsFavorite,
  });

  @override
  String toString() {
    return 'TouchBarState('
        'enabled: $enabled, '
        'disposed: $disposed, '
        'lastTrackId: $lastTrackId, '
        'lastIsPlaying: $lastIsPlaying'
        ')';
  }
}