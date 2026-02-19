import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../services/base_service.dart';
import '../layout/breakpoint.dart';
import '../theme.dart';
import 'source_pill.dart';
import 'universal_image.dart';

/// Compact floating bar: artwork, title, artist, SourcePill, play/pause, progress line. Frosted glass. Tap opens full now playing.
class NowPlayingBar extends StatelessWidget {
  final VoidCallback onTap;

  const NowPlayingBar({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final handler = appState.audioHandler;
        if (handler == null) return const SizedBox.shrink();
        return StreamBuilder<MediaItem?>(
          stream: handler.mediaItem,
          builder: (context, snap) {
            final mediaItem = snap.data;
            if (mediaItem == null) return const SizedBox.shrink();
            return StreamBuilder<PlaybackState>(
              stream: handler.playbackState,
              builder: (context, playSnap) {
                final playing = playSnap.data?.playing ?? false;
                return StreamBuilder<Duration>(
                  stream: handler.positionStream,
                  builder: (context, posSnap) {
                    final position = posSnap.data ?? Duration.zero;
                    return StreamBuilder<Duration?>(
                      stream: handler.durationStream,
                      builder: (context, durSnap) {
                        final duration = durSnap.data ?? Duration.zero;
                        final progress = duration.inMilliseconds > 0
                            ? position.inMilliseconds / duration.inMilliseconds
                            : 0.0;
                        final serverType = appState.mediaServiceManager.currentServerType;
                        return GestureDetector(
                          onTap: onTap,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                                child: Container(
                                  height: 72,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(22),
                                    color: Colors.white.withValues(alpha: 0.12),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.12),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          child: Row(
                                            children: [
                                              _artwork(mediaItem),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      mediaItem.title,
                                                      style: const TextStyle(
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.w600,
                                                        color: AppTheme.textPrimary,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      mediaItem.artist ?? 'Unknown Artist',
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        color: AppTheme.textSecondary,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              SourcePill(source: serverType, fontSize: 9),
                                              const SizedBox(width: 8),
                                              IconButton(
                                                icon: Icon(
                                                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                                  color: Theme.of(context).colorScheme.primary,
                                                  size: 28,
                                                ),
                                                onPressed: () => appState.playPause(),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        height: 3,
                                        child: LinearProgressIndicator(
                                          value: progress.clamp(0.0, 1.0),
                                          backgroundColor: AppTheme.surface,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Theme.of(context).colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                    ],
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
              },
            );
          },
        );
      },
    );
  }

  Widget _artwork(MediaItem mediaItem) {
    String? imageUrl = mediaItem.artUri?.toString();
    if (imageUrl == null || imageUrl.isEmpty) {
      imageUrl = mediaItem.extras?['localImageUrl'] as String?;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 52,
        height: 52,
        child: imageUrl != null && imageUrl.isNotEmpty
            ? UniversalImage(imageUrl: imageUrl, width: 52, height: 52)
            : Container(
                color: AppTheme.surface,
                child: Icon(Icons.music_note_rounded, color: AppTheme.textMuted, size: 24),
              ),
      ),
    );
  }
}
