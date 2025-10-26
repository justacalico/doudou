import 'dart:async';
import 'package:flutter/foundation.dart';

/// Error categories for specialized handling
enum ErrorCategory {
  network,           // Network connectivity, timeouts, server errors
  authentication,    // Auth failures, token expiry
  playback,         // Audio playback failures, codec issues
  storage,          // File system, download, cache issues
  system,           // Platform-specific, permission issues
  unknown,          // Unclassified errors
}

/// Error severity levels for prioritization
enum ErrorSeverity {
  critical,    // App-breaking errors that require immediate attention
  high,        // Errors that significantly impact functionality
  medium,      // Errors that impact some features
  low,         // Minor errors or warnings
}

/// Error resolution strategies
enum ErrorResolution {
  retry,              // Retry the operation
  fallback,           // Use alternative approach
  userIntervention,   // Require user action
  ignore,             // Log and continue
  restart,            // Restart component/service
}

/// Represents a managed error with coordination metadata
class ManagedError {
  final String id;
  final String component;
  final ErrorCategory category;
  final ErrorSeverity severity;
  final String message;
  final dynamic originalError;
  final StackTrace? stackTrace;
  final DateTime timestamp;
  final Map<String, dynamic> context;
  final ErrorResolution suggestedResolution;

  bool _resolved = false;
  String? _resolutionMessage;

  ManagedError({
    required this.id,
    required this.component,
    required this.category,
    required this.severity,
    required this.message,
    required this.originalError,
    this.stackTrace,
    Map<String, dynamic>? context,
    this.suggestedResolution = ErrorResolution.ignore,
  }) : timestamp = DateTime.now(),
       context = context ?? <String, dynamic>{};

  bool get isResolved => _resolved;
  String? get resolutionMessage => _resolutionMessage;

  void markResolved(String resolutionMessage) {
    _resolved = true;
    _resolutionMessage = resolutionMessage;
  }

  bool get isExpired => DateTime.now().difference(timestamp) > const Duration(minutes: 10);

  @override
  String toString() => 'ManagedError($component/$category: $message)';
}

/// Event types for error state management
enum ErrorStateEventType {
  errorOccurred,
  errorResolved,
  errorEscalated,
  errorIgnored,
  stateCleared,
}

/// Events emitted by the error state manager
class ErrorStateEvent {
  final ErrorStateEventType type;
  final ManagedError? error;
  final String message;
  final DateTime timestamp;

  ErrorStateEvent({
    required this.type,
    this.error,
    required this.message,
  }) : timestamp = DateTime.now();
}

/// Manages error states across the audio system to prevent conflicting error handling
class ErrorStateManager {
  // Active errors by component
  final Map<String, List<ManagedError>> _activeErrors = <String, List<ManagedError>>{};
  
  // Global error state
  final Map<ErrorCategory, ManagedError> _latestByCategory = <ErrorCategory, ManagedError>{};
  
  // Error suppression for rate limiting
  final Map<String, DateTime> _suppressionMap = <String, DateTime>{};
  
  // Event streaming
  final StreamController<ErrorStateEvent> _eventController = 
      StreamController<ErrorStateEvent>.broadcast();
  
  // Cleanup timer
  Timer? _cleanupTimer;
  bool _disposed = false;

  static const Duration suppressionWindow = Duration(seconds: 30);
  static const int maxErrorsPerComponent = 10;

  /// Stream of error state events for monitoring
  Stream<ErrorStateEvent> get events => _eventController.stream;

  /// Current error statistics
  ErrorStateStats get stats => ErrorStateStats(
    totalActiveErrors: _activeErrors.values.fold(0, (sum, list) => sum + list.length),
    componentCount: _activeErrors.keys.length,
    categoriesWithErrors: _latestByCategory.keys.toSet(),
    criticalErrors: _getAllActiveErrors().where((e) => e.severity == ErrorSeverity.critical).length,
  );

  /// Check if component has active errors
  bool hasErrors(String component) => _activeErrors.containsKey(component) && 
                                      _activeErrors[component]!.isNotEmpty;

  /// Check if system has critical errors
  bool get hasCriticalErrors => _getAllActiveErrors().any((e) => e.severity == ErrorSeverity.critical);

  /// Get latest error for category
  ManagedError? getLatestError(ErrorCategory category) => _latestByCategory[category];

  ErrorStateManager() {
    _startPeriodicCleanup();
  }

