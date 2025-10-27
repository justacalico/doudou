import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import '../models/jellyfin_models.dart';
import 'media_service_manager.dart';
import 'audio/base_audio_handler.dart';
import 'audio/mobile_audio_handler.dart';
import 'audio/simple_desktop_audio_handler.dart';
import 'audio/web_audio_handler.dart';

/// Main audio service that provides a unified interface across all platforms
/// This service automatically instantiates the correct audio handler based on platform
/// and provides a consistent API for audio playback throughout the app
class AudioService {
  static AudioService? _instance;
  static AudioService get instance => _instance ??= AudioService._();
  AudioService._();

  // Platform-specific audio handler
  dynamic _audioHandler;
  bool _initialized = false;
  
  // Stream controllers for unified interface
  final StreamController<AudioPlayerState> _stateController = StreamController<AudioPlayerState>.broadcast();
  final StreamController<Duration> _positionController = StreamController<Duration>.broadcast();
  final StreamController<Duration> _durationController = StreamController<Duration>.broadcast();
  final StreamController<Track?> _currentTrackController = StreamController<Track?>.broadcast();
  final StreamController<List<Track>> _queueController = StreamController<List<Track>>.broadcast();
  final StreamController<RepeatMode> _repeatModeController = StreamController<RepeatMode>.broadcast();
  final StreamController<bool> _shuffleController = StreamController<bool>.broadcast();
  final StreamController<double> _volumeController = StreamController<double>.broadcast();
  final StreamController<double> _speedController = StreamController<double>.broadcast();
  final StreamController<String?> _errorController = StreamController<String?>.broadcast();

  // Current state
  AudioPlayerState _currentState = AudioPlayerState.idle;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Track? _currentTrack;
  List<Track> _queue = [];
  RepeatMode _repeatMode = RepeatMode.none;
  bool _shuffleEnabled = false;
  double _volume = 1.0;
  double _speed = 1.0;
  String? _lastError;

  /// Initialize the audio service with appropriate handler for current platform
  Future<void> initialize(MediaServiceManager mediaServiceManager) async {
    if (_initialized) return;

    try {
      if (kDebugMode) {
        print('AudioService: Initializing for platform ${defaultTargetPlatform.name}...');
      }

      // Create appropriate handler based on platform
      if (kIsWeb) {
        // Web platform
        _audioHandler = WebAudioHandler(mediaServiceManager);
        await _setupWebHandlerStreams();
      } else if (defaultTargetPlatform == TargetPlatform.android || 
                 defaultTargetPlatform == TargetPlatform.iOS) {
        // Mobile platforms - use AudioService
        _audioHandler = await audio_service.AudioService.init(
          builder: () => DoudouAudioHandler(
            mediaServiceManager: mediaServiceManager,
          ),
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'com.doudoubox.audio',
            androidNotificationChannelName: 'Doudou Audio',
            androidNotificationOngoing: true,
            androidStopForegroundOnPause: false,
          ),
        );
        await _setupMobileHandlerStreams();
      } else {
        // Desktop platforms (Linux, macOS, Windows)
        _audioHandler = SimpleDesktopAudioHandler(mediaServiceManager);
        await _setupDesktopHandlerStreams();
      }

      _initialized = true;
      
      if (kDebugMode) {
        print('AudioService: Initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('AudioService: Failed to initialize: $e');
      }
      _updateError('Failed to initialize audio service: $e');
      rethrow;
    }
  }

