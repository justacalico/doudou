/// Reference counting system for AudioPreloader to prevent cleanup race conditions
/// Ensures audio sources are not disposed while they're being used or prepared

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Reference-counted audio source container
class ReferenceCountedAudioSource {
  final String trackId;
  final AudioSource audioSource;
  final AudioPlayer? player;
  int _referenceCount = 0;
  bool _isDisposed = false;
  DateTime _lastAccessed = DateTime.now();
  
  ReferenceCountedAudioSource({
    required this.trackId,
    required this.audioSource,
    this.player,
  });
  
  /// Current reference count
  int get referenceCount => _referenceCount;
  
  /// Whether this audio source has been disposed
  bool get isDisposed => _isDisposed;
  
  /// When this audio source was last accessed
  DateTime get lastAccessed => _lastAccessed;
  
  /// Add a reference to this audio source
  void addReference(String requester) {
    if (_isDisposed) {
      throw StateError('Cannot add reference to disposed audio source: $trackId');
    }
    
    _referenceCount++;
    _lastAccessed = DateTime.now();
    
    if (kDebugMode) {
      print('Added reference to $trackId (count: $_referenceCount, requester: $requester)');
    }
  }
  
  /// Remove a reference from this audio source
  /// Returns true if the reference count reached zero and disposal is safe
  bool removeReference(String requester) {
    if (_isDisposed) {
      if (kDebugMode) {
        print('Warning: Removing reference from already disposed audio source: $trackId');
      }
      return false;
    }
    
    if (_referenceCount <= 0) {
      if (kDebugMode) {
        print('Warning: Removing reference from audio source with zero references: $trackId');
      }
      return true;
    }
    
    _referenceCount--;
    _lastAccessed = DateTime.now();
    
    if (kDebugMode) {
      print('Removed reference from $trackId (count: $_referenceCount, requester: $requester)');
    }
    
    return _referenceCount <= 0;
  }
  
  /// Dispose this audio source and its associated player
  Future<void> dispose() async {
    if (_isDisposed) return;
    
    _isDisposed = true;
    
    try {
      await player?.dispose();
      if (kDebugMode) {
        print('Disposed audio source and player for: $trackId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error disposing audio source for $trackId: $e');
      }
    }
  }
  
  /// Force dispose regardless of reference count (for emergency cleanup)
  Future<void> forceDispose() async {
    _referenceCount = 0;
    await dispose();
  }
}

/// Manager for reference-counted audio sources
class AudioSourceReferenceManager {
  final Map<String, ReferenceCountedAudioSource> _audioSources = {};
  final Set<String> _protectedSources = {}; // Sources that should never be cleaned up
  Timer? _cleanupTimer;
  
  /// Start automatic cleanup of unreferenced sources
  void startCleanupTimer({Duration interval = const Duration(minutes: 2)}) {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(interval, (_) => _performAutomaticCleanup());
  }
  
