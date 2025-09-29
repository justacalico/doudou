import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
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
        
        // Return empty widget if no track is playing
        if (currentTrack == null || audioHandler == null) {
          return const SizedBox.shrink();
        }

        return Container(
          height: 70,
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8), // Balanced margin for floating effect
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  // Glassmorphism effect
                  color: const Color(0xFF000000).withOpacity(0.3), // Semi-transparent dark background
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFFFFFF).withOpacity(0.2), // Subtle white border
                    width: 1,
                  ),
                  // Enhanced shadow for floating effect
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000), // Strong shadow
                      offset: Offset(0, 8), // More dramatic offset
                      blurRadius: 16, // More blur for floating effect
                    ),
                    BoxShadow(
                      color: Color(0x20000000), // Additional subtle shadow
                      offset: Offset(0, 4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => const NowPlayingScreen(),
                  transitionDuration: const Duration(milliseconds: 300),
                  reverseTransitionDuration: const Duration(milliseconds: 300),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    const begin = Offset(0.0, 1.0); // Start from bottom
                    const end = Offset.zero; // End at current position
                    const curve = Curves.easeInOut;

                    var tween = Tween(begin: begin, end: end).chain(
                      CurveTween(curve: curve),
                    );

                    return SlideTransition(
                      position: animation.drive(tween),
                      child: child,
                    );
                  },
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
                            color: Color(0xFFFFFFFF), // Pure white for OLED
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
                    stream: audioHandler.playerStateStream,
                    builder: (context, snapshot) {
                      final isPlaying = audioHandler.isPlaying;
                      final processingState = audioHandler.playerState.processingState;
                      
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
                                      color: Color(0xFFFFFFFF), // Pure white for OLED
                                    )
                                  : Icon(
                                      isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                                      size: 24,
                                      color: const Color(0xFFFFFFFF), // Pure white for OLED
                                    ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Next Button
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: audioHandler.hasNext == true
                                ? () => appState.skipToNext()
                                : null,
                            child: Icon(
                              CupertinoIcons.forward_fill,
                              size: 24,
                              color: audioHandler.hasNext == true 
                                  ? const Color(0xFFFFFFFF) // Pure white for OLED
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
        ))));
      },
    );
  }
}
