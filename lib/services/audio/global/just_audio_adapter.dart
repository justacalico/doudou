/// JustAudio Platform Adapter - Cross-platform audio implementation using just_audio
/// 
/// This adapter provides audio playback using the just_audio package,
/// which works on mobile, desktop, and web platforms.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import '../../../models/jellyfin_models.dart';
import 'audio_state.dart';
import 'platform_audio_adapter.dart';

/// JustAudio-based platform adapter.
/// 
/// This is the primary audio adapter used across all platforms.
/// It wraps the just_audio package and provides a consistent interface.
class JustAudioAdapter extends PlatformAudioAdapter with PlatformAdapterMixin {
  AudioPlayer? _player;
  final PlatformAdapterConfig config;
  
  // Stream controllers for exposing state
  final BehaviorSubject<AudioPhase> _phaseSubject = 
      BehaviorSubject<AudioPhase>.seeded(AudioPhase.idle);
  final BehaviorSubject<Duration> _positionSubject = 
      BehaviorSubject<Duration>.seeded(Duration.zero);
  final BehaviorSubject<Duration> _durationSubject = 
      BehaviorSubject<Duration>.seeded(Duration.zero);
  final BehaviorSubject<Duration> _bufferedPositionSubject = 
      BehaviorSubject<Duration>.seeded(Duration.zero);
  final PublishSubject<AudioError> _errorSubject = PublishSubject<AudioError>();
  
  // Subscriptions for cleanup
  final List<StreamSubscription> _subscriptions = [];
  
  // State tracking
  bool _isInitialized = false;
  bool _isDisposed = false;
  String? _currentUrl;
  double _currentVolume = 1.0;
  double _currentSpeed = 1.0;

  JustAudioAdapter({
    this.config = const PlatformAdapterConfig(),
  });

