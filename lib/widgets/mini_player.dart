import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import '../screens/now_playing_screen.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: AudioService.currentMediaItemStream,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;
        if (mediaItem == null) {
          return const SizedBox.shrink();
        }

        return Container(
          height: 70,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(
              top: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NowPlayingScreen(),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // Album Art
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        width: 50,
                        height: 50,
                        color: Colors.grey[300],
                        child: mediaItem.artUri != null
                            ? Image.network(
                                mediaItem.artUri.toString(),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.music_note);
                                },
                              )
                            : const Icon(Icons.music_note),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Track Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            mediaItem.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (mediaItem.artist != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              mediaItem.artist!,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    // Play/Pause Button
                    StreamBuilder<PlaybackState>(
                      stream: AudioService.playbackStateStream,
                      builder: (context, snapshot) {
                        final playbackState = snapshot.data;
                        final isPlaying = playbackState?.playing ?? false;
                        final processingState = playbackState?.processingState ?? AudioProcessingState.idle;
                        
                        if (processingState == AudioProcessingState.loading ||
                            processingState == AudioProcessingState.buffering) {
                          return const SizedBox(
                            width: 40,
                            height: 40,
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          );
                        }
                        
                        return IconButton(
                          icon: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            size: 28,
                          ),
                          onPressed: () {
                            if (isPlaying) {
                              AudioService.pause();
                            } else {
                              AudioService.play();
                            }
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
