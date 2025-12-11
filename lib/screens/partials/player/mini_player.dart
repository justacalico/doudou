import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:ui';
import '../../../providers/app_state.dart';
import '../../../models/jellyfin_models.dart';
import '../../playing/now_playing.dart';
import '../../../widgets/cached_image_widget.dart';
import '../../../widgets/apple_design/apple_theme.dart';

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

        // Use the currentTrackStream for reliable real-time updates
        return StreamBuilder<Track?>(
          stream: appState.currentTrackStream,
          builder: (context, currentTrackSnapshot) {
            // Get current track from the stream or fallback to direct access
            final currentTrack = currentTrackSnapshot.data ?? audioHandler?.currentTrack;
            
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
            isDesktop ? 0 : AppleDesignSystem.spacing16,
            isDesktop ? 0 : AppleDesignSystem.spacing8,
            isDesktop ? 0 : AppleDesignSystem.spacing16,
            0
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isDesktop ? 0 : AppleDesignSystem.radiusMedium),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: AppleDesignSystem.blurThin,
                sigmaY: AppleDesignSystem.blurThin,
              ),
              child: Container(
                decoration: BoxDecoration(
                  // Apple glassmorphism effect
                  color: AppleColors.glassDark,
                  borderRadius: BorderRadius.circular(isDesktop ? 0 : AppleDesignSystem.radiusMedium),
                  border: isDesktop ? null : Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 0.5,
                  ),
                  // Shadow only on mobile for floating effect
                  boxShadow: isDesktop ? null : AppleDesignSystem.shadowLarge(Colors.black),
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
                          style: AppleTextStyles.headline(
                            color: AppleColors.labelPrimaryDark,
                          ).copyWith(fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (currentTrack.artistName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            currentTrack.artistName!,
                            style: AppleTextStyles.footnote(
                              color: AppleColors.labelSecondaryDark,
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