  /// Stop automatic cleanup
  void stopCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
  }
  
  /// Register a new audio source with reference counting
  void registerAudioSource({
    required String trackId,
    required AudioSource audioSource,
    AudioPlayer? player,
    String requester = 'unknown',
  }) {
    if (_audioSources.containsKey(trackId)) {
      // Already exists, just add a reference
      _audioSources[trackId]!.addReference(requester);
      return;
    }
    
    final refCountedSource = ReferenceCountedAudioSource(
      trackId: trackId,
      audioSource: audioSource,
      player: player,
    );
    
    refCountedSource.addReference(requester);
    _audioSources[trackId] = refCountedSource;
    
    if (kDebugMode) {
      print('Registered new audio source: $trackId (requester: $requester)');
    }
  }
  
  /// Add a reference to an existing audio source
  bool addReference(String trackId, String requester) {
    final source = _audioSources[trackId];
    if (source == null || source.isDisposed) {
      return false;
    }
    
    source.addReference(requester);
    return true;
  }
  
  /// Remove a reference from an audio source
  /// Returns true if the source was cleaned up due to zero references
  Future<bool> removeReference(String trackId, String requester) async {
    final source = _audioSources[trackId];
    if (source == null) {
      return false;
    }
    
    final shouldCleanup = source.removeReference(requester);
    
    if (shouldCleanup && !_protectedSources.contains(trackId)) {
      await source.dispose();
      _audioSources.remove(trackId);
      
      if (kDebugMode) {
        print('Cleaned up audio source due to zero references: $trackId');
      }
      return true;
    }
    
    return false;
  }
  
  /// Get an audio source and add a reference to it
  AudioSource? getAudioSourceWithReference(String trackId, String requester) {
    final source = _audioSources[trackId];
    if (source == null || source.isDisposed) {
      return null;
    }
    
    source.addReference(requester);
    return source.audioSource;
  }
  
  /// Get an audio source without adding a reference (read-only access)
  AudioSource? getAudioSource(String trackId) {
    final source = _audioSources[trackId];
    if (source == null || source.isDisposed) {
      return null;
    }
    
    return source.audioSource;
  }
  
  /// Protect an audio source from automatic cleanup
  void protectAudioSource(String trackId) {
    _protectedSources.add(trackId);
    if (kDebugMode) {
      print('Protected audio source from cleanup: $trackId');
    }
  }
  
  /// Unprotect an audio source (allow cleanup)
  void unprotectAudioSource(String trackId) {
    _protectedSources.remove(trackId);
    if (kDebugMode) {
      print('Unprotected audio source: $trackId');
    }
  }
  
  /// Perform automatic cleanup of old, unreferenced sources
  Future<void> _performAutomaticCleanup() async {
    final now = DateTime.now();
    final cutoffTime = now.subtract(const Duration(minutes: 5));
    
    final toCleanup = <String>[];
    
    for (final entry in _audioSources.entries) {
      final trackId = entry.key;
      final source = entry.value;
      
      // Skip protected sources
      if (_protectedSources.contains(trackId)) {
        continue;
      }
      
      // Skip sources with references
      if (source.referenceCount > 0) {
        continue;
      }
      
      // Clean up old sources
      if (source.lastAccessed.isBefore(cutoffTime)) {
        toCleanup.add(trackId);
      }
    }
    
    for (final trackId in toCleanup) {
      final source = _audioSources[trackId];
      if (source != null) {
        await source.dispose();
        _audioSources.remove(trackId);
        
        if (kDebugMode) {
          print('Automatic cleanup of old audio source: $trackId');
        }
      }
    }
    
    if (kDebugMode && toCleanup.isNotEmpty) {
      print('Automatic cleanup completed: ${toCleanup.length} sources cleaned');
    }
  }
  
  /// Force cleanup of all unreferenced sources
  Future<void> forceCleanupUnreferenced() async {
    final toCleanup = <String>[];
    
    for (final entry in _audioSources.entries) {
      final trackId = entry.key;
      final source = entry.value;
      
      if (source.referenceCount <= 0 && !_protectedSources.contains(trackId)) {
        toCleanup.add(trackId);
      }
    }
    
    for (final trackId in toCleanup) {
      final source = _audioSources[trackId];
      if (source != null) {
        await source.dispose();
        _audioSources.remove(trackId);
      }
    }
    
    if (kDebugMode) {
      print('Force cleanup completed: ${toCleanup.length} sources cleaned');
    }
  }
  
  /// Get statistics about current audio sources
  Map<String, dynamic> getStatistics() {
    final stats = {
      'totalSources': _audioSources.length,
      'protectedSources': _protectedSources.length,
      'referencedSources': 0,
      'unreferencedSources': 0,
      'disposedSources': 0,
    };
    
    for (final source in _audioSources.values) {
      if (source.isDisposed) {
        stats['disposedSources'] = (stats['disposedSources'] as int) + 1;
      } else if (source.referenceCount > 0) {
        stats['referencedSources'] = (stats['referencedSources'] as int) + 1;
      } else {
        stats['unreferencedSources'] = (stats['unreferencedSources'] as int) + 1;
      }
    }
    
    return stats;
  }
  
  /// Dispose all audio sources (for complete cleanup)
  Future<void> disposeAll() async {
    _cleanupTimer?.cancel();
    
    final disposeFutures = _audioSources.values.map((source) => source.forceDispose());
    await Future.wait(disposeFutures);
    
    _audioSources.clear();
    _protectedSources.clear();
    
    if (kDebugMode) {
      print('Disposed all audio sources');
    }
  }
}