  /// Set up streams for web audio handler
  Future<void> _setupWebHandlerStreams() async {
    final handler = _audioHandler as WebAudioHandler;
    
    handler.stateStream.listen((state) {
      _currentState = state;
      _stateController.add(state);
    });
    
    handler.positionStream.listen((position) {
      _position = position;
      _positionController.add(position);
    });
    
    handler.durationStream.listen((duration) {
      if (duration != null) {
        _duration = duration;
        _durationController.add(duration);
      }
    });
    
    handler.currentTrackStream.listen((track) {
      _currentTrack = track;
      _currentTrackController.add(track);
    });
    
    handler.queueStream.listen((queue) {
      _queue = queue;
      _queueController.add(queue);
    });
    
    handler.repeatModeStream.listen((mode) {
      _repeatMode = mode;
      _repeatModeController.add(mode);
    });
    
    handler.shuffleEnabledStream.listen((enabled) {
      _shuffleEnabled = enabled;
      _shuffleController.add(enabled);
    });
    
    handler.volumeStream.listen((volume) {
      _volume = volume;
      _volumeController.add(volume);
    });
    
    handler.speedStream.listen((speed) {
      _speed = speed;
      _speedController.add(speed);
    });
    
    handler.errorStream.listen((error) {
      _lastError = error;
      _errorController.add(error);
    });
  }

  /// Set up streams for mobile audio handler
  Future<void> _setupMobileHandlerStreams() async {
    final handler = _audioHandler as DoudouAudioHandler;
    
    handler.stateStream.listen((state) {
      _currentState = state;
      _stateController.add(state);
    });
    
    handler.positionStream.listen((position) {
      _position = position;
      _positionController.add(position);
    });
    
    handler.durationStream.listen((duration) {
      if (duration != null) {
        _duration = duration;
        _durationController.add(duration);
      }
    });
    
    handler.currentTrackStream.listen((track) {
      _currentTrack = track;
      _currentTrackController.add(track);
    });
    
    // For mobile, we need to convert MediaItem streams to Track streams
    // This would need implementation based on how the mobile handler works
    
    handler.repeatModeStream.listen((mode) {
      _repeatMode = mode;
      _repeatModeController.add(mode);
    });
    
    handler.shuffleEnabledStream.listen((enabled) {
      _shuffleEnabled = enabled;
      _shuffleController.add(enabled);
    });
    
    handler.volumeStream.listen((volume) {
      _volume = volume;
      _volumeController.add(volume);
    });
    
    handler.speedStream.listen((speed) {
      _speed = speed;
      _speedController.add(speed);
    });
    
    handler.errorStream.listen((error) {
      _lastError = error;
      _errorController.add(error);
    });
  }

  /// Set up streams for desktop audio handler
  Future<void> _setupDesktopHandlerStreams() async {
    final handler = _audioHandler as SimpleDesktopAudioHandler;
    
    handler.stateStream.listen((state) {
      _currentState = state;
      _stateController.add(state);
    });
    
    handler.positionStream.listen((position) {
      _position = position;
      _positionController.add(position);
    });
    
    handler.durationStream.listen((duration) {
      if (duration != null) {
        _duration = duration;
        _durationController.add(duration);
      }
    });
    
    handler.currentTrackStream.listen((track) {
      _currentTrack = track;
      _currentTrackController.add(track);
    });
    
    handler.queueStream.listen((queue) {
      _queue = queue;
      _queueController.add(queue);
    });
    
    handler.repeatModeStream.listen((mode) {
      _repeatMode = mode;
      _repeatModeController.add(mode);
    });
    
    handler.shuffleEnabledStream.listen((enabled) {
      _shuffleEnabled = enabled;
      _shuffleController.add(enabled);
    });
    
    handler.volumeStream.listen((volume) {
      _volume = volume;
      _volumeController.add(volume);
    });
    
    handler.speedStream.listen((speed) {
      _speed = speed;
      _speedController.add(speed);
    });
    
    handler.errorStream.listen((error) {
      _lastError = error;
      _errorController.add(error);
    });
  }

  // Unified API methods

  /// Play or resume audio
  Future<void> play() async {
    _ensureInitialized();
    
    if (_audioHandler is WebAudioHandler) {
      await (_audioHandler as WebAudioHandler).play();
    } else if (_audioHandler is DoudouAudioHandler) {
      await (_audioHandler as DoudouAudioHandler).play();
    } else if (_audioHandler is SimpleDesktopAudioHandler) {
      await (_audioHandler as SimpleDesktopAudioHandler).play();
    }
  }

