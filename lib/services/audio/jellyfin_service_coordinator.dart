import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../jellyfin_service.dart';
import '../models/jellyfin_models.dart';
import 'jellyfin_request_queue.dart';

/// Event types for Jellyfin service coordination
enum JellyfinServiceEventType {
  requestQueued,
  requestCompleted,
  requestFailed,
  queueOverflow,
  serviceDisposed,
}

/// Events emitted by the Jellyfin service coordinator
class JellyfinServiceEvent {
  final JellyfinServiceEventType type;
  final String operation;
  final String message;
  final DateTime timestamp;

  JellyfinServiceEvent({
    required this.type,
    required this.operation,
    required this.message,
  }) : timestamp = DateTime.now();
}

/// Coordinates JellyfinService operations to prevent race conditions and timeout errors
class JellyfinServiceCoordinator {
  final JellyfinService _jellyfinService;
  final JellyfinRequestQueue _requestQueue;
  final StreamController<JellyfinServiceEvent> _eventController = 
      StreamController<JellyfinServiceEvent>.broadcast();

  bool _disposed = false;
  late StreamSubscription _queueEventsSubscription;

  /// Stream of coordination events for monitoring
  Stream<JellyfinServiceEvent> get events => _eventController.stream;

  /// Access to the underlying Jellyfin service (for methods that don't need coordination)
  JellyfinService get service => _jellyfinService;

  /// Current request queue statistics
  RequestQueueStats get queueStats => _requestQueue.stats;

  JellyfinServiceCoordinator(this._jellyfinService) 
      : _requestQueue = JellyfinRequestQueue() {
    _setupQueueEventListening();
  }

  /// Set up event forwarding from request queue
  void _setupQueueEventListening() {
    _queueEventsSubscription = _requestQueue.events.listen((event) {
      JellyfinServiceEventType coordinatorEventType;
      switch (event.type) {
        case RequestQueueEventType.requestQueued:
          coordinatorEventType = JellyfinServiceEventType.requestQueued;
          break;
        case RequestQueueEventType.requestCompleted:
          coordinatorEventType = JellyfinServiceEventType.requestCompleted;
          break;
        case RequestQueueEventType.requestFailed:
        case RequestQueueEventType.requestTimeout:
          coordinatorEventType = JellyfinServiceEventType.requestFailed;
          break;
        case RequestQueueEventType.queueOverflow:
          coordinatorEventType = JellyfinServiceEventType.queueOverflow;
          break;
        default:
          return; // Don't forward other event types
      }

      _emitEvent(coordinatorEventType, event.requestId, event.message);
    });
  }

  /// Get albums with request coordination
  Future<List<Album>> getAlbums({String? libraryId, int? limit, int? startIndex}) async {
    final requestId = 'getAlbums:${libraryId ?? 'all'}:$limit:$startIndex';
    
    try {
      final response = await _requestQueue.queueRequest(
        id: requestId,
        type: RequestType.browsing,
        priority: RequestPriority.normal,
        operation: () async {
          // Create a mock Dio response from the service method
          final albums = await _jellyfinService.getAlbums(
            libraryId: libraryId,
            limit: limit,
            startIndex: startIndex,
          );
          
          // Convert to Response for queue consistency
          return Response(
            requestOptions: RequestOptions(path: '/albums'),
            data: albums,
            statusCode: 200,
          );
        },
        description: 'Get albums from library ${libraryId ?? 'all'}',
      );
      
      return response.data as List<Album>;
    } catch (e) {
      if (kDebugMode) {
        print('JellyfinServiceCoordinator.getAlbums(): Error: $e');
      }
      return [];
    }
  }

  /// Get album tracks with request coordination
  Future<List<Track>> getAlbumTracks(String albumId) async {
    final requestId = 'getAlbumTracks:$albumId';
    
    try {
      final response = await _requestQueue.queueRequest(
        id: requestId,
        type: RequestType.browsing,
        priority: RequestPriority.normal,
        operation: () async {
          final tracks = await _jellyfinService.getAlbumTracks(albumId);
          return Response(
            requestOptions: RequestOptions(path: '/album-tracks'),
            data: tracks,
            statusCode: 200,
          );
        },
        description: 'Get tracks for album $albumId',
      );
      
      return response.data as List<Track>;
    } catch (e) {
      if (kDebugMode) {
        print('JellyfinServiceCoordinator.getAlbumTracks(): Error: $e');
      }
      return [];
    }
  }

