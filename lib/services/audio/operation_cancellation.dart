/// Operation cancellation system for preventing race conditions in audio operations
/// Provides cancellation tokens that can abort long-running operations when needed

import 'dart:async';

/// A cancellation token that can be used to cancel ongoing operations
class CancellationToken {
  final Completer<void> _cancellationCompleter = Completer<void>();
  bool _isCancelled = false;
  String? _reason;

  /// Whether this token has been cancelled
  bool get isCancelled => _isCancelled;

  /// The reason for cancellation (if any)
  String? get reason => _reason;

  /// Future that completes when this token is cancelled
  Future<void> get cancelled => _cancellationCompleter.future;

  /// Cancel this token with an optional reason
  void cancel([String? reason]) {
    if (_isCancelled) return;
    
    _isCancelled = true;
    _reason = reason;
    
    if (!_cancellationCompleter.isCompleted) {
      _cancellationCompleter.complete();
    }
  }

  /// Throw a cancellation exception if this token is cancelled
  void throwIfCancelled() {
    if (_isCancelled) {
      throw OperationCancelledException(_reason);
    }
  }

  /// Check cancellation and delay if not cancelled
  Future<void> delay(Duration duration) async {
    throwIfCancelled();
    
    // Use Future.any to allow cancellation during delay
    await Future.any([
      Future.delayed(duration),
      cancelled,
    ]);
    
    throwIfCancelled();
  }
}

/// Exception thrown when an operation is cancelled
class OperationCancelledException implements Exception {
  final String? reason;
  
  const OperationCancelledException([this.reason]);
  
  @override
  String toString() {
    if (reason != null) {
      return 'Operation cancelled: $reason';
    }
    return 'Operation cancelled';
  }
}

/// Manages cancellation tokens for different operation types
class OperationCancellationManager {
  final Map<String, CancellationToken> _activeTokens = {};

  /// Create a new cancellation token for an operation type
  /// Automatically cancels any existing token for the same operation type
  CancellationToken createToken(String operationType, [String? reason]) {
    // Cancel existing token for this operation type
    final existingToken = _activeTokens[operationType];
    if (existingToken != null && !existingToken.isCancelled) {
      existingToken.cancel(reason ?? 'Superseded by new $operationType operation');
    }

    // Create new token
    final newToken = CancellationToken();
    _activeTokens[operationType] = newToken;

    return newToken;
  }

  /// Get the current active token for an operation type (if any)
  CancellationToken? getActiveToken(String operationType) {
    final token = _activeTokens[operationType];
    if (token != null && !token.isCancelled) {
      return token;
    }
    return null;
  }

  /// Cancel all active tokens
  void cancelAll([String? reason]) {
    for (final token in _activeTokens.values) {
      if (!token.isCancelled) {
        token.cancel(reason ?? 'All operations cancelled');
      }
    }
    _activeTokens.clear();
  }

  /// Clean up completed/cancelled tokens
  void cleanup() {
    _activeTokens.removeWhere((_, token) => token.isCancelled);
  }

  /// Get count of active (non-cancelled) tokens
  int get activeTokenCount {
    return _activeTokens.values.where((token) => !token.isCancelled).length;
  }
}