import 'package:flutter/foundation.dart';
import 'package:flutter_smart_watch/flutter_smart_watch.dart';
import '../models/jellyfin_models.dart';
import 'audio_service_integration.dart';
import 'dart:convert';

/// Service to handle communication with wearOS companion app
class WearOSService {
  static WearOSService? _instance;
  static WearOSService get instance => _instance ??= WearOSService._();
  WearOSService._();

  FlutterWearOsConnectivity? _wearOSConnectivity;
  bool _initialized = false;
  
  /// Initialize the wearOS service
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      _wearOSConnectivity = FlutterSmartWatch().wearOS;
      await _setupListeners();
      await _syncCurrentState();
      _initialized = true;
      
      if (kDebugMode) {
        print('WearOSService: Initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('WearOSService: Failed to initialize: $e');
      }
      rethrow;
    }
  }

  /// Check if the service is initialized
  bool get isInitialized => _initialized;

  /// Setup listeners for incoming messages from wearOS
  Future<void> _setupListeners() async {
    if (_wearOSConnectivity == null) return;

    // Listen for messages from wearOS companion app
    _wearOSConnectivity!.messageReceived.listen((message) async {
      if (kDebugMode) {
        print('WearOSService: Received message from wearOS: $message');
      }
      
      await _handleWearOSMessage(message);
    });

    // Listen for capability changes
    _wearOSConnectivity!.capabilityChanged.listen((capability) {
      if (kDebugMode) {
        print('WearOSService: Capability changed: $capability');
      }
    });
  }

  /// Handle incoming messages from wearOS
  Future<void> _handleWearOSMessage(Map<String, dynamic> message) async {
    try {
      final String? action = message['action'];
      if (action == null) return;

      final audioService = AudioServiceIntegration.instance;
      if (!audioService.isInitialized) return;

      switch (action) {
        case 'play':
          await audioService.play();
          break;
        case 'pause':
          await audioService.pause();
          break;
        case 'play_pause':
          await audioService.playPause();
          break;
        case 'next':
          await audioService.skipToNext();
          break;
        case 'previous':
          await audioService.skipToPrevious();
          break;
        case 'seek':
          final double? position = message['position']?.toDouble();
          if (position != null) {
            await audioService.seek(Duration(milliseconds: (position * 1000).round()));
          }
          break;
        case 'set_volume':
          final double? volume = message['volume']?.toDouble();
          if (volume != null && volume >= 0.0 && volume <= 1.0) {
            await audioService.setVolume(volume);
          }
          break;
        case 'request_state':
          await _syncCurrentState();
          break;
        default:
          if (kDebugMode) {
            print('WearOSService: Unknown action: $action');
          }
      }
    } catch (e) {
      if (kDebugMode) {
        print('WearOSService: Error handling message: $e');
      }
    }
  }

  /// Sync current playback state with wearOS
  Future<void> _syncCurrentState() async {
    if (_wearOSConnectivity == null || !_initialized) return;

    try {
      final audioService = AudioServiceIntegration.instance;
      if (!audioService.isInitialized) return;

      final Track? currentTrack = audioService.currentTrack;
      
      final Map<String, dynamic> state = {
        'type': 'state_update',
        'is_playing': audioService.isPlaying,
        'position': audioService.position?.inMilliseconds ?? 0,
        'duration': audioService.duration?.inMilliseconds ?? 0,
        'volume': audioService.volume ?? 1.0,
      };

      if (currentTrack != null) {
        state['current_track'] = {
          'id': currentTrack.id,
          'title': currentTrack.name,
          'artist': currentTrack.artistItems?.isNotEmpty == true 
              ? currentTrack.artistItems!.first.name 
              : 'Unknown Artist',
          'album': currentTrack.album,
          'image_url': currentTrack.imageUrl,
        };
      }

      await _wearOSConnectivity!.sendMessage(state);
      
      if (kDebugMode) {
        print('WearOSService: Synced state to wearOS');
      }
    } catch (e) {
      if (kDebugMode) {
        print('WearOSService: Error syncing state: $e');
      }
    }
  }

  /// Send playback state updates to wearOS
  Future<void> sendPlaybackStateUpdate({
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    double? volume,
  }) async {
    if (_wearOSConnectivity == null || !_initialized) return;

    try {
      final Map<String, dynamic> update = {
        'type': 'playback_update',
      };

      if (isPlaying != null) update['is_playing'] = isPlaying;
      if (position != null) update['position'] = position.inMilliseconds;
      if (duration != null) update['duration'] = duration.inMilliseconds;
      if (volume != null) update['volume'] = volume;

      await _wearOSConnectivity!.sendMessage(update);
    } catch (e) {
      if (kDebugMode) {
        print('WearOSService: Error sending playback state update: $e');
      }
    }
  }

  /// Send track change update to wearOS
  Future<void> sendTrackUpdate(Track? track) async {
    if (_wearOSConnectivity == null || !_initialized) return;

    try {
      final Map<String, dynamic> update = {
        'type': 'track_update',
      };

      if (track != null) {
        update['track'] = {
          'id': track.id,
          'title': track.name,
          'artist': track.artistItems?.isNotEmpty == true 
              ? track.artistItems!.first.name 
              : 'Unknown Artist',
          'album': track.album,
          'image_url': track.imageUrl,
        };
      } else {
        update['track'] = null;
      }

      await _wearOSConnectivity!.sendMessage(update);
    } catch (e) {
      if (kDebugMode) {
        print('WearOSService: Error sending track update: $e');
      }
    }
  }

  /// Send playlist/queue update to wearOS
  Future<void> sendQueueUpdate(List<Track> queue, int currentIndex) async {
    if (_wearOSConnectivity == null || !_initialized) return;

    try {
      final List<Map<String, dynamic>> queueData = queue.map((track) => {
        'id': track.id,
        'title': track.name,
        'artist': track.artistItems?.isNotEmpty == true 
            ? track.artistItems!.first.name 
            : 'Unknown Artist',
        'album': track.album,
        'image_url': track.imageUrl,
      }).toList();

      final Map<String, dynamic> update = {
        'type': 'queue_update',
        'queue': queueData,
        'current_index': currentIndex,
      };

      await _wearOSConnectivity!.sendMessage(update);
    } catch (e) {
      if (kDebugMode) {
        print('WearOSService: Error sending queue update: $e');
      }
    }
  }

  /// Check if wearOS device is reachable
  Future<bool> isWearOSReachable() async {
    if (_wearOSConnectivity == null || !_initialized) return false;
    
    try {
      return await _wearOSConnectivity!.getReachableDevices().then((devices) => devices.isNotEmpty);
    } catch (e) {
      if (kDebugMode) {
        print('WearOSService: Error checking reachability: $e');
      }
      return false;
    }
  }

  /// Get connected wearOS devices
  Future<List<Map<String, dynamic>>> getConnectedDevices() async {
    if (_wearOSConnectivity == null || !_initialized) return [];
    
    try {
      return await _wearOSConnectivity!.getReachableDevices();
    } catch (e) {
      if (kDebugMode) {
        print('WearOSService: Error getting connected devices: $e');
      }
      return [];
    }
  }

  /// Dispose the service
  void dispose() {
    _initialized = false;
    _wearOSConnectivity = null;
    _instance = null;
  }
}