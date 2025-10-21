import 'dart:async';

/// Synchronized radio mode state manager to prevent race conditions
/// between radio mode UI state and actual streaming behavior
class RadioModeStateManager {
  bool _radioModeEnabled = false;
  bool _isExpanding = false;
  DateTime? _lastExpansionTime;
  final Duration _expansionCooldown = const Duration(seconds: 2);
  
  final Completer<void> _readyCompleter = Completer<void>();
  final StreamController<bool> _radioModeStreamController = StreamController<bool>.broadcast();

  RadioModeStateManager() {
    _readyCompleter.complete();
  }

  /// Get current radio mode enabled state (thread-safe)
  bool get isEnabled => _radioModeEnabled;

  /// Check if radio mode expansion is currently in progress
  bool get isExpanding => _isExpanding;

  /// Stream of radio mode state changes
  Stream<bool> get radioModeStream => _radioModeStreamController.stream;

  /// Ensure radio mode manager is ready
  Future<void> ensureReady() => _readyCompleter.future;

  /// Enable radio mode with synchronization
  Future<void> enable() async {
    await ensureReady();
    
    if (!_radioModeEnabled) {
      _radioModeEnabled = true;
      _radioModeStreamController.add(true);
    }
  }

  /// Disable radio mode with synchronization
  Future<void> disable() async {
    await ensureReady();
    
    if (_radioModeEnabled) {
      _radioModeEnabled = false;
      // Cancel any ongoing expansion
      _isExpanding = false;
      _radioModeStreamController.add(false);
    }
  }

  /// Toggle radio mode state with synchronization
  Future<void> toggle() async {
    await ensureReady();
    
    if (_radioModeEnabled) {
      await disable();
    } else {
      await enable();
    }
  }

  /// Check if expansion is allowed (prevents rapid expansions)
  bool canExpand() {
    if (!_radioModeEnabled || _isExpanding) {
      return false;
    }

    final now = DateTime.now();
    if (_lastExpansionTime != null) {
      final timeSinceLastExpansion = now.difference(_lastExpansionTime!);
      if (timeSinceLastExpansion < _expansionCooldown) {
        return false;
      }
    }

    return true;
  }

  /// Mark expansion as starting (with race condition protection)
  bool startExpansion() {
    if (!canExpand()) {
      return false;
    }

    _isExpanding = true;
    _lastExpansionTime = DateTime.now();
    return true;
  }

  /// Mark expansion as completed
  void completeExpansion() {
    _isExpanding = false;
  }

  /// Force cancel any ongoing expansion (for mode disable)
  void cancelExpansion() {
    _isExpanding = false;
  }

  /// Get radio mode configuration
  RadioModeConfig getConfig() {
    return RadioModeConfig(
      enabled: _radioModeEnabled,
      isExpanding: _isExpanding,
      lastExpansionTime: _lastExpansionTime,
      expansionCooldown: _expansionCooldown,
    );
  }

  /// Dispose resources
  void dispose() {
    _radioModeStreamController.close();
  }
}

/// Immutable radio mode configuration
class RadioModeConfig {
  final bool enabled;
  final bool isExpanding;
  final DateTime? lastExpansionTime;
  final Duration expansionCooldown;

  const RadioModeConfig({
    required this.enabled,
    required this.isExpanding,
    required this.lastExpansionTime,
    required this.expansionCooldown,
  });

  @override
  String toString() {
    return 'RadioModeConfig('
        'enabled: $enabled, '
        'isExpanding: $isExpanding, '
        'lastExpansionTime: $lastExpansionTime, '
        'expansionCooldown: ${expansionCooldown.inSeconds}s'
        ')';
  }
}

/// Coordinated radio mode operation manager
class RadioModeOperationManager {
  final RadioModeStateManager _stateManager;
  final Completer<void> _operationCompleter = Completer<void>();
  bool _disposed = false;

  RadioModeOperationManager(this._stateManager) {
    _operationCompleter.complete();
  }

  /// Execute radio mode operation with proper coordination
  Future<T> executeOperation<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    if (_disposed) {
      throw StateError('RadioModeOperationManager has been disposed');
    }

    await _stateManager.ensureReady();

    try {
      final result = await operation();
      return result;
    } catch (e) {
      // Log operation failure but don't throw to prevent cascading failures
      print('RadioModeOperationManager: $operationName failed: $e');
      rethrow;
    }
  }

  /// Execute expansion operation with proper state management
  Future<bool> executeExpansion(Future<void> Function() expansionOperation) async {
    if (_disposed || !_stateManager.canExpand()) {
      return false;
    }

    if (!_stateManager.startExpansion()) {
      return false;
    }

    try {
      await expansionOperation();
      return true;
    } catch (e) {
      print('RadioModeOperationManager: Expansion failed: $e');
      return false;
    } finally {
      _stateManager.completeExpansion();
    }
  }

  /// Dispose resources
  void dispose() {
    _disposed = true;
  }
}