part of 'standard_player.dart';

class _ExpandedNowPlaying extends StatelessWidget {
  const _ExpandedNowPlaying({
    super.key,
    required this.metrics,
  });

  final _NowPlayingLayoutMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final isInSlidingPanel = _isInSlidingPanel(context);
    final pc = Get.find<PlayerController>();
    final theme = Theme.of(context);
    final doudou = context.doudouColors;
    final textColor = doudou.textPrimary;
    final mutedColor = doudou.textSecondary;
    final surfaceColor = doudou.surfaceElevated;

    return Stack(
      children: [
        BackgroundImage(
          key: Key("${pc.currentSong.value?.id}_background"),
          cacheHeight: 400,
        ),
        Positioned.fill(
          child: Container(color: Colors.transparent),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.6),
                  Colors.black.withValues(alpha: 0.85),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(metrics.isDense ? 12 : 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: isInSlidingPanel
                          ? const Icon(Icons.keyboard_arrow_down_rounded)
                          : Obx(
                              () => Icon(
                                Get.find<ShellController>()
                                        .isNowPlayingFullscreen
                                        .value
                                    ? Icons.fullscreen_exit_rounded
                                    : Icons.fullscreen_rounded,
                              ),
                            ),
                      onPressed: () {
                        if (isInSlidingPanel) {
                          pc.playerPanelController.close();
                        } else {
                          Get.find<ShellController>().toggleNowPlayingFullscreen();
                        }
                      },
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.queue_music_rounded),
                      tooltip: context.l10n.queue,
                      onPressed: () => _openQueue(pc),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_horiz_rounded),
                      onPressed: () {
                        if (pc.currentSong.value == null) return;
                        showModalBottomSheet(
                          constraints: const BoxConstraints(maxWidth: 500),
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(10)),
                          ),
                          isScrollControlled: true,
                          context: context,
                          barrierColor: Colors.transparent.withAlpha(100),
                          builder: (ctx) => SongInfoBottomSheet(
                            pc.currentSong.value!,
                            calledFromPlayer: true,
                          ),
                        ).whenComplete(() => Get.delete<SongInfoController>());
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: metrics.useWideShortLayout
                    ? _WideShortNowPlayingStrip(
                        pc: pc,
                        textColor: textColor,
                        mutedColor: mutedColor,
                        metrics: metrics,
                      )
                    : Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: _ExpandedLeftColumn(
                              pc: pc,
                              textColor: textColor,
                              mutedColor: mutedColor,
                              surfaceColor: surfaceColor,
                              metrics: metrics,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Container(
                              margin: EdgeInsets.only(
                                right: metrics.sidePanelMargin,
                                bottom: metrics.sidePanelMargin,
                              ),
                              child: _buildRightPanelCard(
                                  borderColor: doudou.borderSubtle,
                                theme: theme,
                                surfaceColor: surfaceColor,
                                pc: pc,
                                textColor: textColor,
                                mutedColor: mutedColor,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRightPanelCard({
    required ThemeData theme,
    required Color surfaceColor,
    required PlayerController pc,
    required Color textColor,
    required Color mutedColor,
    required Color borderColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: _RightPanel(pc: pc, textColor: textColor, mutedColor: mutedColor),
    );
  }
}
