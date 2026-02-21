import 'dart:async';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

/// Platform-agnostic audio player interface used by [UnifiedAudioHandler].
/// On Windows/macOS/Android/iOS/web: [JustAudioAppPlayer] (just_audio + media_kit).
/// On Linux: [AudioplayersAppPlayer] (audioplayers + GStreamer).
abstract class AppAudioPlayer {
  Future<void> setSource(String url);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> setVolume(double volume);

  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<PlayerState> get playerStateStream;
  Stream<ProcessingState> get processingStateStream;
  Stream<PlaybackEvent> get playbackEventStream;
  Stream<double> get volumeStream;
  Stream<double> get speedStream;

  Duration? get duration;
  Duration get position;
  Duration get bufferedPosition;
  PlayerState get playerState;

  Future<void> dispose();

  /// Recreate underlying player. No-op on Linux; used on Windows/macOS to avoid callback-after-dispose.
  Future<void> recreate();
}

/// just_audio (media_kit on desktop) implementation. Used on Windows, macOS, Android, iOS, web.
class JustAudioAppPlayer implements AppAudioPlayer {
  JustAudioAppPlayer() : _inner = AudioPlayer();

  AudioPlayer _inner;

  @override
  Future<void> setSource(String url) =>
      _inner.setAudioSource(AudioSource.uri(Uri.parse(url)));

  @override
  Future<void> play() => _inner.play();

  @override
  Future<void> pause() => _inner.pause();

  @override
  Future<void> stop() => _inner.stop();

  @override
  Future<void> seek(Duration position) => _inner.seek(position);

  @override
  Future<void> setSpeed(double speed) => _inner.setSpeed(speed);

  @override
  Future<void> setVolume(double volume) => _inner.setVolume(volume);

  @override
  Stream<Duration> get positionStream => _inner.positionStream;

  @override
  Stream<Duration?> get durationStream => _inner.durationStream;

  @override
  Stream<PlayerState> get playerStateStream => _inner.playerStateStream;

  @override
  Stream<ProcessingState> get processingStateStream =>
      _inner.processingStateStream;

  @override
  Stream<PlaybackEvent> get playbackEventStream => _inner.playbackEventStream;

  @override
  Stream<double> get volumeStream => _inner.volumeStream;

  @override
  Stream<double> get speedStream => _inner.speedStream;

  @override
  Duration? get duration => _inner.duration;

  @override
  Duration get position => _inner.position;

  @override
  Duration get bufferedPosition => _inner.bufferedPosition;

  @override
  PlayerState get playerState => _inner.playerState;

  @override
  Future<void> dispose() => _inner.dispose();

  @override
  Future<void> recreate() async {
    await _inner.dispose();
    _inner = AudioPlayer();
  }
}

/// audioplayers (GStreamer) implementation for Linux only.
class AudioplayersAppPlayer implements AppAudioPlayer {
  AudioplayersAppPlayer() {
    _inner = ap.AudioPlayer();
    _volumeSubject = BehaviorSubject<double>.seeded(1.0);
    _speedSubject = BehaviorSubject<double>.seeded(1.0);
    _playerStateSubject = BehaviorSubject<PlayerState>.seeded(
      PlayerState(false, ProcessingState.idle),
    );
    _processingStateSubject =
        BehaviorSubject<ProcessingState>.seeded(ProcessingState.idle);
    _positionSubject = BehaviorSubject<Duration>.seeded(Duration.zero);
    _durationSubject = BehaviorSubject<Duration?>.seeded(null);
    _playbackEventController = StreamController<PlaybackEvent>.broadcast();
    _setupListeners();
  }

  late ap.AudioPlayer _inner;
  late final BehaviorSubject<double> _volumeSubject;
  late final BehaviorSubject<double> _speedSubject;
  late final BehaviorSubject<PlayerState> _playerStateSubject;
  late final BehaviorSubject<ProcessingState> _processingStateSubject;
  late final BehaviorSubject<Duration> _positionSubject;
  late final BehaviorSubject<Duration?> _durationSubject;
  late final StreamController<PlaybackEvent> _playbackEventController;
  Duration _lastPosition = Duration.zero;
  Duration? _lastDuration;
  PlayerState _lastPlayerState = PlayerState(false, ProcessingState.idle);
  bool _disposed = false;

