import 'dart:async';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import '../../models/jellyfin_models.dart';
import '../download_service.dart';
import '../jellyfin_service.dart';

/// Handles preloading and caching of audio tracks for instant playback
/// Enhanced for gapless playback with AudioSource generation
/// Thread-safe implementation to prevent cleanup/creation race conditions
class AudioPreloader {
  final JellyfinService _jellyfinService;
  final DownloadService _downloadService;
  
  // Synchronized preloading state
  final Map<String, AudioPlayer> _preloadedPlayers = {};
  final Map<String, AudioSource> _preloadedAudioSources = {}; // New: Audio sources for concatenation
  final Set<String> _preloadingTracks = {}; // Tracks currently being preloaded
  final Set<String> _bufferedTracks = {}; // Tracks with buffered content
  
  // Synchronization locks
  Completer<void>? _preloadLock;
  Completer<void>? _cleanupLock;
  
  AudioPreloader(this._jellyfinService, this._downloadService);
  
  /// Acquires preload operation lock to prevent race conditions
  Future<void> _acquirePreloadLock() async {
    while (_preloadLock != null && !_preloadLock!.isCompleted) {
      await _preloadLock!.future;
    }
    _preloadLock = Completer<void>();
  }
  
  /// Releases preload operation lock
  void _releasePreloadLock() {
    if (_preloadLock != null && !_preloadLock!.isCompleted) {
      _preloadLock!.complete();
    }
  }
  
  /// Acquires cleanup operation lock to prevent race conditions
  Future<void> _acquireCleanupLock() async {
    while (_cleanupLock != null && !_cleanupLock!.isCompleted) {
      await _cleanupLock!.future;
    }
    _cleanupLock = Completer<void>();
  }
  
  /// Releases cleanup operation lock
  void _releaseCleanupLock() {
    if (_cleanupLock != null && !_cleanupLock!.isCompleted) {
      _cleanupLock!.complete();
    }
  }

  Map<String, AudioPlayer> get preloadedPlayers => _preloadedPlayers;
  Map<String, AudioSource> get preloadedAudioSources => _preloadedAudioSources;
  Set<String> get preloadingTracks => _preloadingTracks;
  Set<String> get bufferedTracks => _bufferedTracks;

  /// Get preloaded audio source for gapless playback
  AudioSource? getPreloadedAudioSource(String trackId) {
    return _preloadedAudioSources[trackId];
  }

  /// Get preloaded player (legacy method)
  AudioPlayer? getPreloadedPlayer(String trackId) {
    return _preloadedPlayers[trackId];
  }
  
  /// Thread-safe aggressive preload of next tracks
  void preloadNextTracks(List<Track> playlist, int currentIndex) async {
    // Acquire preload lock to prevent conflicts with cleanup
    await _acquirePreloadLock();
    
    try {
      // Always preload next 3 tracks for instant switching
      const preloadCount = 3;
      
      if (kDebugMode) {
        print('Starting synchronized preloading of next $preloadCount tracks...');
      }
      
      // Schedule cleanup without blocking (but synchronized)
      Future(() => _cleanupOldPreloadedPlayersSynchronized(playlist, currentIndex));
      
      for (int i = 1; i <= preloadCount; i++) {
        final nextIndex = currentIndex + i;
        if (nextIndex < playlist.length) {
          final track = playlist[nextIndex];
          if (!_preloadedPlayers.containsKey(track.id) && !_preloadingTracks.contains(track.id)) {
            // Start preloading without blocking
            Future(() => _preloadTrackAggressive(track, i));
          }
        }
      }
      
      // Also preload the previous track for instant skip-back
      if (currentIndex > 0) {
        final prevTrack = playlist[currentIndex - 1];
        if (!_preloadedPlayers.containsKey(prevTrack.id) && !_preloadingTracks.contains(prevTrack.id)) {
          Future(() => _preloadTrackAggressive(prevTrack, 0));
        }
      }
    } finally {
      _releasePreloadLock();
    }
  }
  
