/// Audio Operation Queue - Thread-safe operation queue with locking
/// 
/// This file provides the operation queue that ensures all audio operations
/// are executed sequentially, preventing race conditions.
library;

import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'audio_state.dart';

/// A thread-safe operation queue for audio operations.
/// 
/// Ensures that only one operation runs at a time, with proper
/// timeout handling and cancellation support.
class AudioOperationQueue {
  /// Timeout for each operation
  final Duration timeout;
  
  /// Callback for operation errors
  final void Function(AudioError error) onError;
  
  /// Queue of pending operations
  final Queue<_QueuedOperation> _queue = Queue();
  
  /// Whether the queue is disposed
  bool _isDisposed = false;
  
  /// Lock to ensure sequential processing
  Completer<void>? _processingLock;

  AudioOperationQueue({
    required this.timeout,
    required this.onError,
  });

  /// Enqueue an operation for execution.
  /// 
  /// Returns the result of the operation.
  /// If an operation is already running, this will wait until it completes.
  Future<AudioResult<void>> enqueue(
    AudioOperationType type,
    Future<AudioResult<void>> Function() operation,
  ) async {
    if (_isDisposed) {
      return AudioResult.failure(AudioError(
        type: AudioErrorType.state,
        message: 'Operation queue is disposed',
        operation: type.name,
        timestamp: DateTime.now(),
      ));
    }
    
    final queuedOp = _QueuedOperation(
      id: _generateOperationId(),
      type: type,
      operation: operation,
      completer: Completer<AudioResult<void>>(),
      createdAt: DateTime.now(),
    );
    
    _queue.add(queuedOp);
    
    if (kDebugMode) {
      print('AudioOperationQueue: Enqueued ${type.name} (queue size: ${_queue.length})');
    }
    
    // Process queue (non-blocking)
    _processQueue();
    
    // Wait for this operation to complete
    return queuedOp.completer.future;
  }

  /// Cancel all pending operations.
  void cancelAll() {
    if (kDebugMode) {
      print('AudioOperationQueue: Cancelling all operations');
    }
    
    while (_queue.isNotEmpty) {
      final op = _queue.removeFirst();
      if (!op.completer.isCompleted) {
        op.completer.complete(AudioResult.failure(AudioError(
          type: AudioErrorType.state,
          message: 'Operation cancelled',
          operation: op.type.name,
          timestamp: DateTime.now(),
        )));
      }
    }
  }

  /// Dispose of the queue.
  Future<void> dispose() async {
    if (_isDisposed) return;
    
    if (kDebugMode) {
      print('AudioOperationQueue: Disposing');
    }
    
    _isDisposed = true;
    cancelAll();
    
    // Wait for current operation to complete
    if (_processingLock != null && !_processingLock!.isCompleted) {
      await _processingLock!.future.timeout(
        timeout,
        onTimeout: () {
          if (kDebugMode) {
            print('AudioOperationQueue: Timeout waiting for current operation');
          }
        },
      );
    }
  }

  /// Process the queue sequentially.
  Future<void> _processQueue() async {
    // Check if already processing
    if (_processingLock != null && !_processingLock!.isCompleted) {
      return;
    }
    
    if (_queue.isEmpty || _isDisposed) return;
    
    // Acquire lock
    _processingLock = Completer<void>();
    
    try {
      while (_queue.isNotEmpty && !_isDisposed) {
        final op = _queue.removeFirst();
        
        if (kDebugMode) {
          print('AudioOperationQueue: Processing ${op.type.name}');
        }
        
        try {
          // Execute with timeout
          final result = await op.operation().timeout(
            timeout,
            onTimeout: () {
              if (kDebugMode) {
                print('AudioOperationQueue: Operation ${op.type.name} timed out');
              }
              return AudioResult.failure(AudioError(
                type: AudioErrorType.timeout,
                message: 'Operation timed out after ${timeout.inSeconds} seconds',
                operation: op.type.name,
                timestamp: DateTime.now(),
              ));
            },
          );
          
          if (!op.completer.isCompleted) {
            op.completer.complete(result);
          }
          
          if (!result.isSuccess && result.error != null) {
            onError(result.error!);
          }
          
        } catch (e, stackTrace) {
          final error = AudioError.fromException(
            e,
            op.type.name,
            stackTrace: stackTrace,
          );
          
          if (!op.completer.isCompleted) {
            op.completer.complete(AudioResult.failure(error));
          }
          
          onError(error);
        }
        
        // Small delay between operations to prevent overwhelming
        if (_queue.isNotEmpty) {
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }
    } finally {
      _processingLock?.complete();
      _processingLock = null;
    }
  }

  /// Generate a unique operation ID
  String _generateOperationId() {
    return '${DateTime.now().microsecondsSinceEpoch}_${_queue.length}';
  }
}

/// Internal class representing a queued operation
class _QueuedOperation {
  final String id;
  final AudioOperationType type;
  final Future<AudioResult<void>> Function() operation;
  final Completer<AudioResult<void>> completer;
  final DateTime createdAt;

