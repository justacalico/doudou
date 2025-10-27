import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import '../jellyfin_service.dart';
import '../media_service_manager.dart';
import '../../models/jellyfin_models.dart';

/// A simple, reliable audio handler that focuses on basic functionality
/// without complex gapless playback or concatenation issues.
class SimpleAudioHandler extends BaseAudioHandler {
  final JellyfinService _jellyfinService;
  final MediaServiceManager? _mediaServiceManager;
  
  // Core audio player
  late final AudioPlayer _player;
  
  // Simple state management
  List<Track> _playlist = [];
  int _currentIndex = 0;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  
  // Stream subscriptions
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  
  SimpleAudioHandler(this._jellyfinService, [this._mediaServiceManager]) {
    _player = AudioPlayer();
    _initializePlayer();
    
    if (kDebugMode) {
      print('SimpleAudioHandler initialized');
    }
  }

  void _initializePlayer() {
    // Listen to player state changes
    _playerStateSubscription = _player.playerStateStream.listen((playerState) {
      _isPlaying = playerState.playing;
      
      final processingState = switch (playerState.processingState) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      };
      
      // Update playback state
      playbackState.add(PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          _isPlaying ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: processingState,
        playing: _isPlaying,
        updatePosition: _position,
        queueIndex: _currentIndex,
      ));
      
      // Update media item
      if (_currentIndex < _playlist.length) {
        _updateMediaItem();
      }
      
      // Handle track completion
      if (processingState == AudioProcessingState.completed) {
        _handleTrackCompleted();
      }
      
      if (kDebugMode) {
        print('Player state: playing=$_isPlaying, processing=${processingState.name}, index=$_currentIndex');
      }
    });
    
    // Listen to position changes
    _positionSubscription = _player.positionStream.listen((position) {
      _position = position;
    });
  }
  
  void _updateMediaItem() {
    if (_currentIndex >= 0 && _currentIndex < _playlist.length) {
      final track = _playlist[_currentIndex];
      mediaItem.add(MediaItem(
        id: track.id,
        title: track.name,
        artist: track.albumArtist ?? track.artist ?? 'Unknown Artist',
        album: track.album ?? 'Unknown Album',
        duration: track.duration != null ? Duration(milliseconds: (track.duration! * 1000).round()) : null,
        artUri: Uri.parse(_jellyfinService.getImageUrl(track.albumId ?? track.id, width: 300, height: 300)),
      ));
      
      if (kDebugMode) {
        print('Updated media item: ${track.name}');
      }
    }
  }
  
  void _handleTrackCompleted() {
    if (kDebugMode) {
      print('Track completed, auto-advancing to next');
    }
    
    // Auto-advance to next track
    if (_currentIndex < _playlist.length - 1) {
      skipToNext();
    } else {
      // End of playlist
      _isPlaying = false;
      if (kDebugMode) {
        print('Reached end of playlist');
      }
    }
  }

  @override
  Future<void> play() async {
    if (kDebugMode) {
      print('Play requested');
    }
    
    if (_playlist.isEmpty) {
      if (kDebugMode) {
        print('No playlist loaded');
      }
      return;
    }
    
    if (_player.audioSource == null) {
      // Load current track first
      await _loadCurrentTrack();
    }
    
    await _player.play();
  }

  @override
  Future<void> pause() async {
    if (kDebugMode) {
      print('Pause requested');
    }
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    if (kDebugMode) {
      print('Stop requested');
    }
    await _player.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    if (kDebugMode) {
      print('Seek to: ${position.inSeconds}s');
    }
    await _player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    if (kDebugMode) {
      print('Skip to next: current=$_currentIndex, max=${_playlist.length - 1}');
    }
    
    if (_currentIndex < _playlist.length - 1) {
      _currentIndex++;
      await _loadCurrentTrack();
      
      if (_isPlaying) {
        await _player.play();
      }
      
      if (kDebugMode) {
        print('Skipped to track ${_currentIndex + 1}/${_playlist.length}: ${_playlist[_currentIndex].name}');
      }
    } else {
      if (kDebugMode) {
        print('Already at last track');
      }
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (kDebugMode) {
      print('Skip to previous: current=$_currentIndex');
    }
    
    // If we're more than 3 seconds into the track, restart it
    if (_position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    
    // Otherwise go to previous track
    if (_currentIndex > 0) {
      _currentIndex--;
      await _loadCurrentTrack();
      
      if (_isPlaying) {
        await _player.play();
      }
      
      if (kDebugMode) {
        print('Skipped to track ${_currentIndex + 1}/${_playlist.length}: ${_playlist[_currentIndex].name}');
      }
    } else {
      if (kDebugMode) {
        print('Already at first track, restarting current track');
      }
      await seek(Duration.zero);
    }
  }
  
  Future<void> _loadCurrentTrack() async {
    if (_currentIndex < 0 || _currentIndex >= _playlist.length) {
      if (kDebugMode) {
        print('Invalid track index: $_currentIndex');
      }
      return;
    }
    
    final track = _playlist[_currentIndex];
    if (kDebugMode) {
      print('Loading track: ${track.name}');
    }
    
    try {
      // Get stream URLs for this track
      final urls = await _getStreamUrls(track);
      
      // Try each URL until one works
      bool loaded = false;
      for (int i = 0; i < urls.length && !loaded; i++) {
        try {
          if (kDebugMode) {
            print('Trying URL ${i + 1}/${urls.length}: ${urls[i]}');
          }
          
          await _player.setUrl(urls[i]);
          loaded = true;
          
          if (kDebugMode) {
            print('Successfully loaded URL ${i + 1}/${urls.length}');
          }
        } catch (e) {
          if (kDebugMode) {
            print('URL ${i + 1}/${urls.length} failed: $e');
          }
          
          if (i == urls.length - 1) {
            // All URLs failed
            throw Exception('All stream URLs failed for track: ${track.name}');
          }
        }
      }
      
      _updateMediaItem();
      
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load track ${track.name}: $e');
      }
      
      // Skip to next track on error
      if (_currentIndex < _playlist.length - 1) {
        _currentIndex++;
        await _loadCurrentTrack();
      }
    }
  }
  
  Future<List<String>> _getStreamUrls(Track track) async {
    final service = _mediaServiceManager ?? _jellyfinService;
    
    return [
      service.getDirectStreamUrl(track.id),
      service.getSimpleStreamUrl(track.id),
      service.getMinimalStreamUrl(track.id),
    ];
  }

  // Public methods for playlist management
  Future<void> setPlaylist(List<Track> tracks, {int startIndex = 0}) async {
    if (kDebugMode) {
      print('Setting playlist: ${tracks.length} tracks, starting at index $startIndex');
    }
    
    _playlist = tracks;
    _currentIndex = startIndex;
    
    if (_playlist.isNotEmpty) {
      await _loadCurrentTrack();
      _updateMediaItem();
    }
  }

  Future<void> playTrack(Track track) async {
    if (kDebugMode) {
      print('Playing single track: ${track.name}');
    }
    
    await setPlaylist([track], startIndex: 0);
    await play();
  }

  Future<void> playPlaylist(List<Track> tracks, {int startIndex = 0}) async {
    if (kDebugMode) {
      print('Playing playlist: ${tracks.length} tracks, starting at ${tracks[startIndex].name}');
    }
    
    await setPlaylist(tracks, startIndex: startIndex);
    await play();
  }
  
  // Getters
  List<Track> get playlist => List.unmodifiable(_playlist);
  int get currentIndex => _currentIndex;
  Track? get currentTrack => _currentIndex >= 0 && _currentIndex < _playlist.length ? _playlist[_currentIndex] : null;
  bool get hasNext => _currentIndex < _playlist.length - 1;
  bool get hasPrevious => _currentIndex > 0;

  @override
  Future<void> onTaskRemoved() async {
    if (kDebugMode) {
      print('Task removed, stopping playback');
    }
    await stop();
  }

  void dispose() {
    if (kDebugMode) {
      print('Disposing SimpleAudioHandler');
    }
    
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _player.dispose();
  }
}