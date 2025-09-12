import 'package:flutter/foundation.dart';
import '../../models/jellyfin_models.dart';
import 'audio_state_manager.dart';

/// Manages queue operations including shuffle, add/remove tracks, and queue manipulation
class AudioQueueManager {
  final AudioStateManager _stateManager;
  
  AudioQueueManager(this._stateManager);
  
  Future<void> addToQueue(Track track) async {
    await _stateManager.addToPlaylistAtomic(track);
    
    if (kDebugMode) {
      print('Added track to queue: ${track.name}');
    }
  }
  
  Future<void> addNext(Track track) async {
    // Insert the track right after the current track
    final insertIndex = _stateManager.currentIndex + 1;
    
    await _stateManager.insertIntoPlaylistAtomic(insertIndex, track);
    
    if (kDebugMode) {
      print('Added track to play next: ${track.name} at position $insertIndex');
    }
  }
  
  Future<bool> removeFromQueue(int index) async {
    if (index < 0 || index >= _stateManager.queueLength || index == _stateManager.currentIndex) {
      return false;
    }
    
    final success = await _stateManager.removeFromPlaylistAtomic(index);
    
    if (success && kDebugMode) {
      print('Removed track from queue at index: $index');
    }
    
    return success;
  }
  
  Future<void> clearQueue() async {
    await _stateManager.clearPlaylistAtomic();
    
    if (kDebugMode) {
      print('Cleared entire queue');
    }
  }
  
  void shuffle() {
    final playlist = _stateManager.playlist;
    final currentIndex = _stateManager.currentIndex;
    
    if (playlist.length <= 1) return;
    
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
    
    if (kDebugMode) {
      print('Shuffled playlist: ${newPlaylist.length} tracks');
    }
  }
  
  void unshuffle() {
    // Since we don't store the original playlist, we'll just disable shuffle mode
    _stateManager.setShuffled(false);
    
    if (kDebugMode) {
      print('Unshuffle called - shuffle mode disabled');
    }
  }
  
  /// Set up a new playlist and queue
  void setPlaylist(List<Track> tracks, int startIndex) {
    _stateManager.setPlaylist(tracks);
    _stateManager.setCurrentIndex(startIndex.clamp(0, tracks.length - 1));
    _stateManager.setShuffled(false);
    
    if (kDebugMode) {
      print('Set new playlist: ${tracks.length} tracks, starting at index $startIndex');
    }
  }
  
  /// Set up a single track as the playlist
  void setSingleTrack(Track track) {
    _stateManager.setPlaylist([track]);
    _stateManager.setCurrentIndex(0);
    
    if (kDebugMode) {
      print('Set single track playlist: ${track.name}');
    }
  }
  
  /// Add tracks to the end of the playlist (for radio mode)
  void addTracksToPlaylist(List<Track> tracks) {
    for (final track in tracks) {
      _stateManager.addToPlaylist(track);
    }
    
    if (kDebugMode) {
      print('Added ${tracks.length} tracks to playlist (now ${_stateManager.playlist.length} total)');
    }
  }
}
