import 'dart:async';
import 'dart:io';
import '../download_service.dart';
import '../../models/jellyfin_models.dart';
import '../../models/download_models.dart';

/// Coordinates download service operations with audio playback to prevent race conditions
/// Ensures download operations don't interfere with active audio streaming
class DownloadServiceCoordinator {
  final DownloadService _downloadService;
  final Set<String> _activeStreamingTracks = {};
  final Set<String> _protectedTracks = {};
  bool _disposed = false;
  
  // Synchronization for download operations
  final Completer<void> _readyCompleter = Completer<void>();
  final StreamController<DownloadCoordinationEvent> _eventController = 
      StreamController<DownloadCoordinationEvent>.broadcast();

  DownloadServiceCoordinator(this._downloadService) {
    _readyCompleter.complete();
  }

  /// Stream of coordination events for debugging and monitoring
  Stream<DownloadCoordinationEvent> get eventStream => _eventController.stream;

  /// Ensure coordinator is ready
  Future<void> ensureReady() => _readyCompleter.future;

  /// Mark a track as actively streaming to protect it from modification
  Future<void> markTrackAsStreaming(String trackId) async {
    if (_disposed) return;
    
    await ensureReady();
    _activeStreamingTracks.add(trackId);
    _protectedTracks.add(trackId);
    
    _eventController.add(DownloadCoordinationEvent(
      type: DownloadCoordinationEventType.trackProtected,
      trackId: trackId,
      message: 'Track marked as actively streaming',
    ));
  }

  /// Unmark a track as streaming, but keep it protected briefly
  Future<void> unmarkTrackAsStreaming(String trackId) async {
    if (_disposed) return;
    
    await ensureReady();
    _activeStreamingTracks.remove(trackId);
    
    // Keep track protected for a short time to prevent immediate deletion
    Timer(const Duration(seconds: 2), () {
      _protectedTracks.remove(trackId);
      _eventController.add(DownloadCoordinationEvent(
        type: DownloadCoordinationEventType.trackUnprotected,
        trackId: trackId,
        message: 'Track protection removed after delay',
      ));
    });
    
    _eventController.add(DownloadCoordinationEvent(
      type: DownloadCoordinationEventType.trackStreamingEnded,
      trackId: trackId,
      message: 'Track no longer actively streaming',
    ));
  }

  /// Safely get local file path with streaming coordination
  Future<String?> getLocalFilePath(String trackId) async {
    if (_disposed) return null;
    
    await ensureReady();
    
    try {
      final filePath = _downloadService.getLocalFilePath(trackId);
      
      if (filePath != null) {
        // Verify file still exists and is accessible
        final file = File(filePath);
        if (await file.exists()) {
          return filePath;
        } else {
          // File was deleted, clean up download service state
          _eventController.add(DownloadCoordinationEvent(
            type: DownloadCoordinationEventType.fileNotFound,
            trackId: trackId,
            message: 'Local file no longer exists: $filePath',
          ));
          return null;
        }
      }
      
      return null;
    } catch (e) {
      _eventController.add(DownloadCoordinationEvent(
        type: DownloadCoordinationEventType.error,
        trackId: trackId,
        message: 'Error getting local file path: $e',
      ));
      return null;
    }
  }

  /// Safely start download with streaming coordination
  Future<bool> downloadTrack(Track track) async {
    if (_disposed) return false;
    
    await ensureReady();
    
    // Check if track is currently streaming
    if (_activeStreamingTracks.contains(track.id)) {
      _eventController.add(DownloadCoordinationEvent(
        type: DownloadCoordinationEventType.downloadBlocked,
        trackId: track.id,
        message: 'Download blocked - track is actively streaming',
      ));
      return false;
    }

    try {
      await _downloadService.downloadTrack(track);
      _eventController.add(DownloadCoordinationEvent(
        type: DownloadCoordinationEventType.downloadStarted,
        trackId: track.id,
        message: 'Download started for track: ${track.name}',
      ));
      return true;
    } catch (e) {
      _eventController.add(DownloadCoordinationEvent(
        type: DownloadCoordinationEventType.error,
        trackId: track.id,
        message: 'Download failed: $e',
      ));
      return false;
    }
  }

  /// Safely cancel download with coordination
  Future<bool> cancelDownload(String trackId) async {
    if (_disposed) return false;
    
    await ensureReady();

    try {
      await _downloadService.cancelDownload(trackId);
      _eventController.add(DownloadCoordinationEvent(
        type: DownloadCoordinationEventType.downloadCancelled,
        trackId: trackId,
        message: 'Download cancelled',
      ));
      return true;
    } catch (e) {
      _eventController.add(DownloadCoordinationEvent(
        type: DownloadCoordinationEventType.error,
        trackId: trackId,
        message: 'Cancel download failed: $e',
      ));
      return false;
    }
  }

