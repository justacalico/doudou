import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'audio_manager.dart';
import 'audio_service.dart';
import '../../models/jellyfin_models.dart';

/// Provider for the new audio system - replaces the old complex audio providers
class AudioProvider extends ChangeNotifier {
  final AudioManager _audioManager = AudioManager.instance;
  
  AudioPlayerState _playerState = AudioPlayerState.initial();
  
  AudioPlayerState get playerState => _playerState;
  
  // Convenient getters
  bool get isPlaying => _playerState.audioState.isPlaying;
  bool get isLoading => _playerState.audioState.isLoading;
  Duration get position => _playerState.audioState.position;
  Duration? get duration => _playerState.audioState.duration;
  Track? get currentTrack => _playerState.currentTrack;
  List<Track> get playlist => _playerState.playlist;
  bool get shuffle => _playerState.shuffle;
  RepeatMode get repeatMode => _playerState.repeatMode;
  
  // Progress as percentage (0.0 to 1.0)
  double get progress {
    final dur = duration;
    if (dur == null || dur.inMilliseconds == 0) return 0.0;
    return position.inMilliseconds / dur.inMilliseconds;
  }
  
  void initialize() {
    // Listen to audio manager state changes
    _audioManager.playerState.listen((newState) {
      _playerState = newState;
      notifyListeners();
    });
  }
  
  // Playback controls
  Future<void> play() => _audioManager.play();
  Future<void> pause() => _audioManager.pause();
  Future<void> togglePlayPause() => _audioManager.togglePlayPause();
  Future<void> stop() => _audioManager.stop();
  Future<void> seek(Duration position) => _audioManager.seek(position);
  Future<void> skipToNext() => _audioManager.skipToNext();
  Future<void> skipToPrevious() => _audioManager.skipToPrevious();
  Future<void> skipToTrack(int index) => _audioManager.skipToTrack(index);
  
  // Playlist management
  Future<void> playPlaylist(List<Track> tracks, [int startIndex = 0]) => 
      _audioManager.playPlaylist(tracks, startIndex);
  Future<void> playTrack(Track track) => _audioManager.playTrack(track);
  Future<void> addToQueue(Track track) => _audioManager.addToQueue(track);
  Future<void> removeFromQueue(int index) => _audioManager.removeFromQueue(index);
  Future<void> clearQueue() => _audioManager.clearQueue();
  
  // Playback modes
  Future<void> toggleShuffle() => _audioManager.toggleShuffle();
  Future<void> setShuffle(bool enabled) => _audioManager.setShuffle(enabled);
  Future<void> setRepeatMode(RepeatMode mode) => _audioManager.setRepeatMode(mode);
  Future<void> cycleRepeatMode() => _audioManager.cycleRepeatMode();
  
  @override
  void dispose() {
    _audioManager.dispose();
    super.dispose();
  }
}

/// Widget that provides audio functionality to the widget tree
class AudioProviderWidget extends StatefulWidget {
  final Widget child;
  
  const AudioProviderWidget({Key? key, required this.child}) : super(key: key);
  
  @override
  State<AudioProviderWidget> createState() => _AudioProviderWidgetState();
}

class _AudioProviderWidgetState extends State<AudioProviderWidget> {
  late AudioProvider _audioProvider;
  
  @override
  void initState() {
    super.initState();
    _audioProvider = AudioProvider();
    _audioProvider.initialize();
  }
  
  @override
  void dispose() {
    _audioProvider.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AudioProvider>.value(
      value: _audioProvider,
      child: widget.child,
    );
  }
}

/// Example widget showing how to use the new audio system
class SimplePlayerControls extends StatelessWidget {
  const SimplePlayerControls({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (context, audioProvider, child) {
        final currentTrack = audioProvider.currentTrack;
        
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Track info
              if (currentTrack != null)
                Column(
                  children: [
                    Text(
                      currentTrack.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      currentTrack.artistName ?? 'Unknown Artist',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              
              // Progress bar
              if (audioProvider.duration != null)
                Column(
                  children: [
                    LinearProgressIndicator(
                      value: audioProvider.progress,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(audioProvider.position)),
                        Text(_formatDuration(audioProvider.duration!)),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              
              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Shuffle
                  IconButton(
                    icon: Icon(
                      Icons.shuffle,
                      color: audioProvider.shuffle ? Colors.blue : null,
                    ),
                    onPressed: audioProvider.toggleShuffle,
                  ),
                  
                  // Previous
                  IconButton(
                    icon: const Icon(Icons.skip_previous),
                    onPressed: audioProvider.skipToPrevious,
                  ),
                  
                  // Play/Pause
                  IconButton(
                    icon: Icon(
                      audioProvider.isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      size: 48,
                    ),
                    onPressed: audioProvider.togglePlayPause,
                  ),
                  
                  // Next
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    onPressed: audioProvider.skipToNext,
                  ),
                  
                  // Repeat
                  IconButton(
                    icon: Icon(
                      _getRepeatIcon(audioProvider.repeatMode),
                      color: audioProvider.repeatMode != RepeatMode.none 
                          ? Colors.blue 
                          : null,
                    ),
                    onPressed: audioProvider.cycleRepeatMode,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
  
  IconData _getRepeatIcon(RepeatMode mode) {
    switch (mode) {
      case RepeatMode.none:
        return Icons.repeat;
      case RepeatMode.all:
        return Icons.repeat;
      case RepeatMode.one:
        return Icons.repeat_one;
    }
  }
  
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}