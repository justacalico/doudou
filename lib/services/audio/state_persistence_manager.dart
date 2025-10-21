import 'dart:async';

/// Manages debounced state persistence to prevent file corruption during rapid state transitions
class StatePersistenceManager {
  Timer? _saveTimer;
  final Duration _debounceDelay;
  final Future<void> Function() _saveFunction;
  bool _hasPendingSave = false;
  bool _disposed = false;

  StatePersistenceManager({
    required Future<void> Function() saveFunction,
    Duration debounceDelay = const Duration(milliseconds: 500),
  })  : _saveFunction = saveFunction,
        _debounceDelay = debounceDelay;

  /// Request a debounced state save operation
  /// Multiple rapid calls will be collapsed into a single save after the debounce delay
  void requestSave() {
    if (_disposed) return;

    // Cancel any existing timer
    _saveTimer?.cancel();
    _hasPendingSave = true;

    // Start new timer
    _saveTimer = Timer(_debounceDelay, _executeSave);
  }

  /// Force immediate save without debouncing
  /// Use sparingly for critical state changes that must be persisted immediately
  Future<void> forceSave() async {
    if (_disposed) return;

    // Cancel any pending debounced save
    _saveTimer?.cancel();
    _hasPendingSave = false;

    await _executeSave();
  }

  /// Execute the actual save operation
  Future<void> _executeSave() async {
    if (_disposed || !_hasPendingSave) return;

    _hasPendingSave = false;
    _saveTimer = null;

    try {
      await _saveFunction();
    } catch (e) {
      // Log error but don't throw to prevent cascading failures
      print('StatePersistenceManager: Save failed: $e');
    }
  }

  /// Check if there's a pending save operation
  bool get hasPendingSave => _hasPendingSave;

  /// Flush any pending saves and dispose resources
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    // If there's a pending save, execute it immediately
    if (_hasPendingSave) {
      _saveTimer?.cancel();
      await _executeSave();
    }

    _saveTimer?.cancel();
  }
}

/// Manages multiple debounced state persistence operations
class StateDebouncer {
  final Map<String, StatePersistenceManager> _managers = {};
  bool _disposed = false;

  /// Get or create a persistence manager for a specific key
  StatePersistenceManager getManager(
    String key,
    Future<void> Function() saveFunction, {
    Duration debounceDelay = const Duration(milliseconds: 500),
  }) {
    if (_disposed) {
      throw StateError('StateDebouncer has been disposed');
    }

    return _managers.putIfAbsent(
      key,
      () => StatePersistenceManager(
        saveFunction: saveFunction,
        debounceDelay: debounceDelay,
      ),
    );
  }

  /// Request a debounced save for a specific key
  void requestSave(String key) {
    final manager = _managers[key];
    if (manager != null && !_disposed) {
      manager.requestSave();
    }
  }

  /// Force immediate save for a specific key
  Future<void> forceSave(String key) async {
    final manager = _managers[key];
    if (manager != null && !_disposed) {
      await manager.forceSave();
    }
  }

  /// Force immediate save for all managed keys
  Future<void> forceFlushAll() async {
    if (_disposed) return;

    final futures = _managers.values.map((manager) => manager.forceSave());
    await Future.wait(futures);
  }

  /// Get pending save status for a specific key
  bool hasPendingSave(String key) {
    final manager = _managers[key];
    return manager?.hasPendingSave ?? false;
  }

  /// Check if any managers have pending saves
  bool get hasAnyPendingSaves {
    return _managers.values.any((manager) => manager.hasPendingSave);
  }

  /// Dispose all managers and flush pending saves
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    final futures = _managers.values.map((manager) => manager.dispose());
    await Future.wait(futures);
    _managers.clear();
  }
}