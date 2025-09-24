import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:touch_bar/touch_bar.dart';
import '../models/jellyfin_models.dart';

/// Service for managing macOS Touch Bar integration
/// Only active on macOS devices with Touch Bar support
class TouchBarService {
  static bool _isInitialized = false;
  static VoidCallback? _onPlayPause;
  static VoidCallback? _onPrevious;
  static VoidCallback? _onNext;
  static Function(Duration)? _onSeek;
  static VoidCallback? _onFavorite;

  /// Initialize Touch Bar support (macOS only)
  static Future<void> initialize() async {
    if (!Platform.isMacOS) return;
    
    try {
      await TouchBar.setTouchBar(_createTouchBar());
      _isInitialized = true;
      
      if (kDebugMode) {
        print('Touch Bar service initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Touch Bar initialization failed: $e');
      }
    }
  }

  /// Create the TouchBar layout
  static TouchBarItem _createTouchBar() {
    return TouchBarGroup(
      identifier: 'media-controls',
      items: [
        TouchBarButton(
          identifier: 'previous',
          text: '⏮',
          onPressed: () => _onPrevious?.call(),
        ),
        TouchBarButton(
          identifier: 'play-pause',
          text: '⏸',
          onPressed: () => _onPlayPause?.call(),
        ),
        TouchBarButton(
          identifier: 'next',
          text: '⏭',
          onPressed: () => _onNext?.call(),
        ),
        TouchBarSpace.flexible(),
        TouchBarButton(
          identifier: 'favorite',
          text: '♡',
          onPressed: () => _onFavorite?.call(),
        ),
      ],
    );
  }

  /// Set callback functions for Touch Bar button presses
  static void setCallbacks({
    VoidCallback? onPlayPause,
    VoidCallback? onPrevious,
    VoidCallback? onNext,
    Function(Duration)? onSeek,
    VoidCallback? onFavorite,
  }) {
    _onPlayPause = onPlayPause;
    _onPrevious = onPrevious;
    _onNext = onNext;
    _onSeek = onSeek;
    _onFavorite = onFavorite;
    
    if (kDebugMode) {
      print('Touch Bar callbacks set successfully');
    }
  }

  /// Update the now playing information on Touch Bar
  static Future<void> updateNowPlaying(Track? track) async {
    if (!Platform.isMacOS || !_isInitialized) return;
    
    try {
      if (track != null) {
        // Stub implementation - would call native method
        if (kDebugMode) {
          print('Would update Touch Bar with: ${track.name} - ${track.artistName ?? 'Unknown Artist'}');
        }
      } else {
        if (kDebugMode) {
          print('Would clear Touch Bar now playing');
        }
      }
      
      if (kDebugMode) {
        print('Touch Bar updated with track: ${track?.name ?? 'No track'}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to update Touch Bar now playing: $e');
      }
    }
  }

  /// Update playback controls state
  static Future<void> updatePlaybackState({
    required bool isPlaying,
    required Duration position,
    required Duration duration,
    bool? isFavorite,
  }) async {
    if (!Platform.isMacOS || !_isInitialized) return;
    
    try {
      // Stub implementation - would call native method
      if (kDebugMode) {
        print('Would update Touch Bar - Playing: $isPlaying, Position: ${_formatDuration(position)}/${_formatDuration(duration)}, Favorite: ${isFavorite ?? false}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to update Touch Bar playback state: $e');
      }
    }
  }

  /// Enable or disable Touch Bar controls
  static Future<void> setControlsEnabled(bool enabled) async {
    if (!Platform.isMacOS || !_isInitialized) return;
    
    try {
      // Stub implementation
      if (kDebugMode) {
        print('Would ${enabled ? 'enable' : 'disable'} Touch Bar controls');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to set Touch Bar controls enabled: $e');
      }
    }
  }

  /// Format duration for display
  static String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  /// Clean up Touch Bar resources
  static Future<void> dispose() async {
    if (!Platform.isMacOS || !_isInitialized) return;
    
    try {
      // Stub implementation
      _isInitialized = false;
      
      if (kDebugMode) {
        print('Touch Bar service disposed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to dispose Touch Bar: $e');
      }
    }
  }
}