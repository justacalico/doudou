import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/jellyfin_models.dart';
import '../services/jellyfin_service.dart';

class AudioPlayerService extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  final JellyfinService _jellyfinService;
  
  List<Track> _playlist = [];
  int _currentIndex = 0;
  Track? _currentTrack;

  AudioPlayerService(this._jellyfinService) {
    _init();
  }

  void _init() {
    // Listen to player state changes
    _player.playerStateStream.listen((playerState) {
      notifyListeners();
    });

    // Listen to position changes
    _player.positionStream.listen((position) {
      notifyListeners();
    });

    // Auto-play next track when current track completes
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        skipToNext();
      }
    });
  }

  Future<void> play() => _player.play();

  Future<void> pause() => _player.pause();

  Future<void> stop() => _player.stop();

  Future<void> skipToNext() async {
    if (_currentIndex < _playlist.length - 1) {
      _currentIndex++;
      await _playCurrentTrack();
    }
  }

  Future<void> skipToPrevious() async {
    if (_currentIndex > 0) {
      _currentIndex--;
      await _playCurrentTrack();
    }
  }

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> playTrack(Track track) async {
    _playlist = [track];
    _currentIndex = 0;
    await _playCurrentTrack();
  }

  Future<void> playPlaylist(List<Track> tracks, int startIndex) async {
    if (tracks.isEmpty) return;
    
    _playlist = tracks;
    _currentIndex = startIndex.clamp(0, tracks.length - 1);
    await _playCurrentTrack();
  }

  Future<void> _playCurrentTrack() async {
    if (_playlist.isEmpty || _currentIndex >= _playlist.length) return;

    final track = _playlist[_currentIndex];
    _currentTrack = track;
    
    final streamUrl = _jellyfinService.getStreamUrl(track.id);
    
    try {
      await _player.setUrl(streamUrl);
      await _player.play();
      notifyListeners();
      
      if (kDebugMode) {
        print('Playing track: ${track.name}');
        print('Stream URL: $streamUrl');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error playing track: $e');
        print('Stream URL: $streamUrl');
      }
    }
  }

  // Getters
  Track? get currentTrack => _currentTrack;
  List<Track> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _player.playing;
  bool get hasNext => _currentIndex < _playlist.length - 1;
  bool get hasPrevious => _currentIndex > 0;
  
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  PlayerState get playerState => _player.playerState;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