  /// Pause audio
  Future<void> pause() async {
    _ensureInitialized();
    
    if (_audioHandler is WebAudioHandler) {
      await (_audioHandler as WebAudioHandler).pause();
    } else if (_audioHandler is DoudouAudioHandler) {
      await (_audioHandler as DoudouAudioHandler).pause();
    } else if (_audioHandler is SimpleDesktopAudioHandler) {
      await (_audioHandler as SimpleDesktopAudioHandler).pause();
    }
  }

  /// Stop audio
  Future<void> stop() async {
    _ensureInitialized();
    
    if (_audioHandler is WebAudioHandler) {
      await (_audioHandler as WebAudioHandler).stop();
    } else if (_audioHandler is DoudouAudioHandler) {
      await (_audioHandler as DoudouAudioHandler).stop();
    } else if (_audioHandler is SimpleDesktopAudioHandler) {
      await (_audioHandler as SimpleDesktopAudioHandler).stop();
    }
  }

  /// Play a specific track
  Future<void> playTrack(Track track) async {
    _ensureInitialized();
    
    if (_audioHandler is WebAudioHandler) {
      await (_audioHandler as WebAudioHandler).playTrack(track);
    } else if (_audioHandler is DoudouAudioHandler) {
      await (_audioHandler as DoudouAudioHandler).playTrack(track);
    } else if (_audioHandler is SimpleDesktopAudioHandler) {
      await (_audioHandler as SimpleDesktopAudioHandler).playTrack(track);
    }
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    _ensureInitialized();
    
    if (_audioHandler is WebAudioHandler) {
      await (_audioHandler as WebAudioHandler).seek(position);
    } else if (_audioHandler is DoudouAudioHandler) {
      await (_audioHandler as DoudouAudioHandler).seek(position);
    } else if (_audioHandler is SimpleDesktopAudioHandler) {
      await (_audioHandler as SimpleDesktopAudioHandler).seek(position);
    }
  }

  /// Skip to next track
  Future<void> skipToNext() async {
    _ensureInitialized();
    
    if (_audioHandler is WebAudioHandler) {
      await (_audioHandler as WebAudioHandler).skipToNext();
    } else if (_audioHandler is DoudouAudioHandler) {
      await (_audioHandler as DoudouAudioHandler).skipToNext();
    } else if (_audioHandler is SimpleDesktopAudioHandler) {
      await (_audioHandler as SimpleDesktopAudioHandler).skipToNext();
    }
  }

  /// Skip to previous track
  Future<void> skipToPrevious() async {
    _ensureInitialized();
    
    if (_audioHandler is WebAudioHandler) {
      await (_audioHandler as WebAudioHandler).skipToPrevious();
    } else if (_audioHandler is DoudouAudioHandler) {
      await (_audioHandler as DoudouAudioHandler).skipToPrevious();
    } else if (_audioHandler is SimpleDesktopAudioHandler) {
      await (_audioHandler as SimpleDesktopAudioHandler).skipToPrevious();
    }
  }

  /// Set queue
  Future<void> setQueue(List<Track> tracks, {int? initialIndex}) async {
    _ensureInitialized();
    
    if (_audioHandler is WebAudioHandler) {
      await (_audioHandler as WebAudioHandler).setQueue(tracks, initialIndex: initialIndex);
    } else if (_audioHandler is DoudouAudioHandler) {
      // Mobile handler might need different approach for queue
      await (_audioHandler as DoudouAudioHandler).playPlaylist(tracks, initialIndex ?? 0);
    } else if (_audioHandler is SimpleDesktopAudioHandler) {
      await (_audioHandler as SimpleDesktopAudioHandler).setQueue(tracks, initialIndex: initialIndex);
    }
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    _ensureInitialized();
    
    if (_audioHandler is WebAudioHandler) {
      await (_audioHandler as WebAudioHandler).setVolume(volume);
    } else if (_audioHandler is DoudouAudioHandler) {
      await (_audioHandler as DoudouAudioHandler).setVolume(volume);
    } else if (_audioHandler is SimpleDesktopAudioHandler) {
      await (_audioHandler as SimpleDesktopAudioHandler).setVolume(volume);
    }
  }

