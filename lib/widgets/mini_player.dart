import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
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
          height: 70,
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground.resolveFrom(context),
            border: Border(
              top: BorderSide(color: CupertinoColors.separator.resolveFrom(context)),
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
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      width: 50,
                      height: 50,
                      color: CupertinoColors.systemGrey4.resolveFrom(context),
                      child: currentTrack.imageUrl != null
                          ? Image.network(
                              appState.jellyfinService.getImageUrl(
                                currentTrack.imageUrl!,
                                width: 100,
                                height: 100,
                              ),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(CupertinoIcons.music_note);
                              },
                            )
                          : const Icon(CupertinoIcons.music_note),
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
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (currentTrack.artistName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            currentTrack.artistName!,
                            style: TextStyle(
                              color: CupertinoColors.secondaryLabel.resolveFrom(context),
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
                  StreamBuilder(
                    stream: audioService?.playerStateStream,
                    builder: (context, snapshot) {
                      final isPlaying = audioService?.isPlaying ?? false;
                      final processingState = audioService?.playerState.processingState;
                      
                      if (processingState == ProcessingState.loading ||
                          processingState == ProcessingState.buffering) {
                        return const SizedBox(
                          width: 40,
                          height: 40,
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CupertinoActivityIndicator(),
                            ),
                          ),
                        );
                      }
                      
                      return CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          appState.playPause();
                        },
                        child: Icon(
                          isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_arrow_solid,
                          size: 28,
                        ),
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
