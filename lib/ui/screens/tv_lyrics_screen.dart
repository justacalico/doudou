import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '/ui/player/player_controller.dart';
import '/ui/widgets/image_widget.dart';
import '/ui/widgets/tv_focus_highlight.dart';

class TvLyricsScreen extends StatefulWidget {
  const TvLyricsScreen({super.key});

  @override
  State<TvLyricsScreen> createState() => _TvLyricsScreenState();
}

class _TvLyricsScreenState extends State<TvLyricsScreen> {
  final _scrollController = ScrollController();
  int _lastActiveLine = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActiveLine(int index, int totalLines) {
    if (index < 0 || totalLines == 0) return;
    if (index == _lastActiveLine) return;
    _lastActiveLine = index;

    // Each line is roughly 56px tall, center it in view
    const lineHeight = 56.0;
    final targetOffset = (index * lineHeight) - 200;
    _scrollController.animateTo(
      targetOffset.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

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
              // Main content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        Obx(() {
                          final song = playerController.currentSong.value;
                          return Row(
                            children: [
                              if (song != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: ImageWidget(size: 40, song: song),
                                ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    song?.title ?? '',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    song?.artist ?? '',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }),
                        const Spacer(),
                        // Synced / Plain toggle
                        Obx(() {
                          if (!playerController.showLyricsflag.value) {
                            return const SizedBox.shrink();
                          }
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _TvLyricsModeButton(
                                label: 'Synced',
                                selected: playerController.lyricsMode.value == 0,
                                onSelect: () =>
                                    playerController.changeLyricsMode(0),
                              ),
                              const SizedBox(width: 12),
                              _TvLyricsModeButton(
                                label: 'Plain',
                                selected: playerController.lyricsMode.value == 1,
                                onSelect: () =>
                                    playerController.changeLyricsMode(1),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Lyrics content
                    Expanded(
                      child: Obx(() {
                        if (playerController.isLyricsLoading.isTrue) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final mode = playerController.lyricsMode.value;
                        final syncedLines = playerController.syncedLyricLines;

                        // Plain lyrics mode
                        if (mode == 1 || syncedLines.isEmpty) {
                          final plain = playerController.lyrics['plainLyrics']
                                  ?.toString() ??
                              '';
                          if (plain.isEmpty || plain == 'NA') {
                            return Center(
                              child: Text(
                                'Lyrics not available',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            );
                          }
                          return SingleChildScrollView(
                            controller: _scrollController,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 120, vertical: 24),
                              child: Text(
                                plain,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  height: 1.8,
                                  fontSize: 22,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }

                        // Synced lyrics mode
                        final pos = playerController
                            .progressBarStatus.value.current;
                        final activeIndex =
                            playerController.currentSyncedLyricLineIndex(pos);

                        // Scroll to active line
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _scrollToActiveLine(activeIndex, syncedLines.length);
                        });

                        return SingleChildScrollView(
                          controller: _scrollController,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 120, vertical: 200),
                            child: Column(
                              children: List.generate(syncedLines.length, (i) {
                                final line = syncedLines[i];
                                final isActive = i == activeIndex;
                                final isPast = i < activeIndex;

                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    line.text,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontSize: isActive ? 28 : 22,
                                      fontWeight:
                                          isActive ? FontWeight.w700 : FontWeight.w400,
                                      color: isActive
                                          ? theme.colorScheme.primary
                                          : isPast
                                              ? theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.3)
                                              : theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.7),
                                      height: 1.4,
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),
                    // Bottom controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TvFocusHighlight(
                          borderRadius: 8,
                          debugLabel: 'TVLyricsBack',
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
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TvLyricsModeButton extends StatelessWidget {
  const _TvLyricsModeButton({
    required this.label,
    required this.selected,
    required this.onSelect,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TvFocusHighlight(
      borderRadius: 8,
      onSelect: onSelect,
      debugLabel: 'LyricsMode_$label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : theme.dividerColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? theme.colorScheme.primary : null,
          ),
        ),
      ),
    );
  }
}