  /// Start periodic cleanup of resolved and expired errors
  void _startPeriodicCleanup() {
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _cleanupErrors();
    });
  }

  /// Report an error with coordination
  void reportError({
    required String component,
    required ErrorCategory category,
    required ErrorSeverity severity,
    required String message,
    required dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
    ErrorResolution? suggestedResolution,
  }) {
    if (_disposed) return;

    final errorId = _generateErrorId(component, category, message);
    
    // Check suppression to prevent error spam
    if (_isSuppressed(errorId)) {
      return;
    }

    final managedError = ManagedError(
      id: errorId,
      component: component,
      category: category,
      severity: severity,
      message: message,
      originalError: error,
      stackTrace: stackTrace,
      context: context,
      suggestedResolution: suggestedResolution ?? _getDefaultResolution(category, severity),
    );

    // Add to active errors
    _activeErrors.putIfAbsent(component, () => <ManagedError>[]);
    
    // Limit errors per component to prevent memory leaks
    if (_activeErrors[component]!.length >= maxErrorsPerComponent) {
      _activeErrors[component]!.removeAt(0); // Remove oldest
    }
    
    _activeErrors[component]!.add(managedError);

    // Update latest by category
    _latestByCategory[category] = managedError;

    // Add to suppression map
    _suppressionMap[errorId] = DateTime.now();

    // Emit event
    _emitEvent(ErrorStateEventType.errorOccurred, managedError, 
               'Error reported in $component: $message');

    // Debug logging
    if (kDebugMode) {
      print('ErrorStateManager: [$component/${category.name}/${severity.name}] $message');
      if (severity == ErrorSeverity.critical) {
        print('ErrorStateManager: CRITICAL ERROR - $error');
      }
    }
  }

  /// Execute operation with centralized error handling
  Future<T> executeWithErrorHandling<T>({
    required String component,
    required String operation,
    required Future<T> Function() action,
    ErrorCategory category = ErrorCategory.unknown,
    ErrorSeverity severity = ErrorSeverity.medium,
    T? fallbackValue,
    Map<String, dynamic>? context,
  }) async {
    try {
      final result = await action();
      
      // Clear any previous errors for this operation
      _clearComponentErrors(component, operation);
      
      return result;
    } catch (error, stackTrace) {
      reportError(
        component: component,
        category: category,
        severity: severity,
        message: 'Operation "$operation" failed',
        error: error,
        stackTrace: stackTrace,
        context: {
          'operation': operation,
          ...?context,
        },
      );

      if (fallbackValue != null) {
        return fallbackValue;
      }
      
      rethrow;
    }
  }

  /// Execute operation with error recovery
  Future<T?> executeWithRecovery<T>({
    required String component,
    required String operation,
    required Future<T> Function() action,
    Future<T> Function()? fallbackAction,
    ErrorCategory category = ErrorCategory.unknown,
    int maxRetries = 2,
    Duration retryDelay = const Duration(seconds: 1),
  }) async {
    int attempts = 0;
    
    while (attempts <= maxRetries) {
      try {
        final result = await action();
        
        // Clear errors on success
        if (attempts > 0) {
          _resolveComponentErrors(component, operation, 'Recovered after $attempts attempts');
        }
        
        return result;
      } catch (error, stackTrace) {
        attempts++;
        
        if (attempts <= maxRetries) {
          reportError(
            component: component,
            category: category,
            severity: ErrorSeverity.low,
            message: 'Operation "$operation" failed, retrying ($attempts/$maxRetries)',
            error: error,
            stackTrace: stackTrace,
            context: {'attempt': attempts, 'maxRetries': maxRetries},
            suggestedResolution: ErrorResolution.retry,
          );
          
          await Future.delayed(retryDelay);
        } else {
          // Final failure
          reportError(
            component: component,
            category: category,
            severity: ErrorSeverity.high,
            message: 'Operation "$operation" failed after $maxRetries retries',
            error: error,
            stackTrace: stackTrace,
            context: {'finalAttempt': true, 'totalAttempts': attempts},
            suggestedResolution: fallbackAction != null ? ErrorResolution.fallback : ErrorResolution.userIntervention,
          );
          
          // Try fallback if available
          if (fallbackAction != null) {
            try {
              final result = await fallbackAction();
              _resolveComponentErrors(component, operation, 'Fallback action succeeded');
              return result;
            } catch (fallbackError) {
              reportError(
                component: component,
                category: category,
                severity: ErrorSeverity.critical,
                message: 'Fallback action also failed for "$operation"',
                error: fallbackError,
                context: {'fallbackFailed': true},
                suggestedResolution: ErrorResolution.userIntervention,
              );
            }
          }
          
          return null;
        }
      }
    }
    
    return null;
  }

  /// Resolve specific error
  void resolveError(String errorId, String resolutionMessage) {
    bool found = false;
    
    for (final componentErrors in _activeErrors.values) {
      for (final error in componentErrors) {
        if (error.id == errorId && !error.isResolved) {
          error.markResolved(resolutionMessage);
          found = true;
          
          _emitEvent(ErrorStateEventType.errorResolved, error, 
                     'Error resolved: $resolutionMessage');
          break;
        }
      }
      if (found) break;
    }
  }

  /// Clear all errors for a component
  void clearComponentErrors(String component, {String? reason}) {
    if (_activeErrors.containsKey(component)) {
      final count = _activeErrors[component]!.length;
      _activeErrors[component]!.clear();
      
      _emitEvent(ErrorStateEventType.stateCleared, null, 
                 'Cleared $count errors for component $component${reason != null ? ': $reason' : ''}');
    }
  }

  /// Clear errors for specific operation within component
  void _clearComponentErrors(String component, String operation) {
    if (_activeErrors.containsKey(component)) {
      _activeErrors[component]!.removeWhere((error) => 
          error.context['operation'] == operation);
    }
  }

  /// Resolve errors for specific operation within component
  void _resolveComponentErrors(String component, String operation, String resolutionMessage) {
    if (_activeErrors.containsKey(component)) {
      for (final error in _activeErrors[component]!) {
        if (error.context['operation'] == operation && !error.isResolved) {
          error.markResolved(resolutionMessage);
          
          _emitEvent(ErrorStateEventType.errorResolved, error, 
                     'Operation error resolved: $resolutionMessage');
        }
      }
    }
  }

  /// Check if error should be suppressed
  bool _isSuppressed(String errorId) {
    final lastOccurrence = _suppressionMap[errorId];
    if (lastOccurrence == null) return false;
    
    return DateTime.now().difference(lastOccurrence) < suppressionWindow;
  }

  /// Generate unique error ID
  String _generateErrorId(String component, ErrorCategory category, String message) {
    final hash = '$component:${category.name}:${message.hashCode}';
    return hash;
  }

  /// Get default resolution strategy
  ErrorResolution _getDefaultResolution(ErrorCategory category, ErrorSeverity severity) {
    if (severity == ErrorSeverity.critical) {
      return ErrorResolution.userIntervention;
    }
    
    switch (category) {
      case ErrorCategory.network:
        return ErrorResolution.retry;
      case ErrorCategory.authentication:
        return ErrorResolution.userIntervention;
      case ErrorCategory.playback:
        return ErrorResolution.fallback;
      case ErrorCategory.storage:
        return ErrorResolution.retry;
      case ErrorCategory.system:
        return ErrorResolution.userIntervention;
      case ErrorCategory.unknown:
        return ErrorResolution.ignore;
    }
  }

  /// Get all active errors across components
  List<ManagedError> _getAllActiveErrors() {
    final allErrors = <ManagedError>[];
    for (final componentErrors in _activeErrors.values) {
      allErrors.addAll(componentErrors.where((e) => !e.isResolved));
    }
    return allErrors;
  }

  /// Clean up resolved and expired errors
  void _cleanupErrors() {
    if (_disposed) return;

    // Clean up resolved and expired errors
    for (final componentErrors in _activeErrors.values) {
      componentErrors.removeWhere((error) => error.isResolved || error.isExpired);
    }
    
    // Remove empty component entries
    _activeErrors.removeWhere((component, errors) => errors.isEmpty);
    
    // Clean up old suppression entries
    final now = DateTime.now();
    _suppressionMap.removeWhere((key, time) => 
        now.difference(time) > suppressionWindow * 2);
    
    // Clean up expired category entries
    _latestByCategory.removeWhere((category, error) => error.isExpired);
  }

  /// Emit error state event
  void _emitEvent(ErrorStateEventType type, ManagedError? error, String message) {
    if (!_disposed) {
      _eventController.add(ErrorStateEvent(
        type: type,
        error: error,
        message: message,
      ));
    }
  }

  /// Dispose the error state manager
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    _cleanupTimer?.cancel();
    
    _emitEvent(ErrorStateEventType.stateCleared, null, 'Error state manager disposed');
    
    _activeErrors.clear();
    _latestByCategory.clear();
    _suppressionMap.clear();
    
    await _eventController.close();
  }
}

/// Statistics for error state monitoring
class ErrorStateStats {
  final int totalActiveErrors;
  final int componentCount;
  final Set<ErrorCategory> categoriesWithErrors;
  final int criticalErrors;

  const ErrorStateStats({
    required this.totalActiveErrors,
    required this.componentCount,
    required this.categoriesWithErrors,
    required this.criticalErrors,
  });

  bool get hasErrors => totalActiveErrors > 0;
  bool get hasCriticalErrors => criticalErrors > 0;

  @override
  String toString() {
    return 'ErrorStateStats(total: $totalActiveErrors, components: $componentCount, '
           'critical: $criticalErrors, categories: ${categoriesWithErrors.length})';
  }
}