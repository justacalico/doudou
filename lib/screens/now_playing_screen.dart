import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Now Playing'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<MediaItem?>(
        stream: AudioService.currentMediaItemStream,
        builder: (context, snapshot) {
          final mediaItem = snapshot.data;
          if (mediaItem == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No music playing',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Spacer(),
                
                // Album Art
                Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: mediaItem.artUri != null
                        ? Image.network(
                            mediaItem.artUri.toString(),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[300],
                                child: const Icon(Icons.music_note, size: 100),
                              );
                            },
                          )
                        : Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.music_note, size: 100),
                          ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Track Info
                Text(
                  mediaItem.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                if (mediaItem.artist != null)
                  Text(
                    mediaItem.artist!,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                if (mediaItem.album != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    mediaItem.album!,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                
                const SizedBox(height: 40),
                
                // Progress Bar
                StreamBuilder<Duration>(
                  stream: AudioService.positionStream,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final duration = mediaItem.duration ?? Duration.zero;
                    
                    return Column(
                      children: [
                        Slider(
                          value: duration.inMilliseconds > 0
                              ? position.inMilliseconds / duration.inMilliseconds
                              : 0.0,
                          onChanged: (value) {
                            final newPosition = Duration(
                              milliseconds: (value * duration.inMilliseconds).round(),
                            );
                            AudioService.customAction('seek', {'position': newPosition.inMilliseconds});
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatDuration(position)),
                              Text(_formatDuration(duration)),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                
                const SizedBox(height: 20),
                
                // Control Buttons
                StreamBuilder<PlaybackState>(
                  stream: AudioService.playbackStateStream,
                  builder: (context, snapshot) {
                    final playbackState = snapshot.data;
                    final isPlaying = playbackState?.playing ?? false;
                    final processingState = playbackState?.processingState ?? AudioProcessingState.idle;
                    
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          iconSize: 48,
                          icon: const Icon(Icons.skip_previous),
                          onPressed: () => AudioService.skipToPrevious(),
                        ),
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.deepPurple,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.deepPurple.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: processingState == AudioProcessingState.loading ||
                                  processingState == AudioProcessingState.buffering
                              ? const Center(
                                  child: SizedBox(
                                    width: 30,
                                    height: 30,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  ),
                                )
                              : IconButton(
                                  iconSize: 40,
                                  icon: Icon(
                                    isPlaying ? Icons.pause : Icons.play_arrow,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {
                                    if (isPlaying) {
                                      AudioService.pause();
                                    } else {
                                      AudioService.play();
                                    }
                                  },
                                ),
                        ),
                        IconButton(
                          iconSize: 48,
                          icon: const Icon(Icons.skip_next),
                          onPressed: () => AudioService.skipToNext(),
                        ),
                      ],
                    );
                  },
                ),
                
                const Spacer(),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }
}
