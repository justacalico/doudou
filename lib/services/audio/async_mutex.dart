import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

/// Async mutex implementation to replace custom spinlocks
/// Provides proper async synchronization without busy-waiting
class AsyncMutex {
  Completer<void>? _completer;
  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();
  
  /// Acquire the mutex lock
  /// Returns immediately if available, otherwise waits asynchronously
  Future<void> acquire() async {
    if (_completer == null) {
      // Mutex is free, claim it immediately
      _completer = Completer<void>();
      return;
    }
    
    // Mutex is busy, add ourselves to the wait queue
    final waiter = Completer<void>();
    _waitQueue.add(waiter);
    
    // Wait for our turn
    await waiter.future;
  }

  /// Release the mutex lock
  void release() {
    if (_waitQueue.isNotEmpty) {
      // Wake up the next waiter and give them the lock
      final nextWaiter = _waitQueue.removeFirst();
      nextWaiter.complete();
    } else {
      // No one waiting, release the lock completely
      _completer?.complete();
      _completer = null;
    }
  }  /// Check if the mutex is currently locked
  bool get isLocked => _completer != null && !_completer!.isCompleted;
  
  /// Execute a function with the mutex locked with timeout protection
  Future<T> withLock<T>(Future<T> Function() operation, [String? debugName]) async {
    final name = debugName ?? 'unknown';
    if (kDebugMode) {
      print('AsyncMutex($name): Attempting to acquire lock...');
    }
    
    // Add timeout protection to prevent infinite waiting
    await acquire().timeout(
      Duration(seconds: 10),
      onTimeout: () {
        // Force release and log error
        if (kDebugMode) {
          print('AsyncMutex($name): TIMEOUT acquiring lock, forcing release');
        }
        _completer?.complete();
        _completer = null;
        throw TimeoutException('Mutex acquisition timeout', Duration(seconds: 10));
      },
    );
    
    if (kDebugMode) {
      print('AsyncMutex($name): Successfully acquired lock');
    }
    
    try {
      final result = await operation();
      if (kDebugMode) {
        print('AsyncMutex($name): Operation completed successfully');
      }
      return result;
    } catch (error) {
      if (kDebugMode) {
        print('AsyncMutex($name): Operation failed with error: $error');
      }
      rethrow;
    } finally {
      release();
      if (kDebugMode) {
        print('AsyncMutex($name): Lock released');
      }
    }
  }
}

/// Named mutex manager for multiple concurrent locks
class NamedMutexManager {
  final Map<String, AsyncMutex> _mutexes = {};
  
  /// Get or create a mutex for the given name
  AsyncMutex _getMutex(String name) {
    return _mutexes.putIfAbsent(name, () => AsyncMutex());
  }
  
  /// Execute operation with named lock
  Future<T> withLock<T>(String lockName, Future<T> Function() operation) async {
    final mutex = _getMutex(lockName);
    return await mutex.withLock(operation, lockName);
  }
  
  /// Check if a specific lock is currently held
  bool isLocked(String lockName) {
    return _mutexes[lockName]?.isLocked ?? false;
  }
  
  /// Clear all mutexes (for cleanup)
  void clearAll() {
    for (final mutex in _mutexes.values) {
      if (mutex.isLocked) {
        mutex.release();
      }
    }
    _mutexes.clear();
  }
}