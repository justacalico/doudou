import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_smart_watch/flutter_smart_watch.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import 'logging_service.dart';

class WatchConnectivityService {
  static final WatchConnectivityService _instance = WatchConnectivityService._internal();
  factory WatchConnectivityService() => _instance;
  WatchConnectivityService._internal();

  FlutterWatchOsConnectivity? _watchOsConnectivity;
  bool _isSupported = false;
  bool _isReachable = false;
  
  final _reachabilityController = StreamController<bool>.broadcast();
  Stream<bool> get reachabilityStream => _reachabilityController.stream;
  
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  bool get isSupported => _isSupported;
  bool get isReachable => _isReachable;

  Future<void> initialize() async {
    if (!Platform.isIOS) {
      AppLogger.info('Watch connectivity is only supported on iOS');
      return;
    }

    try {
      _watchOsConnectivity = FlutterSmartWatch().watchOS;
      
      // Check if Watch Connectivity is supported
      _isSupported = await _watchOsConnectivity?.isSupported ?? false;
      
      if (!_isSupported) {
        AppLogger.warning('Apple Watch connectivity is not supported on this device');
        return;
      }

      // Check initial reachability
      _isReachable = await _watchOsConnectivity?.isReachable ?? false;
      
      // Listen to reachability changes
      _watchOsConnectivity?.reachabilityStream.listen((reachable) {
        _isReachable = reachable;
        _reachabilityController.add(reachable);
        AppLogger.info('Apple Watch reachability changed: $reachable');
      });

      // Listen to messages from watch
      _watchOsConnectivity?.messageStream.listen((message) {
        _handleMessageFromWatch(message);
      });

      AppLogger.info('Watch connectivity service initialized successfully');
    } catch (e) {
      AppLogger.error('Failed to initialize watch connectivity: $e');
    }
  }

  void _handleMessageFromWatch(Map<String, dynamic> message) {
    AppLogger.info('Received message from Apple Watch: $message');
    
    try {
      final action = message['action'] as String?;
      
      switch (action) {
        case 'play':
          _messageController.add({'type': 'playback_control', 'action': 'play'});
          break;
        case 'pause':
          _messageController.add({'type': 'playback_control', 'action': 'pause'});
          break;
        case 'next':
          _messageController.add({'type': 'playback_control', 'action': 'next'});
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
          AppLogger.warning('Unknown action received from Apple Watch: $action');
      }
    } catch (e) {
      AppLogger.error('Error handling message from Apple Watch: $e');
    }
  }

  Future<void> sendCurrentSong(Song? song) async {
    if (!_isSupported || !_isReachable) return;

    try {
      final songData = song != null ? {
        'id': song.id,
        'title': song.title,
        'artist': song.artist,
        'album': song.album,
        'duration': song.duration?.inSeconds,
        'artwork_url': song.artworkUrl,
      } : null;

      await _watchOsConnectivity?.sendMessage({
        'type': 'current_song',
        'data': songData,
      });

      AppLogger.info('Sent current song to Apple Watch: ${song?.title ?? 'None'}');
    } catch (e) {
      AppLogger.error('Failed to send current song to Apple Watch: $e');
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