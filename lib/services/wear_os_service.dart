import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../providers/app_state.dart';
import '../models/jellyfin_models.dart';

class WearOSService {
  static const MethodChannel _channel = MethodChannel('doudou/wear_os');
  static WearOSService? _instance;
  static WearOSService get instance => _instance ??= WearOSService._();
  
  WearOSService._();
  
  bool _isInitialized = false;
  AppState? _appState;
  Track? _currentTrack;
  bool _isPlaying = false;

  /// Initialize the Wear OS service
  Future<void> initialize(AppState appState) async {
    if (_isInitialized || !Platform.isAndroid) return;
    
    _appState = appState;
    
    try {
      // Set up method call handler for messages from Wear OS
      _channel.setMethodCallHandler(_handleMethodCall);
      
      // Listen to current track changes
      _appState!.currentTrackStream?.listen((track) {
        _currentTrack = track;
        _sendPlaybackState();
      });
      
      // Listen to playback state changes
      _appState!.playerStateStream?.listen((playerState) {
        _isPlaying = playerState.playing;
        _sendPlaybackState();
      });
      
      // Initialize the native Android service
      await _channel.invokeMethod('initialize');
      
      _isInitialized = true;
      
      if (kDebugMode) {
        print('WearOSService initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to initialize WearOSService: $e');
      }
    }
  }

  /// Handle method calls from the native Android code
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onWearOSConnected':
        _onWearOSConnected();
        break;
      case 'onWearOSDisconnected':
        _onWearOSDisconnected();
        break;
      case 'onMediaControlCommand':
        final command = call.arguments as String;
        _handleMediaControlCommand(command);
        break;
      case 'requestPlaybackState':
        return await _getPlaybackState();
      default:
        if (kDebugMode) {
          print('Unknown method call: ${call.method}');
        }
    }
    return null;
  }

  /// Called when Wear OS device connects
  void _onWearOSConnected() {
    if (kDebugMode) {
      print('Wear OS device connected');
    }
    // Send current playback state to Wear OS
    _sendPlaybackState();
  }

  /// Called when Wear OS device disconnects
  void _onWearOSDisconnected() {
    if (kDebugMode) {
      print('Wear OS device disconnected');
    }
  }

  /// Handle media control commands from Wear OS
  void _handleMediaControlCommand(String command) {
    if (_appState == null) return;

    switch (command) {
      case 'play':
        _appState!.audioHandler?.play();
        break;
      case 'pause':
        _appState!.audioHandler?.pause();
        break;
      case 'next':
        _appState!.skipToNext();
        break;
      case 'previous':
        _appState!.skipToPrevious();
        break;
      default:
        if (kDebugMode) {
          print('Unknown media control command: $command');
        }
    }
  }

  /// Get current playback state
  Future<Map<String, dynamic>> _getPlaybackState() async {
    if (_appState == null || _currentTrack == null) {
      return {
        'song': 'No song playing',
        'artist': '',
        'isPlaying': false,
        'position': 0,
        'duration': 0,
      };
    }

    return {
      'song': _currentTrack?.name ?? 'Unknown',
      'artist': _currentTrack?.artistName ?? '',
      'isPlaying': _isPlaying,
      'position': 0, // Position would need to be tracked separately
      'duration': _currentTrack?.duration ?? 0,
    };
  }

  /// Send playback state to Wear OS
  Future<void> _sendPlaybackState() async {
    if (!_isInitialized || _appState == null) return;

    try {
      final playbackState = await _getPlaybackState();
      await _channel.invokeMethod('sendPlaybackState', playbackState);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to send playback state to Wear OS: $e');
      }
    }
  }

  /// Send playback update to Wear OS (call this when playback state changes)
  Future<void> notifyPlaybackStateChanged() async {
    await _sendPlaybackState();
  }

  /// Send a message to Wear OS
  Future<void> sendMessage(String path, String message) async {
    if (!_isInitialized) return;

    try {
      await _channel.invokeMethod('sendMessage', {
        'path': path,
        'message': message,
      });
    } catch (e) {
      if (kDebugMode) {
        print('Failed to send message to Wear OS: $e');
      }
    }
  }

  /// Check if Wear OS is connected
  Future<bool> isWearOSConnected() async {
    if (!_isInitialized) return false;

    try {
      final result = await _channel.invokeMethod('isWearOSConnected');
      return result as bool;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to check Wear OS connection: $e');
      }
      return false;
    }
  }

  /// Dispose the service
  void dispose() {
    if (_isInitialized) {
      _channel.setMethodCallHandler(null);
      _isInitialized = false;
    }
  }
}