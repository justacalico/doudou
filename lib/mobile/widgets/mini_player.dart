import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show LinearProgressIndicator;
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import '../theme/app_theme.dart';
import 'cached_artwork.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';

/// Apple Music-style mini player that sits above the tab bar
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
              child: Container(
                height: AppTheme.miniPlayerHeight,
                decoration: BoxDecoration(
                  color: AppTheme.elevated(context),
                  border: Border(
                    top: BorderSide(
                      color: AppTheme.separator(context),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    // Progress indicator
                    StreamBuilder<Duration>(
                      stream: appState.positionStream,
                      builder: (context, positionSnapshot) {
                        final currentTrack = audioHandler.currentTrack;
                        final position = positionSnapshot.data ?? Duration.zero;
                        final duration = currentTrack?.duration != null 
                            ? Duration(milliseconds: currentTrack!.duration!)
                            : Duration.zero;
                        final progress = duration.inMilliseconds > 0
                            ? position.inMilliseconds / duration.inMilliseconds
                            : 0.0;

                        return SizedBox(
                          height: 2,
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            backgroundColor: AppTheme.separator(context),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppTheme.accentPink,
                            ),
                          ),
                        );
                      },
                    ),
                    // Player content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingM,
                        ),
                        child: Row(
                          children: [
                            // Album art
                            CachedArtwork(
                              imageUrl: currentTrack.imageUrl != null
                                  ? appState.getImageUrl(
                                      currentTrack.imageUrl!,
                                      width: 120,
                                      height: 120,
                                    )
                                  : null,
                              size: AppTheme.albumArtSmall,
                              borderRadius: AppTheme.radiusS,
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
                                    style: TextStyle(
                                      fontSize: AppTheme.fontSizeFootnote,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textPrimary(context),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (currentTrack.artistName != null)
                                    Text(
                                      currentTrack.artistName!,
                                      style: TextStyle(
                                        fontSize: AppTheme.fontSizeCaption,
                                        color: AppTheme.textSecondary(context),
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
                                  padding: const EdgeInsets.all(AppTheme.spacingS),
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
                                    color: AppTheme.textPrimary(context),
                                  ),
                                );
                              },
                            ),
                            // Next button
                            CupertinoButton(
                              padding: const EdgeInsets.all(AppTheme.spacingS),
                              minSize: 0,
                              onPressed: () => audioHandler.skipToNext(),
                              child: Icon(
                                CupertinoIcons.forward_fill,
                                size: 24,
                                color: AppTheme.textPrimary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
