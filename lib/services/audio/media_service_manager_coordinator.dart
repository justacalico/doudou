import 'dart:async';
import '../../models/jellyfin_models.dart';
import '../base_service.dart';
import '../media_service_manager.dart';

/// Synchronized wrapper for MediaServiceManager to prevent race conditions during disposal
/// and ensure proper cleanup sequencing during app termination
class MediaServiceManagerCoordinator {
  final MediaServiceManager _mediaServiceManager;
  bool _disposed = false;
  bool _disposing = false;
  final Completer<void> _readyCompleter = Completer<void>();
  final StreamController<MediaServiceEvent> _eventController = 
      StreamController<MediaServiceEvent>.broadcast();

  MediaServiceManagerCoordinator(this._mediaServiceManager) {
    _readyCompleter.complete();
  }

  /// Stream of coordination events for debugging and monitoring
  Stream<MediaServiceEvent> get eventStream => _eventController.stream;

  /// Ensure coordinator is ready
  Future<void> ensureReady() => _readyCompleter.future;

  /// Check if the manager is available for operations
  bool get isAvailable => !_disposed && !_disposing;

  /// Safely execute an operation with the media service manager
  Future<T?> executeOperation<T>(
    String operationName,
    Future<T> Function(MediaServiceManager manager) operation,
  ) async {
    if (_disposed || _disposing) {
      _eventController.add(MediaServiceEvent(
        type: MediaServiceEventType.operationBlocked,
        operation: operationName,
        message: 'Operation blocked - manager is disposed or disposing',
      ));
      return null;
    }

    await ensureReady();

    try {
      final result = await operation(_mediaServiceManager);
      _eventController.add(MediaServiceEvent(
        type: MediaServiceEventType.operationSuccess,
        operation: operationName,
        message: 'Operation completed successfully',
      ));
      return result;
    } catch (e) {
      _eventController.add(MediaServiceEvent(
        type: MediaServiceEventType.operationError,
        operation: operationName,
        message: 'Operation failed: $e',
      ));
      rethrow;
    }
  }

  /// Safely execute a synchronous operation with the media service manager
  T? executeSyncOperation<T>(
    String operationName,
    T Function(MediaServiceManager manager) operation,
  ) {
    if (_disposed || _disposing) {
      _eventController.add(MediaServiceEvent(
        type: MediaServiceEventType.operationBlocked,
        operation: operationName,
        message: 'Sync operation blocked - manager is disposed or disposing',
      ));
      return null;
    }

    try {
      final result = operation(_mediaServiceManager);
      _eventController.add(MediaServiceEvent(
        type: MediaServiceEventType.operationSuccess,
        operation: operationName,
        message: 'Sync operation completed successfully',
      ));
      return result;
    } catch (e) {
      _eventController.add(MediaServiceEvent(
        type: MediaServiceEventType.operationError,
        operation: operationName,
        message: 'Sync operation failed: $e',
      ));
      rethrow;
    }
  }

  /// Initialize service with coordination
  Future<void> initializeService(ServerType serverType) async {
    await executeOperation('initializeService', (manager) async {
      manager.initializeService(serverType);
    });
  }

  /// Authenticate with coordination
  Future<bool> authenticate(String serverUrl, String identifier, String credential) async {
    final result = await executeOperation('authenticate', (manager) async {
      return await manager.authenticate(serverUrl, identifier, credential);
    });
    return result ?? false;
  }

  /// Set server with coordination
  void setServer(String serverUrl) {
    executeSyncOperation('setServer', (manager) {
      manager.setServer(serverUrl);
    });
  }

  /// Validate credentials with coordination
  Future<bool> validateCredentials() async {
    final result = await executeOperation('validateCredentials', (manager) async {
      return await manager.validateCredentials();
    });
    return result ?? false;
  }

  /// Get libraries with coordination
  Future<List<Library>> getLibraries() async {
    final result = await executeOperation('getLibraries', (manager) async {
      return await manager.getLibraries();
    });
    return result ?? <Library>[];
  }

  /// Get stream URL with coordination
  String? getStreamUrl(String trackId, {int? bitrate}) {
    return executeSyncOperation('getStreamUrl', (manager) {
      return manager.getStreamUrl(trackId, bitrate: bitrate);
    });
  }

  /// Get alternative stream URLs with coordination
  List<String> getAlternativeStreamUrls(String trackId) {
    final result = executeSyncOperation('getAlternativeStreamUrls', (manager) {
      return manager.getAlternativeStreamUrls(trackId);
    });
    return result ?? <String>[];
  }

