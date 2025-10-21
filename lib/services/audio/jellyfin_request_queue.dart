import 'dart:async';
import 'dart:collection';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Request priority levels for adaptive processing
enum RequestPriority {
  high,     // User-initiated actions (play track, load playlist)
  normal,   // Standard operations (get albums, tracks)
  low,      // Background operations (sync favorites, metadata refresh)
}

/// Request types for specialized handling
enum RequestType {
  authentication,
  playback,        // Stream URLs, track data for immediate playback
  browsing,        // Albums, artists, playlists for UI
  metadata,        // Track details, images
  modification,    // Favorites, playlist edits
  background,      // Sync operations
}

/// Represents a queued API request with coordination metadata
class QueuedRequest {
  final String id;
  final RequestType type;
  final RequestPriority priority;
  final Future<Response> Function() operation;
  final Completer<Response> completer;
  final DateTime createdAt;
  final Duration timeout;
  final String description;

  QueuedRequest({
    required this.id,
    required this.type,
    required this.priority,
    required this.operation,
    required this.timeout,
    required this.description,
  }) : completer = Completer<Response>(),
       createdAt = DateTime.now();

  bool get isExpired => DateTime.now().difference(createdAt) > timeout;
}

/// Event types for request queue monitoring
enum RequestQueueEventType {
  requestQueued,
  requestStarted,
  requestCompleted,
  requestFailed,
  requestTimeout,
  queueOverflow,
}

/// Events emitted by the request queue for monitoring
class RequestQueueEvent {
  final RequestQueueEventType type;
  final String requestId;
  final RequestType requestType;
  final String message;
  final DateTime timestamp;

  RequestQueueEvent({
    required this.type,
    required this.requestId,
    required this.requestType,
    required this.message,
  }) : timestamp = DateTime.now();
}

/// Coordinates Jellyfin API requests to prevent timeout errors from concurrent operations
class JellyfinRequestQueue {
  // Configuration
  static const int maxConcurrentRequests = 4;
  static const int maxQueueSize = 50;
  static const Duration defaultTimeout = Duration(seconds: 30);
  
  // Request timeout configuration by type
  static const Map<RequestType, Duration> typeTimeouts = {
    RequestType.authentication: Duration(seconds: 20),
    RequestType.playback: Duration(seconds: 15),
    RequestType.browsing: Duration(seconds: 30),
    RequestType.metadata: Duration(seconds: 25),
    RequestType.modification: Duration(seconds: 20),
    RequestType.background: Duration(seconds: 45),
  };

  // State management
  final Queue<QueuedRequest> _queue = Queue<QueuedRequest>();
  final Set<QueuedRequest> _activeRequests = <QueuedRequest>{};
  final Set<String> _processingIds = <String>{};
  final Map<String, QueuedRequest> _duplicateMap = <String, QueuedRequest>{};

  // Event streaming
  final StreamController<RequestQueueEvent> _eventController = 
      StreamController<RequestQueueEvent>.broadcast();
  
  // Disposal state
  bool _disposed = false;
  Timer? _cleanupTimer;

  /// Stream of queue events for monitoring
  Stream<RequestQueueEvent> get events => _eventController.stream;

  /// Current queue statistics
  RequestQueueStats get stats => RequestQueueStats(
    queueSize: _queue.length,
    activeRequests: _activeRequests.length,
    maxConcurrent: maxConcurrentRequests,
    totalProcessing: _processingIds.length,
  );

  JellyfinRequestQueue() {
    _startPeriodicCleanup();
  }

