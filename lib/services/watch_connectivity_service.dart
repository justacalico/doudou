import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_smart_watch/flutter_smart_watch.dart';
import '../models/jellyfin_models.dart';
import 'logging_service.dart';

class WatchConnectivityService {
  static final WatchConnectivityService _instance = WatchConnectivityService._internal();
  factory WatchConnectivityService() => _instance;
  WatchConnectivityService._internal();

  FlutterWatchOsConnectivity? _watchOsConnectivity;
  bool _isSupported = false;
  bool _isReachable = false;
  
  final LoggingService _logger = LoggingService();
  
  final _reachabilityController = StreamController<bool>.broadcast();
  Stream<bool> get reachabilityStream => _reachabilityController.stream;
  
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  bool get isSupported => _isSupported;
  bool get isReachable => _isReachable;

  Future<void> initialize() async {
    if (!Platform.isIOS) {
      _logger.log('INFO', 'Watch connectivity is only supported on iOS', 'WatchConnectivity');
      return;
    }

    try {
      _watchOsConnectivity = FlutterSmartWatch().watchOS;
      
      // Check if Watch Connectivity is supported
      final supported = await _watchOsConnectivity?.isSupported;
      _isSupported = supported == true;
      
      if (!_isSupported) {
        _logger.log('WARNING', 'Apple Watch connectivity is not supported on this device', 'WatchConnectivity');
        return;
      }

      // Initialize session
      await _watchOsConnectivity?.activateSession();
      
      // Listen to reachability changes
      _watchOsConnectivity?.reachabilityChanged.listen((reachable) {
        _isReachable = reachable;
        _reachabilityController.add(reachable);
        _logger.log('INFO', 'Apple Watch reachability changed: $reachable', 'WatchConnectivity');
      });

      // Listen to messages from watch
      _watchOsConnectivity?.messageReceived.listen((message) {
        _handleMessageFromWatch(message);
      });

      _logger.log('INFO', 'Watch connectivity service initialized successfully', 'WatchConnectivity');
    } catch (e) {
      _logger.log('ERROR', 'Failed to initialize watch connectivity: $e', 'WatchConnectivity');
    }
  }

  void _handleMessageFromWatch(dynamic message) {
    _logger.log('INFO', 'Received message from Apple Watch: $message', 'WatchConnectivity');
    
    try {
      Map<String, dynamic> messageData;
      
      // Handle different message types from flutter_smart_watch
      if (message is Map<String, dynamic>) {
        messageData = message;
      } else {
        // Try to extract data from WatchOSMessage object
        messageData = message?.data ?? {};
      }
      
      final action = messageData['action'] as String?;
      
      switch (action) {
        case 'play':
          _messageController.add({'type': 'playback_control', 'action': 'play'});
          break;
        case 'pause':
          _messageController.add({'type': 'playback_control', 'action': 'pause'});
          break;
        case 'next':
          _messageController.add({'type': 'playbook_control', 'action': 'next'});
          break;
        case 'previous':
          _messageController.add({'type': 'playback_control', 'action': 'previous'});
          break;
        case 'requestCurrentSong':
          _messageController.add({'type': 'request', 'data': 'current_song'});
          break;
        case 'requestPlaylists':
          _messageController.add({'type': 'request', 'data': 'playlists'});
          break;
        default:
          _logger.log('WARNING', 'Unknown action received from Apple Watch: $action', 'WatchConnectivity');
      }
    } catch (e) {
      _logger.log('ERROR', 'Error handling message from Apple Watch: $e', 'WatchConnectivity');
    }
  }

  Future<void> sendCurrentTrack(Track? track) async {
    if (!_isSupported || !_isReachable) return;

    try {
      final trackData = track != null ? {
        'id': track.id,
        'title': track.name,
        'artist': track.artistName,
        'album': track.albumName,
        'duration': track.duration != null ? (track.duration! / 1000).round() : null, // Convert ms to seconds
        'artwork_url': track.imageUrl,
      } : null;

      await _watchOsConnectivity?.sendMessage({
        'type': 'current_track',
        'data': trackData,
      });

      _logger.log('INFO', 'Sent current track to Apple Watch: ${track?.name ?? 'None'}', 'WatchConnectivity');
    } catch (e) {
      _logger.log('ERROR', 'Failed to send current track to Apple Watch: $e', 'WatchConnectivity');
    }
  }

  Future<void> sendPlaybackState({
    required bool isPlaying,
    Duration? position,
    Duration? duration,
  }) async {
    if (!_isSupported || !_isReachable) return;

    try {
      await _watchOsConnectivity?.sendMessage({
        'type': 'playback_state',
        'data': {
          'is_playing': isPlaying,
          'position': position?.inSeconds,
          'duration': duration?.inSeconds,
        },
      });

      AppLogger.info('Sent playback state to Apple Watch: playing=$isPlaying');
    } catch (e) {
      AppLogger.error('Failed to send playback state to Apple Watch: $e');
    }
  }

  Future<void> sendPlaylists(List<Playlist> playlists) async {
    if (!_isSupported || !_isReachable) return;

    try {
      final playlistsData = playlists.map((playlist) => {
        'id': playlist.id,
        'name': playlist.name,
        'song_count': playlist.songs.length,
      }).toList();

      await _watchOsConnectivity?.sendMessage({
        'type': 'playlists',
        'data': playlistsData,
      });

      AppLogger.info('Sent ${playlists.length} playlists to Apple Watch');
    } catch (e) {
      AppLogger.error('Failed to send playlists to Apple Watch: $e');
    }
  }

  Future<void> sendVolumeLevel(double volume) async {
    if (!_isSupported || !_isReachable) return;

    try {
      await _watchOsConnectivity?.sendMessage({
        'type': 'volume',
        'data': {
          'level': volume,
        },
      });
    } catch (e) {
      AppLogger.error('Failed to send volume to Apple Watch: $e');
    }
  }

  void dispose() {
    _reachabilityController.close();
    _messageController.close();
  }
}