  void _preloadTrackAggressive(Track track, int priority) async {
    // Don't preload if already preloaded or currently preloading
    if (_preloadedPlayers.containsKey(track.id) || _preloadingTracks.contains(track.id)) {
      return;
    }
    
    _preloadingTracks.add(track.id);
    
    if (kDebugMode) {
      print('Aggressively preloading track (priority $priority): ${track.name}');
    }
    
    try {
      final player = AudioPlayer();
      
      // Check if track is downloaded locally first
      final localFilePath = _downloadService.getLocalFilePath(track.id);
      
      bool loaded = false;
      
      if (localFilePath != null) {
        final localFile = File(localFilePath);
        if (await localFile.exists()) {
          try {
            await player.setFilePath(localFilePath);
            
            // For local files, wait briefly to ensure they're ready
            await Future.delayed(const Duration(milliseconds: 100));
            
            _preloadedPlayers[track.id] = player;
            _bufferedTracks.add(track.id);
            loaded = true;
            
            if (kDebugMode) {
              print('✓ Aggressively preloaded local track: ${track.name}');
            }
          } catch (e) {
            if (kDebugMode) {
              print('Failed to aggressively preload local track ${track.name}: $e');
            }
          }
        }
      }
      
      if (!loaded) {
        // Stream preloading - use optimized URL selection
        final fallbackUrl = _jellyfinService.getDirectStreamUrl(track.id);
        final primaryUrl = _jellyfinService.getStreamUrl(track.id);
        
        // Try direct stream first (optimized based on server behavior)
        try {
          await player.setUrl(fallbackUrl);
          
          // Don't wait for full buffer - just start the buffering process
          _preloadedPlayers[track.id] = player;
          _bufferedTracks.add(track.id);
          loaded = true;
          
          if (kDebugMode) {
            print('✓ Started aggressive buffering (direct): ${track.name}');
          }
          
          // Let it buffer in the background without waiting
          player.playerStateStream.listen((state) {
            if (state.processingState == ProcessingState.ready) {
              if (kDebugMode) {
                print('✓ Background buffering complete for: ${track.name}');
              }
            }
          });
          
        } catch (e) {
          // Fallback to primary URL
          try {
            await player.setUrl(primaryUrl);
            
            _preloadedPlayers[track.id] = player;
            _bufferedTracks.add(track.id);
            loaded = true;
            
            if (kDebugMode) {
              print('✓ Started aggressive buffering (primary): ${track.name}');
            }
            
            player.playerStateStream.listen((state) {
              if (state.processingState == ProcessingState.ready) {
                if (kDebugMode) {
                  print('✓ Background buffering complete for: ${track.name}');
                }
              }
            });
            
          } catch (primaryError) {
            if (kDebugMode) {
              print('Failed to start aggressive buffering for ${track.name}: direct=$e, primary=$primaryError');
            }
            loaded = false;
          }
        }
      }
      
      if (!loaded) {
        player.dispose();
        if (kDebugMode) {
          print('✗ Could not aggressively preload track: ${track.name}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in aggressive preloading for ${track.name}: $e');
      }
    } finally {
      _preloadingTracks.remove(track.id);
    }
  }
  
  /// Preload a track immediately with highest priority for "play next" functionality
  void preloadPlayNextTrack(Track track) {
    if (kDebugMode) {
      print('Immediately preloading "play next" track: ${track.name}');
    }
    _preloadTrackAggressive(track, 1); // Highest priority
  }
  
  /// Preload a track that was added to queue if it's within next 5 tracks
  void preloadQueueTrack(Track track, int positionFromCurrent) {
    if (positionFromCurrent <= 5) { // If within next 5 tracks, preload immediately
      if (kDebugMode) {
        print('Immediately preloading newly added track: ${track.name}');
      }
      _preloadTrackAggressive(track, positionFromCurrent);
    }
  }
  
  void clearAllPreloadedPlayers() {
    if (kDebugMode) {
      print('Clearing all ${_preloadedPlayers.length} preloaded players');
    }
    
    for (final player in _preloadedPlayers.values) {
      player.dispose();
    }
    _preloadedPlayers.clear();
    _preloadingTracks.clear();
    _bufferedTracks.clear();
    
    if (kDebugMode) {
      print('Cleared all preloaded players and buffers');
    }
  }
  
  /// Thread-safe cleanup of old preloaded players
  Future<void> _cleanupOldPreloadedPlayersSynchronized(List<Track> playlist, int currentIndex) async {
    await _acquireCleanupLock();
    
    try {
      final currentTrackId = playlist.isNotEmpty && currentIndex < playlist.length 
          ? playlist[currentIndex].id 
          : null;
      final upcomingTrackIds = <String>{};
      
      // Collect IDs of upcoming tracks (next 3 tracks + previous track)
      const preloadCount = 3;
      
      // Add next tracks
      for (int i = 1; i <= preloadCount; i++) {
        final nextIndex = currentIndex + i;
        if (nextIndex < playlist.length) {
          upcomingTrackIds.add(playlist[nextIndex].id);
        }
      }
      
      // Add previous track for instant skip-back
      if (currentIndex > 0) {
        upcomingTrackIds.add(playlist[currentIndex - 1].id);
      }
      
      // Find players to remove (synchronized check)
      final keysToRemove = <String>[];
      for (final trackId in _preloadedPlayers.keys) {
        if (trackId != currentTrackId && !upcomingTrackIds.contains(trackId)) {
          keysToRemove.add(trackId);
        }
      }
      
      if (keysToRemove.isNotEmpty && kDebugMode) {
        if (kDebugMode) {
          print('Cleaning up ${keysToRemove.length} old preloaded tracks');
        }
      }
      
      // Atomically remove and dispose players
      for (final trackId in keysToRemove) {
        final player = _preloadedPlayers.remove(trackId);
        _bufferedTracks.remove(trackId);
        
        // Dispose player safely
        if (player != null) {
          try {
            player.dispose();
            if (kDebugMode) {
              print('Cleaned up preloaded player for track: $trackId');
            }
          } catch (e) {
            if (kDebugMode) {
              print('Error disposing preloaded player: $e');
            }
          }
        }
      }
      
      if (kDebugMode) {
        print('Currently buffered: ${_preloadedPlayers.length} tracks, Buffering: ${_preloadingTracks.length} tracks');
      }
    } finally {
      _releaseCleanupLock();
    }
  }
  
  void cleanupOldPreloadedPlayers(List<Track> playlist, int currentIndex) {
    // Delegate to synchronized version
    Future(() => _cleanupOldPreloadedPlayersSynchronized(playlist, currentIndex));
  }
  
  /// Try to use a preloaded player if available - Thread-safe
  AudioPlayer? getPreloadedPlayer(String trackId) {
    // Atomically remove and return the player
    return _preloadedPlayers.remove(trackId);
  }
  
  void dispose() {
    clearAllPreloadedPlayers();
  }
}