  /// Start periodic cleanup of expired requests
  void _startPeriodicCleanup() {
    _cleanupTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _cleanupExpiredRequests();
    });
  }

  /// Queue a Jellyfin API request with coordination
  Future<Response> queueRequest({
    required String id,
    required RequestType type,
    required Future<Response> Function() operation,
    RequestPriority priority = RequestPriority.normal,
    String? description,
  }) async {
    if (_disposed) {
      throw StateError('Request queue has been disposed');
    }

    // Check for duplicate requests (deduplication)
    final duplicateKey = _generateDuplicateKey(id, type);
    if (_duplicateMap.containsKey(duplicateKey)) {
      final existingRequest = _duplicateMap[duplicateKey]!;
      _emitEvent(RequestQueueEventType.requestQueued, id, type, 
          'Returning existing request result');
      return existingRequest.completer.future;
    }

    // Check queue capacity
    if (_queue.length >= maxQueueSize) {
      _emitEvent(RequestQueueEventType.queueOverflow, id, type, 
          'Queue at capacity, rejecting request');
      throw StateError('Request queue is full');
    }

    // Create queued request
    final timeout = typeTimeouts[type] ?? defaultTimeout;
    final request = QueuedRequest(
      id: id,
      type: type,
      priority: priority,
      operation: operation,
      timeout: timeout,
      description: description ?? 'Jellyfin API request',
    );

    // Add to deduplication map
    _duplicateMap[duplicateKey] = request;

    // Add to queue (priority queue insertion)
    _insertByPriority(request);

    _emitEvent(RequestQueueEventType.requestQueued, id, type, 
        'Request queued (priority: ${priority.name})');

    // Process queue
    _processQueue();

    return request.completer.future;
  }

  /// Insert request into queue based on priority
  void _insertByPriority(QueuedRequest request) {
    if (_queue.isEmpty) {
      _queue.add(request);
      return;
    }

    // Convert to list for easier manipulation
    final list = _queue.toList();
    _queue.clear();

    // Find insertion point based on priority
    int insertIndex = list.length;
    for (int i = 0; i < list.length; i++) {
      if (_getPriorityValue(request.priority) > _getPriorityValue(list[i].priority)) {
        insertIndex = i;
        break;
      }
    }

    // Insert at the correct position
    list.insert(insertIndex, request);
    _queue.addAll(list);
  }

  /// Get numeric priority value for comparison
  int _getPriorityValue(RequestPriority priority) {
    switch (priority) {
      case RequestPriority.high:
        return 3;
      case RequestPriority.normal:
        return 2;
      case RequestPriority.low:
        return 1;
    }
  }

  /// Process the queue by starting available requests
  void _processQueue() {
    while (_activeRequests.length < maxConcurrentRequests && _queue.isNotEmpty) {
      final request = _queue.removeFirst();
      
      // Check if request expired while in queue
      if (request.isExpired) {
        _handleRequestTimeout(request);
        continue;
      }

      _startRequest(request);
    }
  }

  /// Start processing a single request
  void _startRequest(QueuedRequest request) {
    _activeRequests.add(request);
    _processingIds.add(request.id);

    _emitEvent(RequestQueueEventType.requestStarted, request.id, request.type, 
        'Starting request execution');

    // Execute the request with timeout handling
    _executeWithTimeout(request);
  }

  /// Execute request with proper timeout and error handling
  Future<void> _executeWithTimeout(QueuedRequest request) async {
    try {
      final response = await request.operation().timeout(request.timeout);
      
      _emitEvent(RequestQueueEventType.requestCompleted, request.id, request.type, 
          'Request completed successfully');
      
      request.completer.complete(response);
    } catch (e) {
      if (e is TimeoutException) {
        _handleRequestTimeout(request);
      } else {
        _emitEvent(RequestQueueEventType.requestFailed, request.id, request.type, 
            'Request failed: $e');
        request.completer.completeError(e);
      }
    } finally {
      _cleanupRequest(request);
      _processQueue(); // Process next requests
    }
  }

  /// Handle request timeout
  void _handleRequestTimeout(QueuedRequest request) {
    _emitEvent(RequestQueueEventType.requestTimeout, request.id, request.type, 
        'Request timed out after ${request.timeout.inSeconds}s');
    
    request.completer.completeError(
      TimeoutException('Request timed out', request.timeout)
    );
  }

  /// Clean up completed/failed request
  void _cleanupRequest(QueuedRequest request) {
    _activeRequests.remove(request);
    _processingIds.remove(request.id);
    
    // Remove from duplicate map
    final duplicateKey = _generateDuplicateKey(request.id, request.type);
    _duplicateMap.remove(duplicateKey);
  }

  /// Generate key for duplicate request detection
  String _generateDuplicateKey(String id, RequestType type) {
    return '${type.name}:$id';
  }

  /// Clean up expired requests from queue
  void _cleanupExpiredRequests() {
    if (_disposed) return;

    final now = DateTime.now();
    _queue.removeWhere((request) {
      if (request.isExpired) {
        _handleRequestTimeout(request);
        return true;
      }
      return false;
    });

    // Clean up old duplicate map entries
    _duplicateMap.removeWhere((key, request) => 
        now.difference(request.createdAt) > const Duration(minutes: 5));
  }

  /// Emit monitoring event
  void _emitEvent(RequestQueueEventType type, String requestId, 
                  RequestType requestType, String message) {
    if (!_disposed) {
      _eventController.add(RequestQueueEvent(
        type: type,
        requestId: requestId,
        requestType: requestType,
        message: message,
      ));
    }
  }

  /// Dispose the request queue
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    // Cancel cleanup timer
    _cleanupTimer?.cancel();

    // Complete all pending requests with error
    for (final request in _queue) {
      request.completer.completeError(
        StateError('Request queue disposed before processing')
      );
    }
    
    for (final request in _activeRequests) {
      request.completer.completeError(
        StateError('Request queue disposed during processing')
      );
    }

    // Clear all state
    _queue.clear();
    _activeRequests.clear();
    _processingIds.clear();
    _duplicateMap.clear();

    // Close event stream
    await _eventController.close();
  }
}

/// Statistics for request queue monitoring
class RequestQueueStats {
  final int queueSize;
  final int activeRequests;
  final int maxConcurrent;
  final int totalProcessing;

  const RequestQueueStats({
    required this.queueSize,
    required this.activeRequests,
    required this.maxConcurrent,
    required this.totalProcessing,
  });

  bool get isAtCapacity => activeRequests >= maxConcurrent;
  double get utilizationPercent => (activeRequests / maxConcurrent) * 100;

  @override
  String toString() {
    return 'RequestQueueStats(queue: $queueSize, active: $activeRequests/$maxConcurrent, '
           'utilization: ${utilizationPercent.toStringAsFixed(1)}%)';
  }
}