  /// Get all tracks with request coordination
  Future<List<Track>> getAllTracks() async {
    const requestId = 'getAllTracks';
    
    try {
      final response = await _requestQueue.queueRequest(
        id: requestId,
        type: RequestType.browsing,
        priority: RequestPriority.low, // Large dataset, lower priority
        operation: () async {
          final tracks = await _jellyfinService.getAllTracks();
          return Response(
            requestOptions: RequestOptions(path: '/all-tracks'),
            data: tracks,
            statusCode: 200,
          );
        },
        description: 'Get all tracks from library',
      );
      
      return response.data as List<Track>;
    } catch (e) {
      if (kDebugMode) {
        print('JellyfinServiceCoordinator.getAllTracks(): Error: $e');
      }
      return [];
    }
  }

  /// Get tracks with request coordination
  Future<List<Track>> getTracks({String? libraryId, int? limit, int? startIndex}) async {
    final requestId = 'getTracks:${libraryId ?? 'all'}:$limit:$startIndex';
    
    try {
      final response = await _requestQueue.queueRequest(
        id: requestId,
        type: RequestType.browsing,
        priority: RequestPriority.normal,
        operation: () async {
          final tracks = await _jellyfinService.getTracks(
            libraryId: libraryId,
            limit: limit,
            startIndex: startIndex,
          );
          return Response(
            requestOptions: RequestOptions(path: '/tracks'),
            data: tracks,
            statusCode: 200,
          );
        },
        description: 'Get tracks from library ${libraryId ?? 'all'}',
      );
      
      return response.data as List<Track>;
    } catch (e) {
      if (kDebugMode) {
        print('JellyfinServiceCoordinator.getTracks(): Error: $e');
      }
      return [];
    }
  }

  /// Get artists with request coordination
  Future<List<Artist>> getArtists({String? libraryId, int? limit, int? startIndex}) async {
    final requestId = 'getArtists:${libraryId ?? 'all'}:$limit:$startIndex';
    
    try {
      final response = await _requestQueue.queueRequest(
        id: requestId,
        type: RequestType.browsing,
        priority: RequestPriority.normal,
        operation: () async {
          final artists = await _jellyfinService.getArtists(
            libraryId: libraryId,
            limit: limit,
            startIndex: startIndex,
          );
          return Response(
            requestOptions: RequestOptions(path: '/artists'),
            data: artists,
            statusCode: 200,
          );
        },
        description: 'Get artists from library ${libraryId ?? 'all'}',
      );
      
      return response.data as List<Artist>;
    } catch (e) {
      if (kDebugMode) {
        print('JellyfinServiceCoordinator.getArtists(): Error: $e');
      }
      return [];
    }
  }

  /// Get playlists with request coordination
  Future<List<Playlist>> getPlaylists() async {
    const requestId = 'getPlaylists';
    
    try {
      final response = await _requestQueue.queueRequest(
        id: requestId,
        type: RequestType.browsing,
        priority: RequestPriority.normal,
        operation: () async {
          final playlists = await _jellyfinService.getPlaylists();
          return Response(
            requestOptions: RequestOptions(path: '/playlists'),
            data: playlists,
            statusCode: 200,
          );
        },
        description: 'Get all playlists',
      );
      
      return response.data as List<Playlist>;
    } catch (e) {
      if (kDebugMode) {
        print('JellyfinServiceCoordinator.getPlaylists(): Error: $e');
      }
      return [];
    }
  }