  _QueuedOperation({
    required this.id,
    required this.type,
    required this.operation,
    required this.completer,
    required this.createdAt,
  });
}

/// Debouncer for rapid user interactions.
/// 
/// Prevents multiple rapid calls from executing - only the last call
/// within the debounce period will execute.
class AudioDebouncer {
  final Duration debounceTime;
  Timer? _timer;
  Completer<void>? _pendingCompleter;

  AudioDebouncer({
    this.debounceTime = const Duration(milliseconds: 300),
  });

  /// Execute an action with debouncing.
  /// 
  /// If called multiple times within [debounceTime], only the last
  /// call will execute.
  Future<void> run(Future<void> Function() action) async {
    _timer?.cancel();
    
    // Complete any pending operation with cancellation
    if (_pendingCompleter != null && !_pendingCompleter!.isCompleted) {
      _pendingCompleter!.complete();
    }
    
    _pendingCompleter = Completer<void>();
    final completer = _pendingCompleter!;
    
    _timer = Timer(debounceTime, () async {
      if (!completer.isCompleted) {
        try {
          await action();
          completer.complete();
        } catch (e) {
          completer.completeError(e);
        }
      }
    });
    
    return completer.future;
  }

  /// Cancel any pending debounced action.
  void cancel() {
    _timer?.cancel();
    _timer = null;
    
    if (_pendingCompleter != null && !_pendingCompleter!.isCompleted) {
      _pendingCompleter!.complete();
    }
    _pendingCompleter = null;
  }

  /// Dispose of the debouncer.
  void dispose() {
    cancel();
  }
}

/// Throttler for rate-limiting operations.
/// 
/// Ensures operations don't execute more frequently than the specified interval.
class AudioThrottler {
  final Duration minInterval;
  DateTime? _lastExecution;
  bool _isPending = false;
  Future<void> Function()? _pendingAction;

  AudioThrottler({
    this.minInterval = const Duration(milliseconds: 100),
  });

  /// Execute an action with throttling.
  /// 
  /// If called too frequently, the action will be delayed until the
  /// minimum interval has passed.
  Future<void> run(Future<void> Function() action) async {
    final now = DateTime.now();
    
    if (_lastExecution == null || 
        now.difference(_lastExecution!) >= minInterval) {
      // Can execute immediately
      _lastExecution = now;
      await action();
    } else {
      // Need to wait
      if (!_isPending) {
        _isPending = true;
        _pendingAction = action;
        
        final waitTime = minInterval - now.difference(_lastExecution!);
        await Future.delayed(waitTime);
        
        if (_isPending && _pendingAction != null) {
          _lastExecution = DateTime.now();
          await _pendingAction!();
          _isPending = false;
          _pendingAction = null;
        }
      } else {
        // Replace pending action with new one
        _pendingAction = action;
      }
    }
  }

  /// Cancel any pending throttled action.
  void cancel() {
    _isPending = false;
    _pendingAction = null;
  }

  /// Dispose of the throttler.
  void dispose() {
    cancel();
  }
}