  /// Safely delete download with streaming protection
  Future<bool> deleteDownload(String trackId) async {
    if (_disposed) return false;
    
    await ensureReady();
    
    // Prevent deletion of protected tracks
    if (_protectedTracks.contains(trackId)) {
      _eventController.add(DownloadCoordinationEvent(
        type: DownloadCoordinationEventType.deleteBlocked,
        trackId: trackId,
        message: 'Delete blocked - track is protected (recently streamed)',
      ));
      return false;
    }

    try {
      await _downloadService.deleteDownload(trackId);
      _eventController.add(DownloadCoordinationEvent(
        type: DownloadCoordinationEventType.downloadDeleted,
        trackId: trackId,
        message: 'Download deleted',
      ));
      return true;
    } catch (e) {
      _eventController.add(DownloadCoordinationEvent(
        type: DownloadCoordinationEventType.error,
        trackId: trackId,
        message: 'Delete download failed: $e',
      ));
      return false;
    }
  }

  /// Clear all downloads with streaming protection
  Future<bool> clearAllDownloads() async {
    if (_disposed) return false;
    
    await ensureReady();
    
    // Don't clear if any tracks are protected
    if (_protectedTracks.isNotEmpty) {
      _eventController.add(DownloadCoordinationEvent(
        type: DownloadCoordinationEventType.clearBlocked,
        trackId: null,
        message: 'Clear all blocked - ${_protectedTracks.length} protected tracks',
      ));
      return false;
    }

    try {
      await _downloadService.clearAllDownloads();
      _eventController.add(DownloadCoordinationEvent(
        type: DownloadCoordinationEventType.allDownloadsCleared,
        trackId: null,
        message: 'All downloads cleared',
      ));
      return true;
    } catch (e) {
      _eventController.add(DownloadCoordinationEvent(
        type: DownloadCoordinationEventType.error,
        trackId: null,
        message: 'Clear all downloads failed: $e',
      ));
      return false;
    }
  }

  /// Check if track is downloaded (passthrough)
  bool isTrackDownloaded(String trackId) {
    return _downloadService.isTrackDownloaded(trackId);
  }

  /// Get download status (passthrough)
  DownloadStatus getDownloadStatus(String trackId) {
    return _downloadService.getDownloadStatus(trackId);
  }

  /// Get coordination state for debugging
  DownloadCoordinationState get state {
    return DownloadCoordinationState(
      activeStreamingTracks: Set.from(_activeStreamingTracks),
      protectedTracks: Set.from(_protectedTracks),
      disposed: _disposed,
    );
  }

  /// Force cleanup of protection for a specific track (emergency use)
  void forceUnprotectTrack(String trackId) {
    _activeStreamingTracks.remove(trackId);
    _protectedTracks.remove(trackId);
    _eventController.add(DownloadCoordinationEvent(
      type: DownloadCoordinationEventType.trackForceUnprotected,
      trackId: trackId,
      message: 'Track protection forcibly removed',
    ));
  }

  /// Dispose resources
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    // Clear all protections
    _activeStreamingTracks.clear();
    _protectedTracks.clear();
    
    // Close event stream
    await _eventController.close();
  }
}

/// Events emitted by the download service coordinator
class DownloadCoordinationEvent {
  final DownloadCoordinationEventType type;
  final String? trackId;
  final String message;
  final DateTime timestamp;

  DownloadCoordinationEvent({
    required this.type,
    required this.trackId,
    required this.message,
  }) : timestamp = DateTime.now();

  @override
  String toString() {
    return 'DownloadCoordinationEvent(${type.name}, $trackId, $message, $timestamp)';
  }
}

/// Types of coordination events
enum DownloadCoordinationEventType {
  trackProtected,
  trackUnprotected,
  trackStreamingEnded,
  trackForceUnprotected,
  downloadBlocked,
  downloadStarted,
  downloadCancelled,
  downloadDeleted,
  deleteBlocked,
  clearBlocked,
  allDownloadsCleared,
  fileNotFound,
  error,
}

/// Current state of download coordination
class DownloadCoordinationState {
  final Set<String> activeStreamingTracks;
  final Set<String> protectedTracks;
  final bool disposed;

  const DownloadCoordinationState({
    required this.activeStreamingTracks,
    required this.protectedTracks,
    required this.disposed,
  });

  @override
  String toString() {
    return 'DownloadCoordinationState('
        'streaming: ${activeStreamingTracks.length}, '
        'protected: ${protectedTracks.length}, '
        'disposed: $disposed'
        ')';
  }
}