  /// Get playlist tracks with request coordination
  Future<List<Track>> getPlaylistTracks(String playlistId) async {
    final requestId = 'getPlaylistTracks:$playlistId';
    
    try {
      final response = await _requestQueue.queueRequest(
        id: requestId,
        type: RequestType.browsing,
        priority: RequestPriority.normal,
        operation: () async {
          final tracks = await _jellyfinService.getPlaylistTracks(playlistId);
          return Response(
            requestOptions: RequestOptions(path: '/playlist-tracks'),
            data: tracks,
            statusCode: 200,
          );
        },
        description: 'Get tracks for playlist $playlistId',
      );
      
      return response.data as List<Track>;
    } catch (e) {
      if (kDebugMode) {
        print('JellyfinServiceCoordinator.getPlaylistTracks(): Error: $e');
      }
      return [];
    }
  }

  /// Get libraries with request coordination
  Future<List<Library>> getLibraries() async {
    const requestId = 'getLibraries';
    
    try {
      final response = await _requestQueue.queueRequest(
        id: requestId,
        type: RequestType.browsing,
        priority: RequestPriority.normal,
        operation: () async {
          final libraries = await _jellyfinService.getLibraries();
          return Response(
            requestOptions: RequestOptions(path: '/libraries'),
            data: libraries,
            statusCode: 200,
          );
        },
        description: 'Get all libraries',
      );
      
      return response.data as List<Library>;
    } catch (e) {
      if (kDebugMode) {
        print('JellyfinServiceCoordinator.getLibraries(): Error: $e');
      }
      return [];
    }
  }

  /// Authentication with high priority coordination
  Future<bool> authenticate(String serverUrl, String username, String password) async {
    final requestId = 'authenticate:$serverUrl:$username';
    
    try {
      final response = await _requestQueue.queueRequest(
        id: requestId,
        type: RequestType.authentication,
        priority: RequestPriority.high, // High priority for user interaction
        operation: () async {
          final result = await _jellyfinService.authenticate(serverUrl, username, password);
          return Response(
            requestOptions: RequestOptions(path: '/auth'),
            data: result,
            statusCode: 200,
          );
        },
        description: 'Authenticate user $username',
      );
      
      return response.data as bool;
    } catch (e) {
      if (kDebugMode) {
        print('JellyfinServiceCoordinator.authenticate(): Error: $e');
      }
      return false;
    }
  }

  /// Toggle favorite with modification priority
  Future<bool> toggleFavorite(String itemId, bool isFavorite) async {
    final requestId = 'toggleFavorite:$itemId:$isFavorite';
    
    try {
      final response = await _requestQueue.queueRequest(
        id: requestId,
        type: RequestType.modification,
        priority: RequestPriority.normal,
        operation: () async {
          final result = await _jellyfinService.toggleFavorite(itemId, isFavorite);
          return Response(
            requestOptions: RequestOptions(path: '/favorite'),
            data: result,
            statusCode: 200,
          );
        },
        description: 'Toggle favorite for item $itemId',
      );
      
      return response.data as bool;
    } catch (e) {
      if (kDebugMode) {
        print('JellyfinServiceCoordinator.toggleFavorite(): Error: $e');
      }
      return false;
    }
  }

  /// Direct access to non-coordinated methods (for immediate access like stream URLs)
  String getStreamUrl(String trackId) => _jellyfinService.getStreamUrl(trackId);
  String getDirectStreamUrl(String trackId) => _jellyfinService.getDirectStreamUrl(trackId);
  String getUniversalStreamUrl(String trackId) => _jellyfinService.getUniversalStreamUrl(trackId);
  List<String> getAlternativeStreamUrls(String trackId) => _jellyfinService.getAlternativeStreamUrls(trackId);
  String getImageUrl(String itemId, {int? width, int? height}) => 
      _jellyfinService.getImageUrl(itemId, width: width, height: height);

  /// Emit coordination event
  void _emitEvent(JellyfinServiceEventType type, String operation, String message) {
    if (!_disposed) {
      _eventController.add(JellyfinServiceEvent(
        type: type,
        operation: operation,
        message: message,
      ));
    }
  }

  /// Dispose coordinator and clean up resources
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    _emitEvent(JellyfinServiceEventType.serviceDisposed, 'dispose', 
               'Jellyfin service coordinator disposed');

    await _queueEventsSubscription.cancel();
    await _requestQueue.dispose();
    await _eventController.close();
  }
}