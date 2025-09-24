import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/jellyfin_models.dart';

/// Service for managing macOS Touch Bar integration
/// Only active on macOS devices with Touch Bar support
class TouchBarService {
  static const _channel = MethodChannel('com.openlyst.doudou/touchbar');
  static bool _isInitialized = false;
  
  // Callback functions for Touch Bar interactions
  static VoidCallback? _onPlayPausePressed;
  static VoidCallback? _onPreviousPressed;
  static VoidCallback? _onNextPressed;
  static Function(Duration)? _onSeekPressed;
  static VoidCallback? _onFavoritePressed;

  /// Initialize Touch Bar support (macOS only)
  static Future<void> initialize() async {
    if (!Platform.isMacOS) return;
    
    try {
      await _channel.invokeMethod('initialize');
      _isInitialized = true;
      
      // Set up method call handler for Touch Bar button presses
      _channel.setMethodCallHandler(_handleMethodCall);
      
      if (kDebugMode) {
        print('Touch Bar initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Touch Bar initialization failed: $e');
      }
    }
  }

  /// Handle method calls from native Touch Bar
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (kDebugMode) {
      print('Touch Bar method call: ${call.method}');
    }
    
    switch (call.method) {
      case 'playPause':
        _onPlayPausePressed?.call();
        break;
      case 'previousTrack':
        _onPreviousPressed?.call();
        break;
      case 'nextTrack':
        _onNextPressed?.call();
        break;
      case 'seekTo':
        final position = call.arguments['position'] as double;
        _onSeekPressed?.call(Duration(milliseconds: (position * 1000).round()));
        break;
      case 'toggleFavorite':
        _onFavoritePressed?.call();
        break;
      default:
        if (kDebugMode) {
          print('Unhandled Touch Bar method: ${call.method}');
        }
    }
  }

  /// Set callback functions for Touch Bar button presses
  static void setCallbacks({
    VoidCallback? onPlayPause,
    VoidCallback? onPrevious,
    VoidCallback? onNext,
    Function(Duration)? onSeek,
    VoidCallback? onFavorite,
  }) {
    _onPlayPausePressed = onPlayPause;
    _onPreviousPressed = onPrevious;
    _onNextPressed = onNext;
    _onSeekPressed = onSeek;
    _onFavoritePressed = onFavorite;
  }

  /// Update the now playing information on Touch Bar
  static Future<void> updateNowPlaying(Track? track) async {
    if (!Platform.isMacOS || !_isInitialized) return;
    
    try {
      if (track != null) {
        await _channel.invokeMethod('updateNowPlaying', {
          'title': track.name,
          'artist': track.artistName ?? 'Unknown Artist',
          'album': track.albumName ?? 'Unknown Album',
          'duration': track.duration?.inMilliseconds.toDouble() ?? 0.0,
          'trackId': track.id,
        });
      } else {
        await _channel.invokeMethod('clearNowPlaying');
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
      await _channel.invokeMethod('updatePlaybackState', {
        'isPlaying': isPlaying,
        'position': position.inMilliseconds.toDouble(),
        'duration': duration.inMilliseconds.toDouble(),
        'isFavorite': isFavorite ?? false,
      });
      
      if (kDebugMode) {
        print('Touch Bar updated - Playing: $isPlaying, Position: ${_formatDuration(position)}');
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
      await _channel.invokeMethod('setControlsEnabled', {'enabled': enabled});
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
      await _channel.invokeMethod('dispose');
      _isInitialized = false;
      
      if (kDebugMode) {
        print('Touch Bar disposed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to dispose Touch Bar: $e');
      }
    }
  }
}