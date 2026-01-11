import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import '../theme/app_theme.dart';
import 'cached_artwork.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';

/// Modern mini player with frosted glass effect
class MiniPlayer extends StatelessWidget {
  final VoidCallback? onTap;

  const MiniPlayer({
    super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final audioHandler = appState.audioHandler;
        if (audioHandler == null) return const SizedBox.shrink();

        return StreamBuilder<Track?>(
          stream: appState.currentTrackStream,
          builder: (context, snapshot) {
            final currentTrack = snapshot.data ?? audioHandler.currentTrack;
            if (currentTrack == null) return const SizedBox.shrink();

            return GestureDetector(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingM,
                  vertical: AppTheme.spacingS,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      height: 64,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: CupertinoColors.white.withOpacity(0.1),
                          width: 0.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingM,
                          vertical: AppTheme.spacingS,
                        ),
                        child: Row(
                          children: [
                            // Album art
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedArtwork(
                                imageUrl: currentTrack.imageUrl != null
                                    ? appState.getImageUrl(
                                        currentTrack.imageUrl!,
                                        width: 120,
                                        height: 120,
                                      )
                                    : null,
                                size: 48,
                                borderRadius: 8,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingM),
                            // Track info
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentTrack.name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: CupertinoColors.white,
                                      decoration: TextDecoration.none,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    currentTrack.artistName ?? 'Unknown Artist',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: CupertinoColors.white.withOpacity(0.6),
                                      decoration: TextDecoration.none,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            // Play/Pause button
                            StreamBuilder<PlayerState>(
                              stream: appState.playerStateStream,
                              builder: (context, stateSnapshot) {
                                final isPlaying = stateSnapshot.data?.playing ?? false;

                                return CupertinoButton(
                                  padding: const EdgeInsets.all(8),
                                  minSize: 0,
                                  onPressed: () {
                                    if (isPlaying) {
                                      audioHandler.pause();
                                    } else {
                                      audioHandler.play();
                                    }
                                  },
                                  child: Icon(
                                    isPlaying
                                        ? CupertinoIcons.pause_fill
                                        : CupertinoIcons.play_fill,
                                    size: 28,
                                    color: CupertinoColors.white,
                                  ),
                                );
                              },
                            ),
                            // Next button
                            CupertinoButton(
                              padding: const EdgeInsets.all(8),
                              minSize: 0,
                              onPressed: () => audioHandler.skipToNext(),
                              child: const Icon(
                                CupertinoIcons.forward_fill,
                                size: 24,
                                color: CupertinoColors.white,
                              ),
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
      },
    );
  }
}
