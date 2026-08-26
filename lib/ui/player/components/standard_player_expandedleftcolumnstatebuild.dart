part of 'standard_player.dart';

mixin _ExpandedLeftColumnStateBuildMixin on _ExpandedLeftColumnStateBase {
  @override
  Widget build(BuildContext context) {
    final pc = widget.pc;
    final textColor = widget.textColor;
    final mutedColor = widget.mutedColor;
    final surfaceColor = widget.surfaceColor;
    final metrics = widget.metrics;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: metrics.horizontalPadding,
          vertical: metrics.verticalPadding,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(() {
              if (pc.currentSong.value == null) return const SizedBox.shrink();
              final artSize = metrics.artSize;
              return Center(
                child: Container(
                  width: artSize,
                  height: artSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ImageWidget(
                    size: artSize,
                    song: pc.currentSong.value!,
                    isPlayerArtImage: true,
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),
            Obx(() {
              final song = pc.currentSong.value;
              return Column(
                children: [
                  Text(
                    song?.title ?? '—',
                    style: TextStyle(
                      fontSize: metrics.isDense ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (pc.isRadioModeOn)
                        Icon(
                          Icons.radio,
                          size: metrics.isDense ? 14 : 16,
                          color: textColor.withValues(alpha: 0.7),
                        ),
                      if (pc.isRadioModeOn) const SizedBox(width: 4),
                      Flexible(
                        child: Text.rich(
                          TextSpan(
                            text: context.l10n.fromAlbum,
                            style: TextStyle(
                              fontSize: metrics.isDense ? 13 : 14,
                              color: mutedColor,
                            ),
                            children: [
                              TextSpan(
                                text: song?.album ?? pc.playinfrom.value.nameString,
                                style: TextStyle(
                                  fontSize: metrics.isDense ? 13 : 14,
                                  color: textColor.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      text: context.l10n.byArtist,
                      style: TextStyle(
                        fontSize: metrics.isDense ? 13 : 14,
                        color: mutedColor,
                      ),
                      children: [
                        TextSpan(
                          text: song?.artist ?? '—',
                          style: TextStyle(
                            fontSize: metrics.isDense ? 13 : 14,
                            color: textColor.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            }),
            SizedBox(height: metrics.panelGap),
            Obx(() {
              final status = pc.progressBarStatus.value;
              final total = status.total;
              final current = status.current;
              final progress = total.inMilliseconds > 0
                  ? (current.inMilliseconds / total.inMilliseconds)
                      .clamp(0.0, 1.0)
                  : 0.0;
              return Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 14),
                      activeTrackColor: textColor,
                      inactiveTrackColor: surfaceColor,
                      thumbColor: textColor,
                    ),
                    child: Slider(
                      value: progress,
                      onChanged: (v) {
                        pc.seek(Duration(
                            milliseconds: (v * total.inMilliseconds).round()));
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(current),
                          style: TextStyle(fontSize: 12, color: mutedColor),
                        ),
                        Text(
                          _formatDuration(total),
                          style: TextStyle(fontSize: 12, color: mutedColor),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
            SizedBox(height: metrics.isDense ? 10 : 16),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: _showVolumePanel
                  ? Column(
                      children: [
                        const SizedBox(height: 8),
                        Obx(() {
                          final v = pc.volume.value;
                          return Row(
                            children: [
                              Icon(
                                v == 0
                                    ? Icons.volume_off_rounded
                                    : v < 50
                                        ? Icons.volume_down_rounded
                                        : Icons.volume_up_rounded,
                                color: mutedColor,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 3,
                                    thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 6),
                                    overlayShape: const RoundSliderOverlayShape(
                                        overlayRadius: 12),
                                    activeTrackColor: textColor,
                                    inactiveTrackColor: surfaceColor,
                                    thumbColor: textColor,
                                  ),
                                  child: Slider(
                                    value: v / 100,
                                    onChanged: (value) {
                                      pc.setVolume(
                                          (value * 100).round().clamp(0, 100));
                                    },
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                        SizedBox(height: metrics.isDense ? 10 : 16),
                      ],
                    )
                  : const SizedBox(height: 0),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Obx(() => IconButton(
                            onPressed: pc.toggleShuffleMode,
                            icon: Icon(
                              Icons.shuffle_rounded,
                              color: pc.isShuffleModeEnabled.isTrue
                                  ? Theme.of(context).colorScheme.primary
                                  : mutedColor,
                            ),
                          )),
                      SizedBox(width: metrics.controlGapLarge),
                      IconButton(
                        onPressed: pc.prev,
                        icon: Icon(Icons.skip_previous_rounded,
                            size: 32, color: textColor),
                      ),
                      SizedBox(width: metrics.controlGapSmall),
                      Obx(() {
                        final playing =
                            pc.buttonState.value == PlayButtonState.playing;
                        return GestureDetector(
                          onTap: () => pc.playPause(),
                          child: Container(
                            width: metrics.playButtonSize,
                            height: metrics.playButtonSize,
                            decoration: BoxDecoration(
                              color: textColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Theme.of(context).scaffoldBackgroundColor,
                              size: 36,
                            ),
                          ),
                        );
                      }),
                      const SizedBox(width: 16),
                      IconButton(
                        onPressed: pc.next,
                        icon: Icon(Icons.skip_next_rounded,
                            size: 32, color: textColor),
                      ),
                      SizedBox(width: metrics.controlGapLarge),
                      Obx(() => IconButton(
                            onPressed: pc.toggleLoopMode,
                            icon: Icon(
                              pc.isLoopModeEnabled.isTrue
                                  ? Icons.repeat_one_rounded
                                  : Icons.repeat_rounded,
                              color: pc.isLoopModeEnabled.isTrue
                                  ? Theme.of(context).colorScheme.primary
                                  : mutedColor,
                            ),
                          )),
                      SizedBox(width: metrics.controlGapLarge),
                      Obx(() {
                        final v = pc.volume.value;
                        return IconButton(
                          onPressed: () {
                            setState(
                                () => _showVolumePanel = !_showVolumePanel);
                          },
                          icon: Icon(
                            v == 0
                                ? Icons.volume_off_rounded
                                : v < 50
                                    ? Icons.volume_down_rounded
                                    : Icons.volume_up_rounded,
                            color: _showVolumePanel
                                ? Theme.of(context).colorScheme.primary
                                : mutedColor,
                          ),
                        );
                      }),
                      SizedBox(width: metrics.controlGapLarge),
                      Obx(() => IconButton(
                            onPressed: pc.toggleFavourite,
                            icon: Icon(
                              pc.isCurrentSongFav.isTrue
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: pc.isCurrentSongFav.isTrue
                                  ? const Color(0xFFEC4899)
                                  : mutedColor,
                            ),
                          )),
                    ],
                  ),
                );
              },
            ),
            SizedBox(height: metrics.panelGap),
          ],
        ),
      ),
    );
  }
}
