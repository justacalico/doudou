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
  static VoidCallback? _onFavorite;
  static TouchBar? _touchBar;
  static String? _currentLyricsText;

  /// Initialize Touch Bar support (macOS only)
  static Future<void> initialize() async {
    if (!Platform.isMacOS) return;
    
    try {
      _touchBar = _createTouchBar();
      await setTouchBar(_touchBar!);
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
  static TouchBar _createTouchBar() {
    List<dynamic> children = [
      TouchBarButton(
        label: '⏮',
        onClick: () => _onPrevious?.call(),
      ),
      TouchBarButton(
        label: '⏸',
        onClick: () => _onPlayPause?.call(),
      ),
      TouchBarButton(
        label: '⏭',
        onClick: () => _onNext?.call(),
      ),
    ];
    
    // Add lyrics display if available
    if (_currentLyricsText != null && _currentLyricsText!.isNotEmpty) {
      children.addAll([
        TouchBarSpace.flexible(),
        TouchBarLabel(text: _currentLyricsText!),
        TouchBarSpace.flexible(),
      ]);
    } else {
      children.add(TouchBarSpace.flexible());
    }
    
    children.add(TouchBarButton(
      label: '♡',
      onClick: () => _onFavorite?.call(),
    ));

    return TouchBar(children: children);
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
    _onFavorite = onFavorite;
    
    // Recreate TouchBar with updated callbacks
    if (_isInitialized) {
      _touchBar = _createTouchBar();
      setTouchBar(_touchBar!);
    }
    
    if (kDebugMode) {
      print('Touch Bar callbacks set successfully');
    }
  }

  /// Update the now playing information on Touch Bar
  static Future<void> updateNowPlaying(Track? track) async {
    if (!Platform.isMacOS || !_isInitialized) return;
    
    try {
      // Update TouchBar with current track info (could add a label with track name)
      if (track != null) {
        if (kDebugMode) {
          print('Touch Bar updated with track: ${track.name} - ${track.artistName ?? 'Unknown Artist'}');
        }
      } else {
        if (kDebugMode) {
          print('Touch Bar cleared now playing');
        }
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
      // Update the play/pause button icon
      final updatedTouchBar = TouchBar(
        children: [
          TouchBarButton(
            label: '⏮',
            onClick: () => _onPrevious?.call(),
          ),
          TouchBarButton(
            label: isPlaying ? '⏸' : '▶',
            onClick: () => _onPlayPause?.call(),
          ),
          TouchBarButton(
            label: '⏭',
            onClick: () => _onNext?.call(),
          ),
          TouchBarSpace.flexible(),
          TouchBarButton(
            label: (isFavorite ?? false) ? '♥' : '♡',
            onClick: () => _onFavorite?.call(),
          ),
        ],
      );
      
      await setTouchBar(updatedTouchBar);
      _touchBar = updatedTouchBar;
      
      if (kDebugMode) {
        print('Touch Bar updated - Playing: $isPlaying, Position: ${_formatDuration(position)}/${_formatDuration(duration)}, Favorite: ${isFavorite ?? false}');
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
      if (enabled && _touchBar != null) {
        await setTouchBar(_touchBar!);
      } else {
        // Clear the TouchBar by setting an empty one
        await setTouchBar(TouchBar(children: []));
      }
      
      if (kDebugMode) {
        print('Touch Bar controls ${enabled ? 'enabled' : 'disabled'}');
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
      // Clear the TouchBar
      await setTouchBar(TouchBar(children: []));
      _touchBar = null;
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