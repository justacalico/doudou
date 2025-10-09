import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'package:flutter/foundation.dart';

class WebAudioPlayer {
  static WebAudioPlayer? _instance;
  static WebAudioPlayer get instance => _instance ??= WebAudioPlayer._();
  
  WebAudioPlayer._() {
    _setupCallbacks();
  }
  
  StreamController<Duration> _positionController = StreamController<Duration>.broadcast();
  StreamController<Duration> _durationController = StreamController<Duration>.broadcast();
  StreamController<bool> _playingController = StreamController<bool>.broadcast();
  
  String? _currentUrl;
  bool _isPlaying = false;
  Timer? _positionTimer;
  
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get durationStream => _durationController.stream;
  Stream<bool> get playingStream => _playingController.stream;
  
  bool get isPlaying => _isPlaying;
  
  Duration get position {
    try {
      final currentTime = js.context['doudouAudio'].callMethod('getCurrentTime') as num;
      return Duration(seconds: currentTime.round());
    } catch (e) {
      return Duration.zero;
    }
  }
  
  Duration get duration {
    try {
      final duration = js.context['doudouAudio'].callMethod('getDuration') as num;
      return Duration(seconds: duration.round());
    } catch (e) {
      return Duration.zero;
    }
  }
  
  void _setupCallbacks() {
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
    if (_audioElementId == null) {
      if (kDebugMode) {
        print('WebAudioPlayer: Cannot play - no audio element');
      }
      return;
    }
    
    try {
      js.context.callMethod('eval', ['document.getElementById("$_audioElementId").play()']);
    } catch (e) {
      if (kDebugMode) {
        print('WebAudioPlayer: Error playing audio: $e');
      }
    }
  }
  
  void pause() {
    if (_audioElementId != null) {
      try {
        js.context.callMethod('eval', ['document.getElementById("$_audioElementId").pause()']);
      } catch (e) {
        if (kDebugMode) {
          print('WebAudioPlayer: Error pausing audio: $e');
        }
      }
    }
  }
  
  void stop() {
    if (_audioElementId != null) {
      try {
        js.context.callMethod('eval', ['''
          var audio = document.getElementById("$_audioElementId");
          audio.pause();
          audio.currentTime = 0;
        ''']);
      } catch (e) {
        if (kDebugMode) {
          print('WebAudioPlayer: Error stopping audio: $e');
        }
      }
    }
  }
  
  void seek(Duration position) {
    if (_audioElementId != null) {
      try {
        js.context.callMethod('eval', ['document.getElementById("$_audioElementId").currentTime = ${position.inSeconds}']);
      } catch (e) {
        if (kDebugMode) {
          print('WebAudioPlayer: Error seeking audio: $e');
        }
      }
    }
  }
  
  void setVolume(double volume) {
    if (_audioElementId != null) {
      final clampedVolume = volume.clamp(0.0, 1.0);
      try {
        js.context.callMethod('eval', ['document.getElementById("$_audioElementId").volume = $clampedVolume']);
      } catch (e) {
        if (kDebugMode) {
          print('WebAudioPlayer: Error setting volume: $e');
        }
      }
    }
  }
  
  void dispose() {
    _stopPositionTimer();
    
    if (_audioElementId != null) {
      try {
        js.context.callMethod('eval', ['''
          var audio = document.getElementById("$_audioElementId");
          if (audio) {
            audio.pause();
            audio.remove();
          }
        ''']);
      } catch (e) {
        if (kDebugMode) {
          print('WebAudioPlayer: Error disposing audio element: $e');
        }
      }
    }
    
    _audioElementId = null;
    _currentUrl = null;
    _positionController.close();
    _durationController.close();
    _playingController.close();
  }
}