  /// Set playback speed
  Future<void> setSpeed(double speed) async {
    _ensureInitialized();
    
    if (_audioHandler is WebAudioHandler) {
      await (_audioHandler as WebAudioHandler).setSpeed(speed);
    } else if (_audioHandler is DoudouAudioHandler) {
      await (_audioHandler as DoudouAudioHandler).setSpeed(speed);
    } else if (_audioHandler is SimpleDesktopAudioHandler) {
      await (_audioHandler as SimpleDesktopAudioHandler).setSpeed(speed);
    }
  }

  /// Enable/disable shuffle
  Future<void> enableShuffle(bool enabled) async {
    _ensureInitialized();
    
    if (_audioHandler is WebAudioHandler) {
      await (_audioHandler as WebAudioHandler).enableShuffle(enabled);
    } else if (_audioHandler is DoudouAudioHandler) {
      (_audioHandler as DoudouAudioHandler).toggleShuffle();
    } else if (_audioHandler is SimpleDesktopAudioHandler) {
      await (_audioHandler as SimpleDesktopAudioHandler).enableShuffle(enabled);
    }
  }

  /// Set repeat mode
  Future<void> setRepeatMode(RepeatMode mode) async {
    _ensureInitialized();
    
    if (_audioHandler is WebAudioHandler) {
      await (_audioHandler as WebAudioHandler).setRepeatMode(mode);
    } else if (_audioHandler is DoudouAudioHandler) {
      // Convert to AudioService repeat mode
      AudioServiceRepeatMode audioServiceMode;
      switch (mode) {
        case RepeatMode.none:
          audioServiceMode = AudioServiceRepeatMode.none;
          break;
        case RepeatMode.one:
          audioServiceMode = AudioServiceRepeatMode.one;
          break;
        case RepeatMode.all:
          audioServiceMode = AudioServiceRepeatMode.all;
          break;
      }
      await (_audioHandler as DoudouAudioHandler).setRepeatMode(audioServiceMode);
    } else if (_audioHandler is SimpleDesktopAudioHandler) {
      await (_audioHandler as SimpleDesktopAudioHandler).setRepeatMode(mode);
    }
  }

  // Stream getters for unified interface
  Stream<AudioPlayerState> get stateStream => _stateController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get durationStream => _durationController.stream;
  Stream<Track?> get currentTrackStream => _currentTrackController.stream;
  Stream<List<Track>> get queueStream => _queueController.stream;
  Stream<RepeatMode> get repeatModeStream => _repeatModeController.stream;
  Stream<bool> get shuffleEnabledStream => _shuffleController.stream;
  Stream<double> get volumeStream => _volumeController.stream;
  Stream<double> get speedStream => _speedController.stream;
  Stream<String?> get errorStream => _errorController.stream;

  // Current state getters
  AudioPlayerState get currentState => _currentState;
  Duration get position => _position;
  Duration get duration => _duration;
  Track? get currentTrack => _currentTrack;
  List<Track> get queue => _queue;
  RepeatMode get repeatMode => _repeatMode;
  bool get shuffleEnabled => _shuffleEnabled;
  double get volume => _volume;
  double get speed => _speed;
  String? get lastError => _lastError;

  // Helper methods
  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('AudioService not initialized. Call initialize() first.');
    }
  }

  void _updateError(String error) {
    _lastError = error;
    _errorController.add(error);
  }

  /// Dispose resources
  Future<void> dispose() async {
    if (_audioHandler is WebAudioHandler) {
      await (_audioHandler as WebAudioHandler).dispose();
    } else if (_audioHandler is DoudouAudioHandler) {
      await (_audioHandler as DoudouAudioHandler).dispose();
    } else if (_audioHandler is SimpleDesktopAudioHandler) {
      await (_audioHandler as SimpleDesktopAudioHandler).dispose();
    }

    // Close all stream controllers
    await _stateController.close();
    await _positionController.close();
    await _durationController.close();
    await _currentTrackController.close();
    await _queueController.close();
    await _repeatModeController.close();
    await _shuffleController.close();
    await _volumeController.close();
    await _speedController.close();
    await _errorController.close();

    _initialized = false;
    _instance = null;
  }
}