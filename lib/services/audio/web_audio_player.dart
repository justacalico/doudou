import 'dart:async';
import 'package:flutter/foundation.dart';

// Conditional import: use dart:js on web, stub on other platforms
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js if (dart.library.io) 'web_audio_player_stub.dart';

class WebAudioPlayer {
  static WebAudioPlayer? _instance;
  static WebAudioPlayer get instance => _instance ??= WebAudioPlayer._();
  
  WebAudioPlayer._() {
    _setupCallbacks();
  }
  
  final StreamController<Duration> _positionController = StreamController<Duration>.broadcast();
  final StreamController<Duration> _durationController = StreamController<Duration>.broadcast();
  final StreamController<bool> _playingController = StreamController<bool>.broadcast();
  
  String? _currentUrl;
  bool _isPlaying = false;
  Timer? _positionTimer;
  
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get durationStream => _durationController.stream;
  Stream<bool> get playingStream => _playingController.stream;
  
  bool get isPlaying => _isPlaying;
  
  Duration get position {
    if (!kIsWeb) return Duration.zero;
    try {
      final currentTime = js.context['doudouAudio'].callMethod('getCurrentTime') as num;
      return Duration(seconds: currentTime.round());
    } catch (e) {
      return Duration.zero;
    }
  }
  
  Duration get duration {
    if (!kIsWeb) return Duration.zero;
    try {
      final duration = js.context['doudouAudio'].callMethod('getDuration') as num;
      return Duration(seconds: duration.round());
    } catch (e) {
      return Duration.zero;
    }
  }
  
  void _setupCallbacks() {
    if (!kIsWeb) return;
    // Set up callbacks for HTML audio events
    js.context['doudouAudioCallbacks'] = js.JsObject.jsify({
      'onLoadedMetadata': () {
        _durationController.add(duration);
        if (kDebugMode) {
          print('WebAudioPlayer: Loaded metadata, duration: ${duration.inSeconds}s');
        }
      },
      'onPlay': () {
        _isPlaying = true;
        _playingController.add(true);
        _startPositionTimer();
        if (kDebugMode) {
          print('WebAudioPlayer: Playback started');
        }
      },
      'onPause': () {
        _isPlaying = false;
        _playingController.add(false);
        _stopPositionTimer();
        if (kDebugMode) {
          print('WebAudioPlayer: Playback paused');
        }
      },
      'onEnded': () {
        _isPlaying = false;
        _playingController.add(false);
        _stopPositionTimer();
        if (kDebugMode) {
          print('WebAudioPlayer: Playback ended');
        }
      },
      'onError': (error) {
        if (kDebugMode) {
          print('WebAudioPlayer: Error: $error');
        }
      },
      'onTimeUpdate': () {
        _positionController.add(position);
      },
    });
  }
  
  Future<void> setUrl(String url) async {
    if (!kIsWeb) return;
    if (_currentUrl == url) {
      return; // Already loaded
    }
    
    if (kDebugMode) {
      print('WebAudioPlayer: Setting URL: $url');
    }
    
    _currentUrl = url;
    
    try {
      js.context['doudouAudio'].callMethod('setUrl', [url]);
    } catch (e) {
      if (kDebugMode) {
        print('WebAudioPlayer: Error setting URL: $e');
      }
    }
  }
  
  void _startPositionTimer() {
    _stopPositionTimer();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      _positionController.add(position);
    });
  }
  
  void _stopPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }
  
  Future<void> play() async {
    if (!kIsWeb) return;
    try {
      await js.context['doudouAudio'].callMethod('play');
    } catch (e) {
      if (kDebugMode) {
        print('WebAudioPlayer: Error playing audio: $e');
      }
    }
  }
  
  void pause() {
    if (!kIsWeb) return;
    try {
      js.context['doudouAudio'].callMethod('pause');
    } catch (e) {
      if (kDebugMode) {
        print('WebAudioPlayer: Error pausing audio: $e');
      }
    }
  }
  
  void stop() {
    if (!kIsWeb) return;
    try {
      js.context['doudouAudio'].callMethod('stop');
    } catch (e) {
      if (kDebugMode) {
        print('WebAudioPlayer: Error stopping audio: $e');
      }
    }
  }
  
  void seek(Duration position) {
    try {
      js.context['doudouAudio'].callMethod('seek', [position.inSeconds]);
    } catch (e) {
      if (kDebugMode) {
        print('WebAudioPlayer: Error seeking audio: $e');
      }
    }
  }
  
  void setVolume(double volume) {
    try {
      js.context['doudouAudio'].callMethod('setVolume', [volume.clamp(0.0, 1.0)]);
    } catch (e) {
      if (kDebugMode) {
        print('WebAudioPlayer: Error setting volume: $e');
      }
    }
  }
  
  void dispose() {
    _stopPositionTimer();
    _currentUrl = null;
    _positionController.close();
    _durationController.close();
    _playingController.close();
  }
}