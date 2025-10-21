import 'dart:async';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

/// Audio session initialization states
enum AudioSessionState {
  uninitialized,
  initializing,
  configured,
  active,
  failed,
}

/// Audio session operation types for coordination
enum AudioSessionOperation {
  configure,
  activate,
  deactivate,
  setOptions,
}

/// Events emitted by the audio session coordinator
enum AudioSessionEventType {
  initialized,
  activated,
  deactivated,
  interrupted,
  deviceChanged,
  error,
}

/// Audio session event for monitoring
class AudioSessionEvent {
  final AudioSessionEventType type;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic> context;

  AudioSessionEvent({
    required this.type,
    required this.message,
    Map<String, dynamic>? context,
  }) : timestamp = DateTime.now(),
       context = context ?? <String, dynamic>{};
}

/// Coordinates iOS audio session operations to prevent race conditions
class AudioSessionCoordinator {
  AudioSession? _audioSession;
  AudioSessionState _state = AudioSessionState.uninitialized;
  final Completer<void> _initializationCompleter = Completer<void>();
  
  // Coordination primitives
  final StreamController<AudioSessionEvent> _eventController = 
      StreamController<AudioSessionEvent>.broadcast();
  
  // Operation queue to prevent concurrent audio session operations
  final List<Future<void> Function()> _operationQueue = [];
  bool _processingQueue = false;
  
  // User intent tracking
  bool _userIntendedPlaying = false;
  
  // Interruption state
  bool _isInterrupted = false;
  
  // Subscription management
  StreamSubscription? _interruptionSubscription;
  StreamSubscription? _noisySubscription;
  StreamSubscription? _devicesSubscription;
  
  bool _disposed = false;

  /// Current audio session state
  AudioSessionState get state => _state;
  
  /// Whether audio session is ready for use
  bool get isReady => _state == AudioSessionState.active;
  
  /// Stream of audio session events
  Stream<AudioSessionEvent> get events => _eventController.stream;
  
  /// Whether currently interrupted
  bool get isInterrupted => _isInterrupted;

  /// Initialize the audio session coordinator (iOS only)
  Future<void> initialize() async {
    if (!Platform.isIOS || _disposed) return;
    
    if (_state != AudioSessionState.uninitialized) {
      await _initializationCompleter.future;
      return;
    }
    
    await _queueOperation(() => _performInitialization());
  }

  /// Perform the actual initialization
  Future<void> _performInitialization() async {
    if (_state != AudioSessionState.uninitialized) return;
    
    try {
      _state = AudioSessionState.initializing;
      _emitEvent(AudioSessionEventType.initialized, 'Starting audio session initialization');
      
      // Get audio session instance
      _audioSession = await AudioSession.instance;
      
      // Configure for music playback
      await _audioSession!.configure(const AudioSessionConfiguration.music());
      
      _state = AudioSessionState.configured;
      _emitEvent(AudioSessionEventType.initialized, 'Audio session configured for music');
      
      // Set up event listeners
      _setupEventListeners();
      
      // Activate the session
      await _audioSession!.setActive(true);
      
      _state = AudioSessionState.active;
      _emitEvent(AudioSessionEventType.activated, 'Audio session activated successfully');
      
      _initializationCompleter.complete();
      
    } catch (e) {
      _state = AudioSessionState.failed;
      _emitEvent(AudioSessionEventType.error, 'Audio session initialization failed: $e');
      
      if (!_initializationCompleter.isCompleted) {
        _initializationCompleter.completeError(e);
      }
      
      if (kDebugMode) {
        print('AudioSessionCoordinator: Failed to initialize: $e');
      }
    }
  }

  /// Set up audio session event listeners
  void _setupEventListeners() {
    if (_audioSession == null) return;
    
    // Handle interruptions (phone calls, notifications, etc.)
    _interruptionSubscription = _audioSession!.interruptionEventStream.listen((event) {
      _handleInterruption(event);
    });
    
    // Handle becoming noisy events (headphones disconnected)
    _noisySubscription = _audioSession!.becomingNoisyEventStream.listen((_) {
      _handleBecomingNoisy();
    });
    
    // Handle device changes
    _devicesSubscription = _audioSession!.devicesChangedEventStream.listen((event) {
      _handleDeviceChanges(event);
    });
  }

  /// Handle audio interruption events
  void _handleInterruption(AudioInterruptionEvent event) {
    _emitEvent(AudioSessionEventType.interrupted, 'Audio interruption: ${event.type}', {
      'type': event.type.toString(),
      'userIntended': _userIntendedPlaying,
    });
    
    switch (event.type) {
      case AudioInterruptionType.pause:
        _isInterrupted = true;
        if (kDebugMode) {
          print('AudioSessionCoordinator: Audio interrupted (pause)');
        }
        break;
        
      case AudioInterruptionType.duck:
        _isInterrupted = true;
        if (kDebugMode) {
          print('AudioSessionCoordinator: Audio ducking');
        }
        break;
        
      case AudioInterruptionType.unknown:
        _isInterrupted = false;
        if (kDebugMode) {
          print('AudioSessionCoordinator: Audio interruption ended');
        }
        break;
    }
  }

