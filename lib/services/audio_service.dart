import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import '../models/jellyfin_models.dart';
import '../services/jellyfin_service.dart';

class AudioPlayerService extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();
  final JellyfinService _jellyfinService;
  
  List<Track> _playlist = [];
  int _currentIndex = 0;

  AudioPlayerService(this._jellyfinService) {
    _init();
  }

  void _init() {
    // Listen to player state changes
    _player.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      final processingState = playerState.processingState;
      
      PlaybackState state;
      switch (processingState) {
        case ProcessingState.idle:
          state = PlaybackState(
            controls: [MediaControl.play],
            playing: false,
            processingState: AudioProcessingState.idle,
          );
          break;
        case ProcessingState.loading:
          state = PlaybackState(
            controls: [MediaControl.stop],
            playing: false,
            processingState: AudioProcessingState.loading,
          );
          break;
        case ProcessingState.buffering:
          state = PlaybackState(
            controls: [MediaControl.stop],
            playing: false,
            processingState: AudioProcessingState.buffering,
          );
          break;
        case ProcessingState.ready:
          state = PlaybackState(
            controls: [
              MediaControl.skipToPrevious,
              isPlaying ? MediaControl.pause : MediaControl.play,
              MediaControl.skipToNext,
            ],
            playing: isPlaying,
            processingState: AudioProcessingState.ready,
          );
          break;
        case ProcessingState.completed:
          state = PlaybackState(
            controls: [MediaControl.play],
            playing: false,
            processingState: AudioProcessingState.completed,
          );
          skipToNext();
          break;
      }
      
      playbackState.add(state);
    });

    // Listen to position changes
    _player.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
        bufferedPosition: _player.bufferedPosition,
      ));
    });
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> skipToNext() async {
    if (_currentIndex < _playlist.length - 1) {
      _currentIndex++;
      await _playCurrentTrack();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_currentIndex > 0) {
      _currentIndex--;
      await _playCurrentTrack();
    }
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> playTrack(Track track) async {
    _playlist = [track];
    _currentIndex = 0;
    await _playCurrentTrack();
  }

  Future<void> playPlaylist(List<Track> tracks, int startIndex) async {
    _playlist = tracks;
    _currentIndex = startIndex;
    await _playCurrentTrack();
  }

  Future<void> _playCurrentTrack() async {
    if (_playlist.isEmpty || _currentIndex >= _playlist.length) return;

    final track = _playlist[_currentIndex];
    final streamUrl = _jellyfinService.getStreamUrl(track.id);
    
    // Update media item
    mediaItem.add(MediaItem(
      id: track.id,
      album: track.albumName ?? '',
      title: track.name,
      artist: track.artistName ?? '',
      duration: track.duration != null ? Duration(milliseconds: track.duration!) : null,
      artUri: track.imageUrl != null 
          ? Uri.parse(_jellyfinService.getImageUrl(track.imageUrl!, width: 300, height: 300))
          : null,
    ));

    try {
      await _player.setUrl(streamUrl);
      await _player.play();
    } catch (e) {
      if (kDebugMode) {
        print('Error playing track: $e');
      }
    }
  }

  Track? get currentTrack => 
      _playlist.isNotEmpty && _currentIndex < _playlist.length 
          ? _playlist[_currentIndex] 
          : null;

  List<Track> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  @override
  Future<void> onTaskRemoved() async {
    await stop();
    await super.onTaskRemoved();
  }

  void dispose() {
    _player.dispose();
  }
}
