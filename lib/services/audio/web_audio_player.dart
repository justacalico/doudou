import 'dart:async';
import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class WebAudioPlayer {
  static WebAudioPlayer? _instance;
  static WebAudioPlayer get instance => _instance ??= WebAudioPlayer._();
  
  WebAudioPlayer._();
  
  String? _audioElementId;
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
    if (_audioElementId == null) return Duration.zero;
    try {
      final currentTime = js.context.callMethod('eval', ['document.getElementById("$_audioElementId").currentTime']) as num;
      return Duration(seconds: currentTime.round());
    } catch (e) {
      return Duration.zero;
    }
  }
  
  Duration get duration {
    if (_audioElementId == null) return Duration.zero;
    try {
      final duration = js.context.callMethod('eval', ['document.getElementById("$_audioElementId").duration']) as num;
      return Duration(seconds: duration.round());
    } catch (e) {
      return Duration.zero;
    }
  }
  
  Future<void> setUrl(String url) async {
    if (_currentUrl == url && _audioElement != null) {
      return; // Already loaded
    }
    
    if (kDebugMode) {
      print('WebAudioPlayer: Setting URL: $url');
    }
    
    // Create new audio element
    _audioElement?.pause();
    _audioElement = html.AudioElement();
    _currentUrl = url;
    
    // Set up event listeners
    _audioElement!.onLoadedMetadata.listen((_) {
      _durationController.add(duration);
      if (kDebugMode) {
        print('WebAudioPlayer: Loaded metadata, duration: ${duration.inSeconds}s');
      }
    });
    
    _audioElement!.onTimeUpdate.listen((_) {
      _positionController.add(position);
    });
    
    _audioElement!.onPlay.listen((_) {
      _isPlaying = true;
      _playingController.add(true);
      if (kDebugMode) {
        print('WebAudioPlayer: Playback started');
      }
    });
    
    _audioElement!.onPause.listen((_) {
      _isPlaying = false;
      _playingController.add(false);
      if (kDebugMode) {
        print('WebAudioPlayer: Playback paused');
      }
    });
    
    _audioElement!.onEnded.listen((_) {
      _isPlaying = false;
      _playingController.add(false);
      if (kDebugMode) {
        print('WebAudioPlayer: Playback ended');
      }
    });
    
    _audioElement!.onError.listen((event) {
      if (kDebugMode) {
        print('WebAudioPlayer: Error loading audio: $event');
      }
    });
    
    // Set the source
    _audioElement!.src = url;
    _audioElement!.preload = 'metadata';
    
    try {
      _audioElement!.load();
    } catch (e) {
      if (kDebugMode) {
        print('WebAudioPlayer: Error loading audio: $e');
      }
    }
  }
  
  Future<void> play() async {
    if (_audioElement == null) {
      if (kDebugMode) {
        print('WebAudioPlayer: Cannot play - no audio element');
      }
      return;
    }
    
    try {
      await _audioElement!.play();
    } catch (e) {
      if (kDebugMode) {
        print('WebAudioPlayer: Error playing audio: $e');
      }
    }
  }
  
  void pause() {
    _audioElement?.pause();
  }
  
  void stop() {
    if (_audioElement != null) {
      _audioElement!.pause();
      _audioElement!.currentTime = 0;
    }
  }
  
  void seek(Duration position) {
    if (_audioElement != null) {
      _audioElement!.currentTime = position.inSeconds.toDouble();
    }
  }
  
  void setVolume(double volume) {
    if (_audioElement != null) {
      _audioElement!.volume = volume.clamp(0.0, 1.0);
    }
  }
  
  void dispose() {
    _audioElement?.pause();
    _audioElement = null;
    _positionController.close();
    _durationController.close();
    _playingController.close();
  }
}