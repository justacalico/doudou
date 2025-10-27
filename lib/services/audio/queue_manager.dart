import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../models/jellyfin_models.dart';
import 'base_audio_handler.dart';
import 'audio_state_controller.dart';

/// Robust queue management system with shuffle, repeat modes, and queue manipulation
class AudioQueueManager {
  final AudioStateController _stateController = AudioStateController();
  
  // Original queue (before shuffling) to preserve user order
  List<Track> _originalQueue = [];
  List<int> _shuffledIndices = [];
  bool _isShuffled = false;
  
  /// Get the current effective queue (shuffled or original)
  List<Track> get effectiveQueue => _stateController.queue;
  
  /// Get the original unshuffled queue
  List<Track> get originalQueue => List.unmodifiable(_originalQueue);
  
  /// Check if queue is currently shuffled
  bool get isShuffled => _isShuffled;
  
  /// Set a new queue and reset shuffle state
  void setQueue(List<Track> tracks, {int? startIndex}) {
    if (kDebugMode) {
      print('QueueManager: Setting queue with ${tracks.length} tracks, startIndex: $startIndex');
    }
    
    _originalQueue = List.from(tracks);
    _shuffledIndices = List.generate(tracks.length, (index) => index);
    _isShuffled = false;
    
    _stateController.updateQueue(tracks, currentIndex: startIndex);
    
    if (kDebugMode) {
      print('QueueManager: Queue set successfully');
    }
  }
  
  /// Add track to the end of the queue
  void addToQueue(Track track) {
    if (kDebugMode) {
      print('QueueManager: Adding track to queue: ${track.name}');
    }
    
    _originalQueue.add(track);
    
    if (_isShuffled) {
      // Add to shuffled queue at random position (but not before current)
      final currentQueue = List<Track>.from(_stateController.queue);
      final currentIndex = _stateController.currentIndex ?? 0;
      
      // Insert at random position after current track
      final insertPosition = currentIndex + 1 + 
          Random().nextInt(max(1, currentQueue.length - currentIndex));
      
      currentQueue.insert(insertPosition.clamp(0, currentQueue.length), track);
      _stateController.updateQueue(currentQueue);
      
      // Update shuffled indices
      _shuffledIndices.add(_originalQueue.length - 1);
    } else {
      // Add to regular queue
      _stateController.addTrackToQueue(track);
    }
  }
  
  /// Add track as next in queue
  void addNext(Track track) {
    if (kDebugMode) {
      print('QueueManager: Adding track next: ${track.name}');
    }
    
    _originalQueue.add(track);
    _stateController.addTrackNext(track);
    
    if (_isShuffled) {
      // Update shuffled indices to include the new track
      _shuffledIndices.add(_originalQueue.length - 1);
    }
  }
  
  /// Remove track from queue by index
  void removeFromQueue(int index) {
    if (index < 0 || index >= _stateController.queue.length) return;
    
    if (kDebugMode) {
      print('QueueManager: Removing track at index $index');
    }
    
    final trackToRemove = _stateController.queue[index];
    
    // Remove from original queue
    _originalQueue.removeWhere((track) => track.id == trackToRemove.id);
    
    // Remove from current queue
    _stateController.removeTrackFromQueue(index);
    
    // Update shuffled indices if needed
    if (_isShuffled) {
      _updateShuffledIndicesAfterRemoval(trackToRemove);
    }
  }
  
  /// Reorder queue items
  void reorderQueue(int oldIndex, int newIndex) {
    if (kDebugMode) {
      print('QueueManager: Reordering queue from $oldIndex to $newIndex');
    }
    
    // Only allow reordering in non-shuffled mode
    if (!_isShuffled) {
      final track = _originalQueue.removeAt(oldIndex);
      _originalQueue.insert(newIndex, track);
    }
    
    _stateController.reorderQueueItems(oldIndex, newIndex);
  }
  
  /// Clear the entire queue
  void clearQueue() {
    if (kDebugMode) {
      print('QueueManager: Clearing queue');
    }
    
    _originalQueue.clear();
    _shuffledIndices.clear();
    _isShuffled = false;
    _stateController.clearQueue();
  }
  
  /// Enable shuffle mode
  void enableShuffle() {
    if (_isShuffled || _originalQueue.isEmpty) return;
    
    if (kDebugMode) {
      print('QueueManager: Enabling shuffle mode');
    }
    
    final currentTrack = _stateController.currentTrack;
    final currentIndex = _stateController.currentIndex;
    
    // Create shuffled indices
    _shuffledIndices = List.generate(_originalQueue.length, (index) => index);
    
    // Keep current track at the beginning if there is one
    if (currentIndex != null && currentIndex < _originalQueue.length) {
      _shuffledIndices.removeAt(currentIndex);
      _shuffledIndices.shuffle();
      _shuffledIndices.insert(0, currentIndex);
    } else {
      _shuffledIndices.shuffle();
    }
    
    // Create shuffled queue
    final shuffledQueue = _shuffledIndices.map((index) => _originalQueue[index]).toList();
    
    _isShuffled = true;
    _stateController.updateQueue(shuffledQueue, currentIndex: currentTrack != null ? 0 : null);
    _stateController.updateShuffleEnabled(true);
    
    if (kDebugMode) {
      print('QueueManager: Shuffle enabled, new queue length: ${shuffledQueue.length}');
    }
  }
  
