import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:ui';
import '../../../providers/app_state.dart';
import '../../playing/now_playing.dart';
import '../../../widgets/cached_image_widget.dart';
import '../../../models/jellyfin_models.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final audioHandler = appState.audioHandler;
        
        // Return empty widget if no audio handler
        if (audioHandler == null) {
          return const SizedBox.shrink();
        }

        // Listen to current track changes in real-time
        return StreamBuilder<Track?>(
          stream: audioHandler.currentTrackStream,
          builder: (context, trackSnapshot) {
            final currentTrack = trackSnapshot.data;
            
            // Return empty widget if no track is playing
            if (currentTrack == null) {
              return const SizedBox.shrink();
            }

        // Determine if we're on a desktop platform
        final isDesktop = !kIsWeb && (defaultTargetPlatform == TargetPlatform.linux ||
                                      defaultTargetPlatform == TargetPlatform.macOS ||
                                      defaultTargetPlatform == TargetPlatform.windows) || kIsWeb;
        
        return Container(
          height: 70,
          margin: EdgeInsets.fromLTRB(
            isDesktop ? 0 : 16, // Full width on desktop, margins on mobile
            isDesktop ? 0 : 8,  // No top margin on desktop for full bar effect
            isDesktop ? 0 : 16, // Full width on desktop, margins on mobile
            0 // No bottom margin for full bar
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isDesktop ? 0 : 12), // No rounded corners on desktop
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  // Glassmorphism effect
                  color: const Color(0xFF000000).withOpacity(isDesktop ? 0.8 : 0.3), // More opaque on desktop for full bar
                  borderRadius: BorderRadius.circular(isDesktop ? 0 : 12), // No rounded corners on desktop
                  border: isDesktop ? null : Border.all(
                    color: const Color(0xFFFFFFFF).withOpacity(0.2), // No border on desktop
                    width: 1,
                  ),
                  // Shadow only on mobile for floating effect
                  boxShadow: isDesktop ? null : const [
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
                  Builder(
                    builder: (context) {
                      return AlbumArtWidget(
                        imageUrl: currentTrack.imageUrl != null
                            ? appState.getImageUrl(
                                currentTrack.imageUrl!,
                                width: 100,
                                height: 100,
                              )
                            : null,
                        size: 50,
                        borderRadius: BorderRadius.circular(8),
                      );
                    },
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
                  StreamBuilder<PlayerState>(
                    stream: appState.playerStateStream,
                    builder: (context, snapshot) {
                      final isPlaying = snapshot.data?.playing == true;
                      final processingState = snapshot.data?.processingState ?? ProcessingState.idle;
                      
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Pause/Play Button
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              if (kDebugMode) {
                                print('=== MINI PLAYER PLAY/PAUSE BUTTON TAPPED ===');
                                print('isPlaying: $isPlaying');
                                print('processingState: $processingState');
                                print('audioHandler.userIntendedPlaying: ${audioHandler.userIntendedPlaying}');
                              }
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
          ), // GestureDetector
        ), // Container
        ), // BackdropFilter
        ), // ClipRRect
        ); // Container - the main container
          }, // StreamBuilder builder
        ); // StreamBuilder
      }, // Consumer builder
    ); // Consumer
  } // build method
} // MiniPlayer class