  void _setupListeners() {
    _inner.onPlayerStateChanged.listen((ap.PlayerState state) {
      if (_disposed) return;
      final jaState = _apStateToJustAudio(state);
      _lastPlayerState = jaState;
      _playerStateSubject.add(jaState);
      _processingStateSubject.add(jaState.processingState);
    });
    _inner.onPositionChanged.listen((Duration pos) {
      if (_disposed) return;
      _lastPosition = pos;
      _positionSubject.add(pos);
    });
    _inner.onDurationChanged.listen((Duration d) {
      if (_disposed) return;
      _lastDuration = d;
      _durationSubject.add(d);
    });
    _inner.onPlayerComplete.listen((_) {
      if (_disposed) return;
      final ev = PlaybackEvent(
        processingState: ProcessingState.completed,
        updateTime: DateTime.now(),
        updatePosition: _lastPosition,
        bufferedPosition: _lastDuration ?? _lastPosition,
        duration: _lastDuration,
      );
      _playbackEventController.add(ev);
      _lastPlayerState = PlayerState(false, ProcessingState.completed);
      _playerStateSubject.add(_lastPlayerState);
      _processingStateSubject.add(ProcessingState.completed);
    });
  }

  static PlayerState _apStateToJustAudio(ap.PlayerState state) {
    switch (state) {
      case ap.PlayerState.stopped:
      case ap.PlayerState.disposed:
        return PlayerState(false, ProcessingState.idle);
      case ap.PlayerState.playing:
        return PlayerState(true, ProcessingState.ready);
      case ap.PlayerState.paused:
        return PlayerState(false, ProcessingState.ready);
      case ap.PlayerState.completed:
        return PlayerState(false, ProcessingState.completed);
    }
  }

  @override
  Future<void> setSource(String url) async {
    if (_disposed) return;
    _playerStateSubject.add(PlayerState(false, ProcessingState.loading));
    _processingStateSubject.add(ProcessingState.loading);
    await _inner.setSourceUrl(url);
    _lastPlayerState = PlayerState(false, ProcessingState.ready);
    _playerStateSubject.add(_lastPlayerState);
    _processingStateSubject.add(ProcessingState.ready);
  }

  @override
  Future<void> play() async {
    if (_disposed) return;
    await _inner.resume();
    _lastPlayerState = PlayerState(true, ProcessingState.ready);
    _playerStateSubject.add(_lastPlayerState);
  }

  @override
  Future<void> pause() async {
    if (_disposed) return;
    await _inner.pause();
    _lastPlayerState = PlayerState(false, ProcessingState.ready);
    _playerStateSubject.add(_lastPlayerState);
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    await _inner.stop();
    _lastPosition = Duration.zero;
    _lastPlayerState = PlayerState(false, ProcessingState.idle);
    _playerStateSubject.add(_lastPlayerState);
    _processingStateSubject.add(ProcessingState.idle);
    _positionSubject.add(Duration.zero);
  }

  @override
  Future<void> seek(Duration position) async {
    if (_disposed) return;
    await _inner.seek(position);
    _lastPosition = position;
    _positionSubject.add(position);
  }

  @override
  Future<void> setSpeed(double speed) async {
    if (_disposed) return;
    await _inner.setPlaybackRate(speed);
    _speedSubject.add(speed);
  }

  @override
  Future<void> setVolume(double volume) async {
    if (_disposed) return;
    await _inner.setVolume(volume);
    _volumeSubject.add(volume);
  }

  @override
  Stream<Duration> get positionStream => _positionSubject.stream;

  @override
  Stream<Duration?> get durationStream => _durationSubject.stream;

  @override
  Stream<PlayerState> get playerStateStream => _playerStateSubject.stream;

  @override
  Stream<ProcessingState> get processingStateStream =>
      _processingStateSubject.stream;

  @override
  Stream<PlaybackEvent> get playbackEventStream =>
      _playbackEventController.stream;

  @override
  Stream<double> get volumeStream => _volumeSubject.stream;

  @override
  Stream<double> get speedStream => _speedSubject.stream;

  @override
  Duration? get duration => _lastDuration;

  @override
  Duration get position => _lastPosition;

  @override
  Duration get bufferedPosition => _lastDuration ?? _lastPosition;

  @override
  PlayerState get playerState => _lastPlayerState;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _inner.dispose();
    await _volumeSubject.close();
    await _speedSubject.close();
    await _playerStateSubject.close();
    await _processingStateSubject.close();
    await _positionSubject.close();
    await _durationSubject.close();
    await _playbackEventController.close();
  }

  @override
  Future<void> recreate() async {
    // No-op on Linux; avoids callback-after-dispose only on Windows/macOS.
  }
}

/// Factory that returns the appropriate [AppAudioPlayer] for the current platform.
AppAudioPlayer createAppAudioPlayer() {
  if (defaultTargetPlatform == TargetPlatform.linux) {
    return AudioplayersAppPlayer();
  }
  return JustAudioAppPlayer();
}

/// Whether the current platform uses the just_audio (media_kit) backend (desktop recreation, etc.).
bool get isJustAudioBackend =>
    defaultTargetPlatform != TargetPlatform.linux;
