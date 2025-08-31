import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import '../providers/app_state.dart';
import '../screens/controller/now_playing.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final audioHandler = appState.audioHandler;
        final currentTrack = audioService?.currentTrack;
        
        if (currentTrack == null) {
          return const SizedBox.shrink();
        }

        return Container(
          height: 70,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2E), // Dark background like in image
            borderRadius: BorderRadius.circular(12),
          ),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                CupertinoPageRoute(
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
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 50,
                      height: 50,
                      color: const Color(0xFF4A4A4A),
                      child: currentTrack.imageUrl != null
                          ? Image.network(
                              appState.jellyfinService.getImageUrl(
                                currentTrack.imageUrl!,
                                width: 100,
                                height: 100,
                              ),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  CupertinoIcons.music_note,
                                  color: CupertinoColors.systemGrey,
                                );
                              },
                            )
                          : const Icon(
                              CupertinoIcons.music_note,
                              color: CupertinoColors.systemGrey,
                            ),
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
                          currentTrack.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: CupertinoColors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (currentTrack.artistName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            currentTrack.artistName!,
                            style: const TextStyle(
                              color: CupertinoColors.systemGrey,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Control Buttons
                  StreamBuilder(
                    stream: audioService?.playerStateStream,
                    builder: (context, snapshot) {
                      final isPlaying = audioService?.isPlaying ?? false;
                      final processingState = audioService?.playerState.processingState;
                      
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Pause/Play Button
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              appState.playPause();
                            },
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: processingState == ProcessingState.loading ||
                                      processingState == ProcessingState.buffering
                                  ? const CupertinoActivityIndicator(
                                      color: CupertinoColors.white,
                                    )
                                  : Icon(
                                      isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                                      size: 24,
                                      color: CupertinoColors.white,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Next Button
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: audioService?.hasNext == true
                                ? () => appState.skipToNext()
                                : null,
                            child: Icon(
                              CupertinoIcons.forward_fill,
                              size: 24,
                              color: audioService?.hasNext == true 
                                  ? CupertinoColors.white
                                  : CupertinoColors.systemGrey,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
