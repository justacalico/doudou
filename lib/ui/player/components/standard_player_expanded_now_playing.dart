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
    final textColor = theme.brightness == Brightness.dark
        ? Colors.white
        : (Colors.grey[900] ?? const Color(0xFF212121));
    final mutedColor = theme.brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.6)
        : (Colors.grey[600] ?? const Color(0xFF757575));
    final surfaceColor = theme.brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

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
                    : metrics.useStackedLayout
                        ? LayoutBuilder(
                            builder: (context, constraints) {
                              final availableHeight = constraints.maxHeight;
                              const minRightPanelHeight = 120.0;
                              const maxRightPanelHeight = 360.0;
                              final reservedForLeft =
                                  metrics.isDense ? 260.0 : 300.0;
                              final maxRightByReserve = availableHeight -
                                  reservedForLeft -
                                  metrics.panelGap;
                              final cappedMaxRight = maxRightByReserve.clamp(
                                minRightPanelHeight,
                                maxRightPanelHeight,
                              );
                              final targetRight =
                                  (availableHeight * 0.40).clamp(
                                minRightPanelHeight,
                                maxRightPanelHeight,
                              );
                              final rightPanelHeight =
                                  targetRight < cappedMaxRight
                                      ? targetRight
                                      : cappedMaxRight;
                              return Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: metrics.sidePanelMargin,
                                  vertical: metrics.verticalPadding,
                                ),
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: _ExpandedLeftColumn(
                                        pc: pc,
                                        textColor: textColor,
                                        mutedColor: mutedColor,
                                        surfaceColor: surfaceColor,
                                        metrics: metrics,
                                      ),
                                    ),
                                    SizedBox(height: metrics.panelGap),
                                    SizedBox(
                                      height: rightPanelHeight,
                                      child: _buildRightPanelCard(
                                        theme: theme,
                                        surfaceColor: surfaceColor,
                                        pc: pc,
                                        textColor: textColor,
                                        mutedColor: mutedColor,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
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
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: _RightPanel(pc: pc, textColor: textColor, mutedColor: mutedColor),
    );
  }
}
