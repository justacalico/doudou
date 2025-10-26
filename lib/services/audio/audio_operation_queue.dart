import 'dart:async';
import 'dart:collection';

/// Operation queue to prevent concurrent AudioPlayer operations
/// Ensures setAudioSource, stop, play calls are executed sequentially
class AudioOperationQueue {
  final Queue<_QueuedOperation> _operations = Queue();
  bool _processing = false;
  Completer<void>? _processingCompleter;
  
  /// Enqueue an async operation to be executed sequentially
  Future<T> enqueue<T>(String operationName, Future<T> Function() operation) async {
    final completer = Completer<T>();
    final queuedOp = _QueuedOperation<T>(
      name: operationName,
      operation: operation,
      completer: completer,
    );
    
    _operations.add(queuedOp);
    _processQueue();
    
    return completer.future;
  }
  
  /// Process the operation queue sequentially
  void _processQueue() async {
    if (_processing || _operations.isEmpty) return;
    
    _processing = true;
    _processingCompleter = Completer<void>();
    
    while (_operations.isNotEmpty) {
      final operation = _operations.removeFirst();
      
      try {
        final result = await operation.operation();
        operation.completer.complete(result);
      } catch (e, stackTrace) {
        operation.completer.completeError(e, stackTrace);
      }
    }
    
    _processing = false;
    _processingCompleter?.complete();
    _processingCompleter = null;
  }
  
  /// Wait for all current operations to complete
  Future<void> waitForCompletion() async {
    if (_processing && _processingCompleter != null) {
      await _processingCompleter!.future;
    }
  }
  
  /// Clear all pending operations (for emergency stop)
  void clearPending() {
    while (_operations.isNotEmpty) {
      final operation = _operations.removeFirst();
      operation.completer.completeError(
        StateError('Operation cancelled: ${operation.name}')
      );
    }
  }
  
  /// Get the current queue size
  int get queueSize => _operations.length;
  
  /// Check if queue is currently processing
  bool get isProcessing => _processing;
}

/// Internal class to represent a queued operation
class _QueuedOperation<T> {
  final String name;
  final Future<T> Function() operation;
  final Completer<T> completer;
  
  _QueuedOperation({
    required this.name,
    required this.operation,
    required this.completer,
  });
}