  /// Handle becoming noisy events
  void _handleBecomingNoisy() {
    _emitEvent(AudioSessionEventType.deviceChanged, 'Audio becoming noisy (headphones disconnected)');
    
    if (kDebugMode) {
      print('AudioSessionCoordinator: Audio becoming noisy');
    }
  }

  /// Handle device change events
  void _handleDeviceChanges(AudioDevicesChangedEvent event) {
    _emitEvent(AudioSessionEventType.deviceChanged, 
               'Audio devices changed: ${event.devicesAdded.length} added, ${event.devicesRemoved.length} removed', {
      'devicesAdded': event.devicesAdded.length,
      'devicesRemoved': event.devicesRemoved.length,
    });
    
    if (kDebugMode) {
      print('AudioSessionCoordinator: Audio devices changed');
    }
  }

  /// Ensure audio session is active (safe coordination)
  Future<void> ensureActive() async {
    if (!Platform.isIOS || _disposed) return;
    
    // Wait for initialization if needed
    if (_state == AudioSessionState.uninitialized) {
      await initialize();
    } else if (_state == AudioSessionState.initializing) {
      await _initializationCompleter.future;
    }
    
    // If already active, nothing to do
    if (_state == AudioSessionState.active) return;
    
    await _queueOperation(() => _performActivation());
  }

  /// Perform audio session activation
  Future<void> _performActivation() async {
    if (_audioSession == null || _state == AudioSessionState.active) return;
    
    try {
      await _audioSession!.setActive(true);
      _state = AudioSessionState.active;
      
      _emitEvent(AudioSessionEventType.activated, 'Audio session activated');
      
      if (kDebugMode) {
        print('AudioSessionCoordinator: Audio session activated');
      }
    } catch (e) {
      _emitEvent(AudioSessionEventType.error, 'Failed to activate audio session: $e');
      
      if (kDebugMode) {
        print('AudioSessionCoordinator: Failed to activate: $e');
      }
      
      rethrow;
    }
  }

  /// Deactivate audio session (safe coordination)
  Future<void> deactivate() async {
    if (!Platform.isIOS || _disposed || _audioSession == null) return;
    
    await _queueOperation(() => _performDeactivation());
  }

  /// Perform audio session deactivation
  Future<void> _performDeactivation() async {
    if (_audioSession == null) return;
    
    try {
      await _audioSession!.setActive(false);
      _state = AudioSessionState.configured;
      
      _emitEvent(AudioSessionEventType.deactivated, 'Audio session deactivated');
      
      if (kDebugMode) {
        print('AudioSessionCoordinator: Audio session deactivated');
      }
    } catch (e) {
      _emitEvent(AudioSessionEventType.error, 'Failed to deactivate audio session: $e');
      
      if (kDebugMode) {
        print('AudioSessionCoordinator: Failed to deactivate: $e');
      }
    }
  }

  /// Update user intent for interruption handling
  void setUserIntendedPlaying(bool intendedPlaying) {
    _userIntendedPlaying = intendedPlaying;
  }

  /// Check if user intended to be playing (for interruption recovery)
  bool get userIntendedPlaying => _userIntendedPlaying;

  /// Queue an operation to prevent concurrent audio session access
  Future<void> _queueOperation(Future<void> Function() operation) async {
    final completer = Completer<void>();
    
    _operationQueue.add(() async {
      try {
        await operation();
        completer.complete();
      } catch (e) {
        completer.completeError(e);
      }
    });
    
    _processQueue();
    return completer.future;
  }

  /// Process the operation queue sequentially
  Future<void> _processQueue() async {
    if (_processingQueue || _operationQueue.isEmpty) return;
    
    _processingQueue = true;
    
    while (_operationQueue.isNotEmpty && !_disposed) {
      final operation = _operationQueue.removeAt(0);
      try {
        await operation();
      } catch (e) {
        if (kDebugMode) {
          print('AudioSessionCoordinator: Operation failed: $e');
        }
      }
    }
    
    _processingQueue = false;
  }

  /// Emit monitoring event
  void _emitEvent(AudioSessionEventType type, String message, [Map<String, dynamic>? context]) {
    if (!_disposed) {
      _eventController.add(AudioSessionEvent(
        type: type,
        message: message,
        context: context,
      ));
    }
  }

  /// Dispose the coordinator and clean up resources
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    
    // Cancel subscriptions
    await _interruptionSubscription?.cancel();
    await _noisySubscription?.cancel();
    await _devicesSubscription?.cancel();
    
    // Deactivate session if active
    if (_state == AudioSessionState.active) {
      try {
        await _audioSession?.setActive(false);
      } catch (e) {
        if (kDebugMode) {
          print('AudioSessionCoordinator: Error deactivating during dispose: $e');
        }
      }
    }
    
    // Clear queue
    _operationQueue.clear();
    
    _emitEvent(AudioSessionEventType.deactivated, 'Audio session coordinator disposed');
    
    // Close event stream
    await _eventController.close();
    
    if (kDebugMode) {
      print('AudioSessionCoordinator: Disposed');
    }
  }
}