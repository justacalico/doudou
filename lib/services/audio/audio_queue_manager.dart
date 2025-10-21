import 'package:flutter/foundation.dart';
import '../../models/jellyfin_models.dart';
import '../logging_service.dart';
import 'audio_state_manager.dart';
import 'async_mutex.dart';

/// Manages queue operations including shuffle, add/remove tracks, and queue manipulation
/// Enhanced with proper synchronization to prevent concurrent queue modifications
class AudioQueueManager {
  final AudioStateManager _stateManager;
  final LoggingService _logger = LoggingService();
  
  // Mutex for queue operation synchronization
  final NamedMutexManager _mutexManager = NamedMutexManager();
  
  AudioQueueManager(this._stateManager);
  
  Future<void> addToQueue(Track track) async {
    await _stateManager.addToPlaylistAtomic(track);
    _logger.info('Added track to queue: ${track.name} (Total: ${_stateManager.queueLength} tracks)', 'QueueManager');
    
    if (kDebugMode) {
      print('Added track to queue: ${track.name}');
    }
  }
  
  Future<void> addNext(Track track) async {
    // Insert the track right after the current track
    final insertIndex = _stateManager.currentIndex + 1;
    
    await _stateManager.insertIntoPlaylistAtomic(insertIndex, track);
    _logger.info('Added track to play next: ${track.name} at position $insertIndex', 'QueueManager');
    
    if (kDebugMode) {
      print('Added track to play next: ${track.name} at position $insertIndex');
    }
  }
  
  Future<bool> removeFromQueue(int index) async {
    if (index < 0 || index >= _stateManager.queueLength || index == _stateManager.currentIndex) {
      _logger.warning('Cannot remove track at index $index (invalid or current track)', 'QueueManager');
      return false;
    }
    
    final success = await _stateManager.removeFromPlaylistAtomic(index);
    
    if (success) {
      _logger.info('Removed track from queue at index: $index', 'QueueManager');
      if (kDebugMode) {
        print('Removed track from queue at index: $index');
      }
    }
    
    return success;
  }
  
  Future<void> clearQueue() async {
    await _stateManager.clearPlaylistAtomic();
    _logger.info('Cleared entire queue', 'QueueManager');
    
    if (kDebugMode) {
      print('Cleared entire queue');
    }
  }
  
  void shuffle() {
    final playlist = _stateManager.playlist;
    final currentIndex = _stateManager.currentIndex;
    
    if (playlist.length <= 1) {
      _logger.info('Cannot shuffle - playlist has 1 or fewer tracks', 'QueueManager');
      return;
    }
    
    _stateManager.setShuffled(true);
    final currentTrack = playlist[currentIndex];
    
    // Remove current track from shuffling
    final remainingTracks = List<Track>.from(playlist);
    remainingTracks.removeAt(currentIndex);
    
    // Shuffle remaining tracks
    remainingTracks.shuffle();
    
    // Create new playlist with current track first, then shuffled tracks
    final newPlaylist = [currentTrack, ...remainingTracks];
    _stateManager.setPlaylist(newPlaylist);
    _stateManager.setCurrentIndex(0);
    
    _logger.info('Shuffled playlist: ${newPlaylist.length} tracks', 'QueueManager');
    if (kDebugMode) {
      print('Shuffled playlist: ${newPlaylist.length} tracks');
    }
  }
  
  void unshuffle() {
    // Since we don't store the original playlist, we'll just disable shuffle mode
    _stateManager.setShuffled(false);
    _logger.info('Unshuffle called - shuffle mode disabled', 'QueueManager');
    
    if (kDebugMode) {
      print('Unshuffle called - shuffle mode disabled');
    }
  }
  
  /// Set up a new playlist and queue
  void setPlaylist(List<Track> tracks, int startIndex) {
    // Ensure startIndex is valid
    final validIndex = startIndex.clamp(0, tracks.length - 1);
    
    // Clear old state and set new playlist
    _stateManager.setPlaylist(tracks);
    _stateManager.setCurrentIndex(validIndex);
    _stateManager.setShuffled(false);
    
    // CRITICAL FIX: Immediately set the current track to ensure UI consistency
    if (tracks.isNotEmpty && validIndex < tracks.length) {
      _stateManager.setCurrentTrack(tracks[validIndex]);
    } else {
      _stateManager.setCurrentTrack(null);
    }
    
    _logger.info('Set new playlist: ${tracks.length} tracks, starting at index $validIndex', 'QueueManager');
    if (kDebugMode) {
      print('Set new playlist: ${tracks.length} tracks, starting at index $validIndex');
      if (tracks.isNotEmpty && validIndex < tracks.length) {
        print('Current track set to: ${tracks[validIndex].name}');
      }
    }
  }
  
  /// Set up a single track as the playlist
  void setSingleTrack(Track track) {
    _stateManager.setPlaylist([track]);
    _stateManager.setCurrentIndex(0);
    
    // CRITICAL FIX: Immediately set the current track for consistency
    _stateManager.setCurrentTrack(track);
    
    _logger.info('Set single track playlist: ${track.name}', 'QueueManager');
    if (kDebugMode) {
      print('Set single track playlist: ${track.name}');
      print('Current track set to: ${track.name}');
    }
  }
  
  /// Add tracks to the end of the playlist (for radio mode) - Thread-safe
  Future<void> addTracksToPlaylist(List<Track> tracks) async {
    for (final track in tracks) {
      await _stateManager.addToPlaylistAtomic(track);
    }
    
    _logger.info('Added ${tracks.length} tracks to playlist (now ${_stateManager.playlist.length} total)', 'QueueManager');
    if (kDebugMode) {
      print('Added ${tracks.length} tracks to playlist (now ${_stateManager.playlist.length} total)');
    }
  }
}
