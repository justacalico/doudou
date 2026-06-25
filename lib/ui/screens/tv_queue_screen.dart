import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '/ui/player/player_controller.dart';
import '/ui/widgets/image_widget.dart';
import '/ui/widgets/tv_focus_highlight.dart';

class TvQueueScreen extends StatelessWidget {
  const TvQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final playerController = Get.find<PlayerController>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: FocusTraversalGroup(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Text(
                      'Up Next',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Obx(() {
                      final count = playerController.currentQueue.length;
                      return Text(
                        '$count songs',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      );
                    }),
                    const Spacer(),
                    // Queue controls
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Loop toggle
                        Obx(() {
                          final loopEnabled =
                              playerController.isQueueLoopModeEnabled.isTrue;
                          return TvFocusHighlight(
                            borderRadius: 8,
                            debugLabel: 'TVQueueLoop',
                            onSelect: () =>
                                playerController.toggleQueueLoopMode(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: loopEnabled
                                    ? theme.colorScheme.primary
                                        .withValues(alpha: 0.15)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: loopEnabled
                                      ? theme.colorScheme.primary
                                      : theme.dividerColor,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.loop_rounded,
                                    size: 24,
                                    color: loopEnabled
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Loop',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: loopEnabled
                                          ? theme.colorScheme.primary
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(width: 16),
                        // Shuffle
                        TvFocusHighlight(
                          borderRadius: 8,
                          debugLabel: 'TVQueueShuffle',
                          onSelect: () => playerController.shuffleQueue(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: theme.dividerColor),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.shuffle_rounded,
                                  size: 24,
                                  color: theme.colorScheme.onSurface,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Shuffle',
                                  style: theme.textTheme.titleSmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Clear
                        TvFocusHighlight(
                          borderRadius: 8,
                          debugLabel: 'TVQueueClear',
                          onSelect: () => playerController.clearQueue(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: theme.dividerColor),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.playlist_remove_rounded,
                                  size: 24,
                                  color: theme.colorScheme.onSurface,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Clear',
                                  style: theme.textTheme.titleSmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Queue list
                Expanded(
                  child: Obx(() {
                    final queue = playerController.currentQueue;
                    final currentSong = playerController.currentSong.value;
                    final currentIndex =
                        playerController.currentSongIndex.value;

                    if (queue.isEmpty) {
                      return Center(
                        child: Text(
                          'Queue is empty',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: queue.length,
                      itemBuilder: (context, index) {
                        final song = queue[index];
                        final isCurrent = song.id == currentSong?.id;
                        final isPast = index < currentIndex;

                        return TvFocusHighlight(
                          borderRadius: 8,
                          debugLabel: 'TVQueueItem_$index',
                          onSelect: () {
                            playerController.playPlayListSong(queue, index);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? theme.colorScheme.primary
                                      .withValues(alpha: 0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: isCurrent
                                  ? Border.all(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.3),
                                    )
                                  : null,
                            ),
                            child: Row(
                              children: [
                                // Index or playing indicator
                                SizedBox(
                                  width: 40,
                                  child: isCurrent
                                      ? Icon(
                                          Icons.play_arrow_rounded,
                                          color: theme.colorScheme.primary,
                                          size: 28,
                                        )
                                      : Text(
                                          '${index + 1}',
                                          style:
                                              theme.textTheme.titleMedium?.copyWith(
                                            color: isPast
                                                ? theme.colorScheme.onSurface
                                                    .withValues(alpha: 0.3)
                                                : theme.colorScheme.onSurfaceVariant,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                ),
                                const SizedBox(width: 16),
                                // Album art
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: ImageWidget(size: 48, song: song),
                                ),
                                const SizedBox(width: 16),
                                // Title and artist
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        song.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style:
                                            theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: isCurrent
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: isCurrent
                                              ? theme.colorScheme.primary
                                              : isPast
                                                  ? theme.colorScheme.onSurface
                                                      .withValues(alpha: 0.3)
                                                  : null,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        song.artist ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Remove button
                                TvFocusHighlight(
                                  borderRadius: 6,
                                  debugLabel: 'TVQueueRemove_$index',
                                  onSelect: () =>
                                      playerController.removeFromQueue(song),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 24,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }),
                ),
                const SizedBox(height: 24),
                // Back button
                Center(
                  child: TvFocusHighlight(
                    borderRadius: 8,
                    debugLabel: 'TVQueueBack',
                    autofocus: true,
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
        ),
      ),
    );
  }
}
