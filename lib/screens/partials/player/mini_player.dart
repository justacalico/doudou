import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:ui';
import '../../../providers/app_state.dart';
import '../../playing/now_playing.dart';
import '../../../widgets/cached_image_widget.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final audioHandler = appState.audioHandler;
        final currentTrack = audioHandler?.currentTrack;
        
        // Check if we're on the settings screen
        final currentRoute = ModalRoute.of(context)?.settings.name;
        final isSettingsScreen = currentRoute == '/settings' || 
                                ModalRoute.of(context)?.settings.arguments == 'settings';
        
        // Also check if the current widget tree contains SettingsScreen
        bool isOnSettingsPage = false;
        context.visitAncestorElements((element) {
          if (element.widget.toString().contains('SettingsScreen')) {
            isOnSettingsPage = true;
            return false; // Stop traversing
          }
          return true; // Continue traversing
        });
        
        if (currentTrack == null || isSettingsScreen || isOnSettingsPage) {
          return const SizedBox.shrink();
        }

        return Container(
          height: 70,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF000000).withOpacity(0.3), // Semi-transparent black
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFFFFFF).withOpacity(0.1), // Subtle white border
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF000000).withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
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
                        AlbumArtWidget(
                          imageUrl: currentTrack.imageUrl != null
                              ? appState.jellyfinService.getImageUrl(
                                  currentTrack.imageUrl!,
                                  width: 100,
                                  height: 100,
                                )
                              : null,
                          size: 50,
                          borderRadius: BorderRadius.circular(8),
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
                                  color: Color(0xFFFFFFFF), // Pure white for glass effect
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (currentTrack.artistName != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  currentTrack.artistName!,
                                  style: const TextStyle(
                                    color: CupertinoColors.systemGrey2,
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
                          stream: audioHandler?.playerStateStream,
                          builder: (context, snapshot) {
                            final isPlaying = audioHandler?.isPlaying ?? false;
                            final processingState = audioHandler?.playerState.processingState;
                            
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
                                            color: Color(0xFFFFFFFF), // Pure white for glass effect
                                          )
                                        : Icon(
                                            isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                                            size: 24,
                                            color: const Color(0xFFFFFFFF), // Pure white for glass effect
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Next Button
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: audioHandler?.hasNext == true
                                      ? () => appState.skipToNext()
                                      : null,
                                  child: Icon(
                                    CupertinoIcons.forward_fill,
                                    size: 24,
                                    color: audioHandler?.hasNext == true 
                                        ? const Color(0xFFFFFFFF) // Pure white for glass effect
                                        : CupertinoColors.systemGrey2,
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
              ),
            ),
          ),
        );
      },
    );
  }
}
