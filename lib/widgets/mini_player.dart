import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../screens/now_playing_screen.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final audioService = appState.audioService;
        final currentTrack = audioService?.currentTrack;
        
        if (currentTrack == null) {
          return const SizedBox.shrink();
        }

        return Container(
          height: 80,
          margin: const EdgeInsets.only(bottom: 85), // Account for tab bar
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            border: Border(
              top: BorderSide(color: Color(0xFF2D2D2D), width: 0.5),
            ),
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
                      width: 60,
                      height: 60,
                      color: const Color(0xFF2D2D2D),
                      child: currentTrack.imageUrl != null
                          ? Image.network(
                              appState.jellyfinService.getImageUrl(
                                currentTrack.imageUrl!,
                                width: 120,
                                height: 120,
                              ),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  CupertinoIcons.music_note,
                                  color: CupertinoColors.systemGrey,
                                  size: 30,
                                );
                              },
                            )
                          : const Icon(
                              CupertinoIcons.music_note,
                              color: CupertinoColors.systemGrey,
                              size: 30,
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
                            color: CupertinoColors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        if (currentTrack.artistName != null)
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
                    ),
                  ),
                  
                  // Control buttons
                  StreamBuilder(
                    stream: audioService?.playerStateStream,
                    builder: (context, snapshot) {
                      final isPlaying = audioService?.isPlaying ?? false;
                      final processingState = audioService?.playerState.processingState;
                      
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Pause/Play button
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              appState.playPause();
                            },
                            child: Icon(
                              isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                              size: 32,
                              color: CupertinoColors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Next button
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: audioService?.hasNext == true
                                ? () => appState.skipToNext()
                                : null,
                            child: Icon(
                              CupertinoIcons.forward_fill,
                              size: 28,
                              color: audioService?.hasNext == true 
                                  ? CupertinoColors.white
                                  : CupertinoColors.systemGrey3,
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