  /// Disable shuffle mode
  void disableShuffle() {
    if (!_isShuffled) return;
    
    if (kDebugMode) {
      print('QueueManager: Disabling shuffle mode');
    }
    
    final currentTrack = _stateController.currentTrack;
    int? newCurrentIndex;
    
    // Find the current track in the original queue
    if (currentTrack != null) {
      newCurrentIndex = _originalQueue.indexWhere((track) => track.id == currentTrack.id);
      if (newCurrentIndex == -1) newCurrentIndex = null;
    }
    
    _isShuffled = false;
    _shuffledIndices = List.generate(_originalQueue.length, (index) => index);
    _stateController.updateQueue(_originalQueue, currentIndex: newCurrentIndex);
    _stateController.updateShuffleEnabled(false);
    
    if (kDebugMode) {
      print('QueueManager: Shuffle disabled, restored original queue');
    }
  }
  
  /// Toggle shuffle mode
  void toggleShuffle() {
    if (_isShuffled) {
      disableShuffle();
    } else {
      enableShuffle();
    }
  }
  
  /// Get next track index based on repeat mode
  int? getNextTrackIndex() {
    final currentIndex = _stateController.currentIndex;
    final queueLength = _stateController.queue.length;
    final repeatMode = _stateController.repeatMode;
    
    if (queueLength == 0) return null;
    if (currentIndex == null) return 0;
    
    switch (repeatMode) {
      case RepeatMode.one:
        // Repeat current track
        return currentIndex;
        
      case RepeatMode.all:
        // Go to next track, loop to beginning if at end
        return (currentIndex + 1) % queueLength;
        
      case RepeatMode.none:
        // Go to next track, stop if at end
        final nextIndex = currentIndex + 1;
        return nextIndex < queueLength ? nextIndex : null;
    }
  }
  
  /// Get previous track index
  int? getPreviousTrackIndex() {
    final currentIndex = _stateController.currentIndex;
    final queueLength = _stateController.queue.length;
    
    if (queueLength == 0 || currentIndex == null) return null;
    
    // Always go to previous track (or last track if at beginning)
    return currentIndex > 0 ? currentIndex - 1 : queueLength - 1;
  }
  
  /// Check if there is a next track available
  bool get hasNext {
    final nextIndex = getNextTrackIndex();
    return nextIndex != null;
  }
  
  /// Check if there is a previous track available
  bool get hasPrevious {
    final previousIndex = getPreviousTrackIndex();
    return previousIndex != null;
  }
  
  /// Get tracks that will play after current track (up next)
  List<Track> getUpNext({int limit = 10}) {
    final currentIndex = _stateController.currentIndex;
    final queue = _stateController.queue;
    
    if (currentIndex == null || queue.isEmpty) return [];
    
    final upNext = <Track>[];
    int nextIndex = currentIndex;
    
    for (int i = 0; i < limit; i++) {
      nextIndex = _getNextIndexForUpNext(nextIndex, queue.length);
      if (nextIndex == null || nextIndex == currentIndex) break;
      
      upNext.add(queue[nextIndex]);
    }
    
    return upNext;
  }
  
  /// Helper method to get next index for up next calculation
  int? _getNextIndexForUpNext(int currentIndex, int queueLength) {
    switch (_stateController.repeatMode) {
      case RepeatMode.one:
        return currentIndex; // Same track repeats
        
      case RepeatMode.all:
        return (currentIndex + 1) % queueLength;
        
      case RepeatMode.none:
        final nextIndex = currentIndex + 1;
        return nextIndex < queueLength ? nextIndex : null;
    }
  }
  
  /// Update shuffled indices after a track is removed
  void _updateShuffledIndicesAfterRemoval(Track removedTrack) {
    final removedOriginalIndex = _originalQueue.indexWhere(
      (track) => track.id == removedTrack.id
    );
    
    if (removedOriginalIndex != -1) {
      // Remove the index from shuffled indices
      _shuffledIndices.removeWhere((index) => index == removedOriginalIndex);
      
      // Adjust remaining indices
      for (int i = 0; i < _shuffledIndices.length; i++) {
        if (_shuffledIndices[i] > removedOriginalIndex) {
          _shuffledIndices[i]--;
        }
      }
    }
  }
  
  /// Get queue statistics for debugging
  Map<String, dynamic> getQueueStats() {
    return {
      'originalQueueLength': _originalQueue.length,
      'currentQueueLength': _stateController.queue.length,
      'isShuffled': _isShuffled,
      'currentIndex': _stateController.currentIndex,
      'hasNext': hasNext,
      'hasPrevious': hasPrevious,
      'repeatMode': _stateController.repeatMode.toString(),
      'upNextCount': getUpNext().length,
    };
  }
}