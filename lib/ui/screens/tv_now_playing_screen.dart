import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '/ui/player/player_controller.dart';
import '/ui/widgets/image_widget.dart';
import '/ui/widgets/lyrics_dialog.dart';
import '/ui/widgets/tv_focus_highlight.dart';

class TvNowPlayingScreen extends StatelessWidget {
  const TvNowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final playerController = Get.find<PlayerController>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: FocusTraversalGroup(
        child: SafeArea(
          child: Stack(
            children: [
              // Brand logo + text top-left
              Positioned(
                top: 24,
                left: 80,
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/icons/icon.png',
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.music_note_rounded,
                          size: 28,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Doudou',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Main content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
                child: Obx(() {
                  final song = playerController.currentSong.value;
                  if (song == null) {
                    return Center(
                      child: Text(
                        'No song playing',
                        style: theme.textTheme.headlineMedium,
                      ),
                    );
                  }
                  return Row(
                    children: [
                      // Left: album art
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: ImageWidget(
                              size: 320,
                              song: song,
                              isPlayerArtImage: true,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 64),
                      // Right: track info + controls
                      Expanded(
                        flex: 3,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            Text(
                              song.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Artist
                            Text(
                              song.artist ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 40),
                            // Progress bar
                            GetX<PlayerController>(
                              init: playerController,
                              builder: (pc) => ProgressBar(
                                timeLabelLocation: TimeLabelLocation.sides,
                                thumbRadius: 8,
                                barHeight: 5,
                                thumbGlowRadius: 0,
                                baseBarColor: theme.colorScheme.outlineVariant
                                    .withValues(alpha: 0.3),
                                bufferedBarColor:
                                    theme.colorScheme.primary.withValues(alpha: 0.2),
                                progressBarColor: theme.colorScheme.primary,
                                thumbColor: theme.colorScheme.primary,
                                timeLabelTextStyle:
                                    theme.textTheme.titleMedium?.copyWith(
                                  fontSize: 16,
                                ),
                                progress: pc.progressBarStatus.value.current,
                                total: pc.progressBarStatus.value.total,
                                buffered: pc.progressBarStatus.value.buffered,
                                onSeek: pc.seek,
                              ),
                            ),
                            const SizedBox(height: 48),
                            // Controls
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                // Prev
                                TvFocusHighlight(
                                  borderRadius: 12,
                                  debugLabel: 'TVPrev',
                                  onSelect: () => playerController.prev(),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Icon(
                                      Icons.skip_previous_rounded,
                                      size: 48,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 32),
                                // Play/Pause
                                Obx(() {
                                  final state = playerController.buttonState.value;
                                  final isPlaying = state == PlayButtonState.playing;
                                  final isLoading = state == PlayButtonState.loading;
                                  return TvFocusHighlight(
                                    borderRadius: 16,
                                    autofocus: true,
                                    debugLabel: 'TVPlayPause',
                                    onSelect: () {
                                      if (isLoading) return;
                                      isPlaying
                                          ? playerController.pause()
                                          : playerController.play();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: isLoading
                                          ? SizedBox(
                                              width: 36,
                                              height: 36,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 3,
                                                color: theme.colorScheme.onPrimary,
                                              ),
                                            )
                                          : Icon(
                                              isPlaying
                                                  ? Icons.pause_rounded
                                                  : Icons.play_arrow_rounded,
                                              size: 48,
                                              color: theme.colorScheme.onPrimary,
                                            ),
                                    ),
                                  );
                                }),
                                const SizedBox(width: 32),
                                // Next
                                TvFocusHighlight(
                                  borderRadius: 12,
                                  debugLabel: 'TVNext',
                                  onSelect: () => playerController.next(),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Icon(
                                      Icons.skip_next_rounded,
                                      size: 48,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 32),
                                // Favourite toggle
                                Obx(() {
                                  final isFav = playerController.isCurrentSongFav.value;
                                  return TvFocusHighlight(
                                    borderRadius: 12,
                                    debugLabel: 'TVFav',
                                    onSelect: () => playerController.toggleFavourite(),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Icon(
                                        isFav
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_border_rounded,
                                        size: 44,
                                        color: isFav
                                            ? theme.colorScheme.error
                                            : theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  );
                                }),
                                const SizedBox(width: 32),
                                // Lyrics
                                TvFocusHighlight(
                                  borderRadius: 12,
                                  debugLabel: 'TVLyrics',
                                  onSelect: () {
                                    playerController.showLyrics();
                                    showDialog(
                                      context: context,
                                      builder: (context) => const LyricsDialog(),
                                    ).whenComplete(() {
                                      playerController.isDesktopLyricsDialogOpen = false;
                                      playerController.showLyricsflag.value = false;
                                    });
                                    playerController.isDesktopLyricsDialogOpen = true;
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Icon(
                                      Icons.mic_rounded,
                                      size: 44,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            ),
                            const SizedBox(height: 32),
                            // Back button
                            Center(
                              child: TvFocusHighlight(
                                borderRadius: 8,
                                debugLabel: 'TVBack',
                                onSelect: () => Navigator.of(context).pop(),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 32, vertical: 12),
                                  child: Text(
                                    'Back',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