  /// Get tracks with coordination
  Future<List<Track>> getTracks({String? libraryId, String? parentId, int? limit, int? startIndex}) async {
    final result = await executeOperation('getTracks', (manager) async {
      return await manager.getTracks(
        libraryId: libraryId,
        parentId: parentId,
        limit: limit,
        startIndex: startIndex,
      );
    });
    return result ?? <Track>[];
  }

  /// Get playlist tracks with coordination
  Future<List<Track>> getPlaylistTracks(String playlistId) async {
    final result = await executeOperation('getPlaylistTracks', (manager) async {
      return await manager.getPlaylistTracks(playlistId);
    });
    return result ?? <Track>[];
  }

  /// Get albums with coordination
  Future<List<Album>> getAlbums({String? libraryId, int? limit, int? startIndex}) async {
    final result = await executeOperation('getAlbums', (manager) async {
      return await manager.getAlbums(
        libraryId: libraryId,
        limit: limit,
        startIndex: startIndex,
      );
    });
    return result ?? <Album>[];
  }

  /// Get current server type safely
  ServerType? get currentServerType {
    return executeSyncOperation('getCurrentServerType', (manager) {
      return manager.currentServerType;
    });
  }

  /// Get current service safely
  BaseMediaService? get currentService {
    if (_disposed || _disposing) {
      return null;
    }
    try {
      return _mediaServiceManager.currentService;
    } catch (e) {
      return null;
    }
  }

  /// Get coordination state for debugging
  MediaServiceCoordinationState get state {
    return MediaServiceCoordinationState(
      disposed: _disposed,
      disposing: _disposing,
      isAvailable: isAvailable,
    );
  }

  /// Dispose with proper cleanup sequencing
  Future<void> dispose() async {
    if (_disposed || _disposing) {
      return;
    }

    _disposing = true;
    _eventController.add(MediaServiceEvent(
      type: MediaServiceEventType.disposalStarted,
      operation: 'dispose',
      message: 'MediaServiceManager disposal started',
    ));

    try {
      // Clear authentication from current service
      final currentService = _mediaServiceManager.currentService;
      if (currentService != null) {
        try {
          currentService.clearAuth();
          _eventController.add(MediaServiceEvent(
            type: MediaServiceEventType.serviceCleared,
            operation: 'clearAuth',
            message: 'Current service authentication cleared',
          ));
        } catch (e) {
          _eventController.add(MediaServiceEvent(
            type: MediaServiceEventType.operationError,
            operation: 'clearAuth',
            message: 'Failed to clear service auth: $e',
          ));
        }
      }

      // Additional cleanup could be added here
      // (e.g., cancelling ongoing requests, clearing caches)

      _disposed = true;
      _eventController.add(MediaServiceEvent(
        type: MediaServiceEventType.disposalCompleted,
        operation: 'dispose',
        message: 'MediaServiceManager disposal completed',
      ));
    } catch (e) {
      _eventController.add(MediaServiceEvent(
        type: MediaServiceEventType.operationError,
        operation: 'dispose',
        message: 'Disposal failed: $e',
      ));
      rethrow;
    } finally {
      _disposing = false;
      await _eventController.close();
    }
  }
}

/// Events emitted by the media service coordinator
class MediaServiceEvent {
  final MediaServiceEventType type;
  final String operation;
  final String message;
  final DateTime timestamp;

  MediaServiceEvent({
    required this.type,
    required this.operation,
    required this.message,
  }) : timestamp = DateTime.now();

  @override
  String toString() {
    return 'MediaServiceEvent(${type.name}, $operation, $message, $timestamp)';
  }
}

/// Types of media service coordination events
enum MediaServiceEventType {
  operationSuccess,
  operationError,
  operationBlocked,
  disposalStarted,
  disposalCompleted,
  serviceCleared,
}

/// Current state of media service coordination
class MediaServiceCoordinationState {
  final bool disposed;
  final bool disposing;
  final bool isAvailable;

  const MediaServiceCoordinationState({
    required this.disposed,
    required this.disposing,
    required this.isAvailable,
  });

  @override
  String toString() {
    return 'MediaServiceCoordinationState('
        'disposed: $disposed, '
        'disposing: $disposing, '
        'isAvailable: $isAvailable'
        ')';
  }
}