  @override
  Future<AudioResult<void>> initialize() async {
    if (_isInitialized) {
      return const AudioResult.success(null);
    }
    
    try {
      if (kDebugMode) {
        print('JustAudioAdapter: Initializing...');
      }
      
      _player = AudioPlayer();
      
      // Configure audio load settings
      await _player!.setAutomaticallyWaitsToMinimizeStalling(true);
      
      // Set up stream subscriptions
      _setupStreamSubscriptions();
      
      _isInitialized = true;
      
      if (kDebugMode) {
        print('JustAudioAdapter: Initialized successfully');
      }
      
      return const AudioResult.success(null);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('JustAudioAdapter: Initialization failed: $e');
      }
      return errorFromException(e, 'initialize', stackTrace: stackTrace);
    }
  }

  void _setupStreamSubscriptions() {
    if (_player == null) return;
    
    // Player state changes
    _subscriptions.add(
      _player!.playerStateStream.listen(
        _handlePlayerState,
        onError: (error) => _handleError(error, 'playerStateStream'),
      ),
    );
    
    // Position updates
    _subscriptions.add(
      _player!.positionStream.listen(
        (position) {
          if (!_isDisposed) {
            _positionSubject.add(position);
          }
        },
        onError: (error) => _handleError(error, 'positionStream'),
      ),
    );
    
    // Duration updates
    _subscriptions.add(
      _player!.durationStream.listen(
        (duration) {
          if (!_isDisposed && duration != null) {
            _durationSubject.add(duration);
          }
        },
        onError: (error) => _handleError(error, 'durationStream'),
      ),
    );
    
    // Buffered position updates
    _subscriptions.add(
      _player!.bufferedPositionStream.listen(
        (buffered) {
          if (!_isDisposed) {
            _bufferedPositionSubject.add(buffered);
          }
        },
        onError: (error) => _handleError(error, 'bufferedPositionStream'),
      ),
    );
    
    // Processing state for loading indication
    _subscriptions.add(
      _player!.processingStateStream.listen(
        _handleProcessingState,
        onError: (error) => _handleError(error, 'processingStateStream'),
      ),
    );
  }

  void _handlePlayerState(PlayerState state) {
    if (_isDisposed) return;
    
    AudioPhase phase;
    
    if (state.processingState == ProcessingState.loading ||
        state.processingState == ProcessingState.buffering) {
      phase = AudioPhase.loading;
    } else if (state.processingState == ProcessingState.completed) {
      phase = AudioPhase.completed;
    } else if (state.processingState == ProcessingState.idle) {
      phase = AudioPhase.idle;
    } else if (state.playing) {
      phase = AudioPhase.playing;
    } else {
      phase = AudioPhase.paused;
    }
    
    if (_phaseSubject.value != phase) {
      _phaseSubject.add(phase);
      
      if (kDebugMode) {
        print('JustAudioAdapter: Phase changed to $phase');
      }
    }
  }

  void _handleProcessingState(ProcessingState state) {
    if (_isDisposed) return;
    
    switch (state) {
      case ProcessingState.loading:
      case ProcessingState.buffering:
        if (_phaseSubject.value != AudioPhase.loading) {
          _phaseSubject.add(AudioPhase.loading);
        }
        break;
      case ProcessingState.completed:
        if (_phaseSubject.value != AudioPhase.completed) {
          _phaseSubject.add(AudioPhase.completed);
        }
        break;
      case ProcessingState.idle:
        if (_phaseSubject.value != AudioPhase.idle) {
          _phaseSubject.add(AudioPhase.idle);
        }
        break;
      case ProcessingState.ready:
        // Don't change phase here - let playerState handle playing/paused
        break;
    }
  }

  void _handleError(Object error, String source) {
    if (_isDisposed) return;
    
    if (kDebugMode) {
      print('JustAudioAdapter: Error from $source: $error');
    }
    
    _phaseSubject.add(AudioPhase.error);
    _errorSubject.add(AudioError.fromException(error, source));
  }

  @override
  Future<AudioResult<Duration>> load(String url, Track track) async {
    _assertNotDisposed();
    _assertInitialized();
    
    try {
      if (kDebugMode) {
        print('JustAudioAdapter: Loading $url');
      }
      
      _phaseSubject.add(AudioPhase.loading);
      _currentUrl = url;
      
      // Set the audio source with proper error handling
      Duration? duration;
      try {
        // Use AudioSource for better control over loading
        final audioSource = AudioSource.uri(
          Uri.parse(url),
          tag: track.name,
        );
        duration = await _player!.setAudioSource(audioSource);
      } catch (loadError) {
        if (kDebugMode) {
          print('JustAudioAdapter: setAudioSource failed: $loadError');
        }
        // Try simpler setUrl as fallback
        try {
          duration = await _player!.setUrl(url);
        } catch (urlError) {
          if (kDebugMode) {
            print('JustAudioAdapter: setUrl fallback also failed: $urlError');
          }
          rethrow;
        }
      }
      
      if (duration != null) {
        _durationSubject.add(duration);
        
        if (kDebugMode) {
          print('JustAudioAdapter: Loaded, duration: $duration');
        }
        
        _phaseSubject.add(AudioPhase.ready);
        return AudioResult.success(duration);
      } else {
        // Duration is null but load succeeded - still allow playback
        if (kDebugMode) {
          print('JustAudioAdapter: Loaded but duration is null (streaming?)');
        }
        _phaseSubject.add(AudioPhase.ready);
        return const AudioResult.success(Duration.zero);
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('JustAudioAdapter: Load failed: $e');
        print('JustAudioAdapter: Stack trace: $stackTrace');
      }
      
      _phaseSubject.add(AudioPhase.error);
      _currentUrl = null;
      
      return errorFromException(e, 'load', track: track, stackTrace: stackTrace);
    }
  }

  @override
  Future<AudioResult<void>> play() async {
    _assertNotDisposed();
    _assertInitialized();
    
    try {
      if (kDebugMode) {
        print('JustAudioAdapter: Play');
      }
      
      await _player!.play();
      return const AudioResult.success(null);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('JustAudioAdapter: Play failed: $e');
      }
      return errorFromException(e, 'play', stackTrace: stackTrace);
    }
  }

  @override
  Future<AudioResult<void>> pause() async {
    _assertNotDisposed();
    _assertInitialized();
    
    try {
      if (kDebugMode) {
        print('JustAudioAdapter: Pause');
      }
      
      await _player!.pause();
      return const AudioResult.success(null);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('JustAudioAdapter: Pause failed: $e');
      }
      return errorFromException(e, 'pause', stackTrace: stackTrace);
    }
  }

  @override
  Future<AudioResult<void>> stop() async {
    _assertNotDisposed();
    _assertInitialized();
    
    try {
      if (kDebugMode) {
        print('JustAudioAdapter: Stop');
      }
      
      await _player!.stop();
      _currentUrl = null;
      _positionSubject.add(Duration.zero);
      _durationSubject.add(Duration.zero);
      _phaseSubject.add(AudioPhase.stopped);
      
      return const AudioResult.success(null);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('JustAudioAdapter: Stop failed: $e');
      }
      return errorFromException(e, 'stop', stackTrace: stackTrace);
    }
  }

  @override
  Future<AudioResult<void>> seek(Duration position) async {
    _assertNotDisposed();
    _assertInitialized();
    
    try {
      position = validatePosition(position, _durationSubject.value);
      
      if (kDebugMode) {
        print('JustAudioAdapter: Seek to $position');
      }
      
      await _player!.seek(position);
      _positionSubject.add(position);
      
      return const AudioResult.success(null);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('JustAudioAdapter: Seek failed: $e');
      }
      return errorFromException(e, 'seek', stackTrace: stackTrace);
    }
  }

  @override
  Future<AudioResult<void>> setVolume(double volume) async {
    _assertNotDisposed();
    _assertInitialized();
    
    try {
      volume = validateVolume(volume);
      _currentVolume = volume;
      
      if (kDebugMode) {
        print('JustAudioAdapter: Set volume to $volume');
      }
      
      await _player!.setVolume(volume);
      return const AudioResult.success(null);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('JustAudioAdapter: Set volume failed: $e');
      }
      return errorFromException(e, 'setVolume', stackTrace: stackTrace);
    }
  }

  @override
  Future<AudioResult<void>> setSpeed(double speed) async {
    _assertNotDisposed();
    _assertInitialized();
    
    try {
      speed = validateSpeed(speed);
      _currentSpeed = speed;
      
      if (kDebugMode) {
        print('JustAudioAdapter: Set speed to $speed');
      }
      
      await _player!.setSpeed(speed);
      return const AudioResult.success(null);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('JustAudioAdapter: Set speed failed: $e');
      }
      return errorFromException(e, 'setSpeed', stackTrace: stackTrace);
    }
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    
    if (kDebugMode) {
      print('JustAudioAdapter: Disposing...');
    }
    
    _isDisposed = true;
    
    // Cancel subscriptions
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    
    // Dispose player
    await _player?.dispose();
    _player = null;
    
    // Close streams
    await _phaseSubject.close();
    await _positionSubject.close();
    await _durationSubject.close();
    await _bufferedPositionSubject.close();
    await _errorSubject.close();
    
    if (kDebugMode) {
      print('JustAudioAdapter: Disposed');
    }
  }

  // Stream getters
  @override
  Stream<AudioPhase> get phaseStream => _phaseSubject.stream;
  
  @override
  Stream<Duration> get positionStream => _positionSubject.stream;
  
  @override
  Stream<Duration> get durationStream => _durationSubject.stream;
  
  @override
  Stream<Duration> get bufferedPositionStream => _bufferedPositionSubject.stream;
  
  @override
  Stream<AudioError> get errorStream => _errorSubject.stream;
  
  // Current state getters
  @override
  AudioPhase get currentPhase => _phaseSubject.value;
  
  @override
  Duration get currentPosition => _player?.position ?? Duration.zero;
  
  @override
  Duration get currentDuration => _player?.duration ?? Duration.zero;
  
  @override
  double get currentVolume => _currentVolume;
  
  @override
  double get currentSpeed => _currentSpeed;
  
  @override
  bool get isActive => _player != null && 
      (_player!.playing || _phaseSubject.value == AudioPhase.paused);
  
  @override
  String? get currentUrl => _currentUrl;

  // Private helpers
  void _assertInitialized() {
    if (!_isInitialized || _player == null) {
      throw StateError('JustAudioAdapter not initialized');
    }
  }
  
  void _assertNotDisposed() {
    if (_isDisposed) {
      throw StateError('JustAudioAdapter has been disposed');
    }
  }
}

/// Factory for creating JustAudio adapters
class JustAudioAdapterFactory implements PlatformAudioAdapterFactory {
  final PlatformAdapterConfig config;

  const JustAudioAdapterFactory({
    this.config = PlatformAdapterConfig.defaultConfig,
  });

  @override
  PlatformAudioAdapter create() {
    return JustAudioAdapter(config: config);
  }
}
