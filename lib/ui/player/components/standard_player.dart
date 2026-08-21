import '/utils/app_l10n.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../shell_controller.dart';
import '../../widgets/image_widget.dart';
import '../../widgets/loader.dart';
import '../../widgets/songinfo_bottom_sheet.dart';
import '../player_controller.dart';
import 'background_image.dart';
import 'lyrics_widget.dart';
import 'player_mobile_bottom_bar.dart';

enum _NowPlayingMode {
  compact,
  expandedStacked,
  expandedSplit,
  expandedWideShort,
}

_NowPlayingMode _resolveNowPlayingMode(BoxConstraints constraints) {
  final width = constraints.maxWidth;
  final height = constraints.maxHeight;
  final aspect = width / (height <= 0 ? 1 : height);

  if (width >= 1000 && height < 470 && aspect > 2.0) {
    return _NowPlayingMode.expandedWideShort;
  }

  // Medium-width and short-height windows look closer to mobile and clip in
  // stacked desktop. Prefer compact mode in this in-between zone.
  if (width < 980 || (height < 720 && aspect < 1.95)) {
    return _NowPlayingMode.compact;
  }

  if (aspect < 1.55 || height < 760) {
    return _NowPlayingMode.expandedStacked;
  }

  return _NowPlayingMode.expandedSplit;
}

String _formatDuration(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  final h = d.inHours;
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

class _NowPlayingLayoutMetrics {
  const _NowPlayingLayoutMetrics({
    required this.mode,
    required this.isDense,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.panelGap,
    required this.artSize,
    required this.sidePanelMargin,
    required this.controlGapSmall,
    required this.controlGapLarge,
    required this.playButtonSize,
  });

  final _NowPlayingMode mode;
  final bool isDense;
  final double horizontalPadding;
  final double verticalPadding;
  final double panelGap;
  final double artSize;
  final double sidePanelMargin;
  final double controlGapSmall;
  final double controlGapLarge;
  final double playButtonSize;
  bool get useStackedLayout => mode == _NowPlayingMode.expandedStacked;
  bool get useWideShortLayout => mode == _NowPlayingMode.expandedWideShort;

  factory _NowPlayingLayoutMetrics.from(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    final mode = _resolveNowPlayingMode(constraints);
    final isDense = width < 1160 || height < 730;
    final useStackedLayout = mode == _NowPlayingMode.expandedStacked;

    final horizontalPadding = isDense ? 18.0 : 32.0;
    final verticalPadding = isDense ? 10.0 : 16.0;
    final panelGap = isDense ? 12.0 : 20.0;
    final sidePanelMargin = isDense ? 14.0 : 24.0;

    final artFromWidth = width * (useStackedLayout ? 0.32 : 0.25);
    final artFromHeight = height * (useStackedLayout ? 0.24 : 0.40);
    final artSize = artFromWidth < artFromHeight ? artFromWidth : artFromHeight;

    return _NowPlayingLayoutMetrics(
      mode: mode,
      isDense: isDense,
      horizontalPadding: horizontalPadding,
      verticalPadding: verticalPadding,
      panelGap: panelGap,
      artSize: artSize.clamp(180.0, 360.0),
      sidePanelMargin: sidePanelMargin,
      controlGapSmall: isDense ? 12.0 : 16.0,
      controlGapLarge: isDense ? 16.0 : 24.0,
      playButtonSize: isDense ? 56.0 : 64.0,
    );
  }
}

class StandardPlayer extends StatefulWidget {
  const StandardPlayer({super.key});

  @override
  State<StandardPlayer> createState() => _StandardPlayerState();
}

class _StandardPlayerState extends State<StandardPlayer> {
  bool _showMobileVolumePanel = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mode = _resolveNowPlayingMode(constraints);
        if (mode != _NowPlayingMode.compact) {
          final metrics = _NowPlayingLayoutMetrics.from(constraints);
          return _ExpandedNowPlaying(
            key: const Key('expanded'),
            metrics: metrics,
          );
        }
        final pc = Get.find<PlayerController>();
        return Stack(
          children: [
            _CompactNowPlaying(
              key: const Key('compact'),
              volumeAction: IconButton(
                onPressed: () {
                  setState(
                      () => _showMobileVolumePanel = !_showMobileVolumePanel);
                },
                icon: Obx(() {
                  final v = pc.volume.value;
                  return Icon(
                    v == 0
                        ? Icons.volume_off_rounded
                        : v < 50
                            ? Icons.volume_down_rounded
                            : Icons.volume_up_rounded,
                    size: 26,
                  );
                }),
                color: _showMobileVolumePanel
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white,
                tooltip: "Volume",
              ),
            ),
            if (_showMobileVolumePanel)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => setState(() => _showMobileVolumePanel = false),
                  child: const SizedBox.expand(),
                ),
              ),
            if (_showMobileVolumePanel)
              Positioned(
                left: 42,
                right: 42,
                bottom: 78,
                child: _MobileVolumeOverlay(
                  onTapOutside: () =>
                      setState(() => _showMobileVolumePanel = false),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CompactNowPlaying extends StatelessWidget {
  const _CompactNowPlaying({
    super.key,
    this.volumeAction,
  });

  final Widget? volumeAction;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final pc = Get.find<PlayerController>();
    const white = CupertinoColors.white;
    // Use the real screen width, not the MediaQuery-overridden one (the side
    // panel overrides MediaQuery to its own width, which would break the check)
    final realScreenWidth =
        View.of(context).physicalSize.width / View.of(context).devicePixelRatio;
    final isWideScreen = realScreenWidth > 800;
    final isLandscapeDense =
        !isWideScreen && size.width > size.height && size.height < 560;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          Obx(() {
            if (pc.currentSong.value == null) return const SizedBox.shrink();
            return Positioned.fill(
              child: BackgroundImage(
                key: Key("${pc.currentSong.value?.id}_background"),
                cacheHeight: 200,
              ),
            );
          }),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.75),
                    Colors.black.withValues(alpha: 0.92),
                  ],
                ),
              ),
            ),
          ),
          isLandscapeDense
              ? SafeArea(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Column(
                      children: [
                        _buildTopActions(pc, white, dense: true, isWideScreen: isWideScreen),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Row(
                                  children: [
                                    Obx(() {
                                      final song = pc.currentSong.value;
                                      if (song == null) {
                                        return const SizedBox(
                                            width: 76, height: 76);
                                      }
                                      return GestureDetector(
                                        onTap: () => pc.showLyrics(),
                                        onLongPress: () =>
                                            _showSongMore(context, pc),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          child: ImageWidget(
                                            size: 76,
                                            song: song,
                                            isPlayerArtImage: true,
                                          ),
                                        ),
                                      );
                                    }),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Obx(() {
                                        final song = pc.currentSong.value;
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              song?.title ?? '—',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.w700,
                                                color: CupertinoColors.white,
                                                letterSpacing: -0.4,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              song?.artist ?? '—',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color:
                                                    CupertinoColors.systemGrey2,
                                              ),
                                            ),
                                          ],
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14),
                                child: _CompactProgressBar(pc: pc, dense: true),
                              ),
                              _CompactControls(pc: pc, dense: true),
                            ],
                          ),
                        ),
                        PlayerMobileBottomBar(
                          volumeAction: volumeAction,
                          dense: true,
                          iconColor: white,
                        ),
                      ],
                    ),
                  ),
                )
              : SafeArea(
                  child: Column(
                    children: [
                      _buildTopActions(pc, white, isWideScreen: isWideScreen),
                      Expanded(
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            Expanded(
                              flex: 3,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final availableHeight =
                                      constraints.maxHeight * 0.9;
                                  final artSize =
                                      (availableHeight < size.width * 0.75
                                              ? availableHeight
                                              : size.width * 0.75)
                                          .clamp(200.0, 350.0);
                                  return Obx(() {
                                    if (pc.currentSong.value == null) {
                                      return const SizedBox.shrink();
                                    }
                                    return Center(
                                      child: GestureDetector(
                                        onTap: () => pc.showLyrics(),
                                        onLongPress: () =>
                                            _showSongMore(context, pc),
                                        child: Container(
                                          width: artSize,
                                          height: artSize,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(24),
                                            border: Border.all(
                                              color: white,
                                              width: 3,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withValues(alpha: 0.32),
                                                blurRadius: 24,
                                                offset: const Offset(0, 12),
                                              ),
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(21),
                                            child: ImageWidget(
                                              size: artSize,
                                              song: pc.currentSong.value!,
                                              isPlayerArtImage: true,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  });
                                },
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 30),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Obx(() {
                                      final song = pc.currentSong.value;
                                      return Text(
                                        song?.title ?? '—',
                                        style: const TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w700,
                                          color: CupertinoColors.white,
                                          letterSpacing: -0.5,
                                          height: 1.0,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      );
                                    }),
                                    const SizedBox(height: 4),
                                    Obx(() {
                                      final song = pc.currentSong.value;
                                      return Text(
                                        song?.artist ?? '—',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: CupertinoColors.systemGrey,
                                          height: 1.0,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: _CompactProgressBar(pc: pc),
                      ),
                      const SizedBox(height: 24),
                      _CompactControls(pc: pc),
                      PlayerMobileBottomBar(
                        volumeAction: volumeAction,
                        iconColor: white,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildTopActions(PlayerController pc, Color white,
      {bool dense = false, required bool isWideScreen}) {
    final buttonSize = dense ? 34.0 : 40.0;
    final iconSize = dense ? 20.0 : 22.0;
    final borderRadius = dense ? 10.0 : 12.0;
    final horizontalPadding = dense ? 12.0 : 20.0;
    final verticalPadding = dense ? 4.0 : 10.0;
    final trailingGap = dense ? 6.0 : 8.0;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              if (isWideScreen) {
                Get.find<ShellController>().toggleNowPlayingFullscreen();
              } else {
                pc.playerPanelController.close();
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Container(
                width: buttonSize,
                height: buttonSize,
                decoration: BoxDecoration(
                  color: white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(
                    color: white.withValues(alpha: 0.18),
                    width: 0.5,
                  ),
                ),
                child: isWideScreen
                    ? Obx(
                        () => Icon(
                          Get.find<ShellController>()
                                  .isNowPlayingFullscreen
                                  .value
                              ? Icons.fullscreen_exit_rounded
                              : Icons.fullscreen_rounded,
                          color: white,
                          size: iconSize,
                        ),
                      )
                    : Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: white,
                        size: iconSize,
                      ),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!GetPlatform.isDesktop)
                GestureDetector(
                  onTap: () => pc.queuePanelController.open(),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(borderRadius),
                    child: Container(
                      width: buttonSize,
                      height: buttonSize,
                      margin: EdgeInsets.only(right: trailingGap),
                      decoration: BoxDecoration(
                        color: white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(borderRadius),
                        border: Border.all(
                          color: white.withValues(alpha: 0.18),
                          width: 0.5,
                        ),
                      ),
                      child: Icon(
                        Icons.queue_music_rounded,
                        color: white,
                        size: iconSize,
                      ),
                    ),
                  ),
                ),
              Obx(() => GestureDetector(
                    onTap: pc.toggleFavourite,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(borderRadius),
                      child: Container(
                        width: buttonSize,
                        height: buttonSize,
                        decoration: BoxDecoration(
                          color: white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(borderRadius),
                          border: Border.all(
                            color: white.withValues(alpha: 0.18),
                            width: 0.5,
                          ),
                        ),
                        child: Icon(
                          pc.isCurrentSongFav.isTrue
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: pc.isCurrentSongFav.isTrue
                              ? const Color(0xFFEC4899)
                              : white,
                          size: iconSize,
                        ),
                      ),
                    ),
                  )),
            ],
          ),
        ],
      ),
    );
  }

  void _showSongMore(BuildContext context, PlayerController pc) {
    if (pc.currentSong.value == null) return;
    showModalBottomSheet(
      constraints: const BoxConstraints(maxWidth: 500),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      isScrollControlled: true,
      context: context,
      barrierColor: Colors.transparent.withAlpha(100),
      builder: (ctx) => SongInfoBottomSheet(
        pc.currentSong.value!,
        calledFromPlayer: true,
      ),
    ).whenComplete(() => Get.delete<SongInfoController>());
  }
}

class _CompactProgressBar extends StatelessWidget {
  const _CompactProgressBar({
    required this.pc,
    this.dense = false,
  });

  final PlayerController pc;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final status = pc.progressBarStatus.value;
      final total = status.total;
      final current = status.current;
      final progress = total.inMilliseconds > 0
          ? (current.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
          : 0.0;

      void seekTo(Offset localPos, RenderBox box) {
        final w = box.size.width;
        if (w > 0 && total.inMilliseconds > 0) {
          final frac = (localPos.dx / w).clamp(0.0, 1.0);
          pc.seek(
              Duration(milliseconds: (frac * total.inMilliseconds).round()));
        }
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => seekTo(
                d.localPosition, context.findRenderObject() as RenderBox),
            onHorizontalDragUpdate: (d) => seekTo(
                d.localPosition, context.findRenderObject() as RenderBox),
            child: SizedBox(
              height: dense ? 30 : 44,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: dense ? 6 : 8,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: CupertinoColors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            FractionallySizedBox(
                              widthFactor: progress,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: CupertinoColors.white
                                      .withValues(alpha: 0.86),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(current),
                  style: TextStyle(
                    color: CupertinoColors.white.withValues(alpha: 0.6),
                    fontSize: dense ? 11 : 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _formatDuration(total),
                  style: TextStyle(
                    color: CupertinoColors.white.withValues(alpha: 0.6),
                    fontSize: dense ? 11 : 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

class FractionallySizedBox extends StatelessWidget {
  const FractionallySizedBox({
    super.key,
    required this.widthFactor,
    required this.child,
  });

  final double widthFactor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth * widthFactor.clamp(0.0, 1.0),
          child: child,
        );
      },
    );
  }
}

class _MobileVolumeOverlay extends StatelessWidget {
  const _MobileVolumeOverlay({required this.onTapOutside});

  final VoidCallback onTapOutside;

  @override
  Widget build(BuildContext context) {
    final pc = Get.find<PlayerController>();
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.18)
                  : Colors.black.withValues(alpha: 0.08),
              width: 0.5,
            ),
          ),
          child: Obx(() {
            final v = pc.volume.value;
            return Row(
              children: [
                Icon(
                  v == 0
                      ? Icons.volume_off_rounded
                      : v < 50
                          ? Icons.volume_down_rounded
                          : Icons.volume_up_rounded,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 12),
                      activeTrackColor: theme.colorScheme.onSurface,
                      inactiveTrackColor:
                          theme.colorScheme.onSurface.withValues(alpha: 0.25),
                      thumbColor: theme.colorScheme.onSurface,
                    ),
                    child: Slider(
                      value: v / 100,
                      onChanged: (value) {
                        pc.setVolume((value * 100).round().clamp(0, 100));
                      },
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _CompactControls extends StatelessWidget {
  const _CompactControls({
    required this.pc,
    this.dense = false,
  });

  final PlayerController pc;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    const white = CupertinoColors.white;
    final horizontalPadding = dense ? 18.0 : 40.0;
    final sideIconSize = dense ? 20.0 : 24.0;
    final skipIconSize = dense ? 30.0 : 36.0;
    final playButtonSize = dense ? 56.0 : 72.0;
    final playIconSize = dense ? 30.0 : 36.0;
    final gapSmall = dense ? 6.0 : 8.0;
    final gapMedium = dense ? 10.0 : 16.0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Obx(() => GestureDetector(
                onTap: pc.toggleShuffleMode,
                child: Icon(
                  Icons.shuffle_rounded,
                  color: pc.isShuffleModeEnabled.isTrue
                      ? white
                      : white.withValues(alpha: 0.6),
                  size: sideIconSize,
                ),
              )),
          SizedBox(width: gapSmall),
          GestureDetector(
            onTap: pc.prev,
            child: Icon(
              Icons.skip_previous_rounded,
              color: white,
              size: skipIconSize,
            ),
          ),
          SizedBox(width: gapMedium),
          Obx(() {
            final playing = pc.buttonState.value == PlayButtonState.playing;
            return GestureDetector(
              onTap: () => pc.playPause(),
              child: Container(
                width: playButtonSize,
                height: playButtonSize,
                decoration: BoxDecoration(
                  color: white.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: white.withValues(alpha: 0.24),
                    width: 0.6,
                  ),
                ),
                child: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: white,
                  size: playIconSize,
                ),
              ),
            );
          }),
          SizedBox(width: gapMedium),
          GestureDetector(
            onTap: pc.next,
            child: Icon(
              Icons.skip_next_rounded,
              color: white,
              size: skipIconSize,
            ),
          ),
          SizedBox(width: gapSmall),
          Obx(() => GestureDetector(
                onTap: pc.toggleLoopMode,
                child: Icon(
                  pc.isLoopModeEnabled.isTrue
                      ? Icons.repeat_one_rounded
                      : Icons.repeat_rounded,
                  color: pc.isLoopModeEnabled.isTrue
                      ? white
                      : white.withValues(alpha: 0.6),
                  size: sideIconSize,
                ),
              )),
        ],
      ),
    );
  }
}

class _ExpandedNowPlaying extends StatelessWidget {
  const _ExpandedNowPlaying({
    super.key,
    required this.metrics,
  });

  final _NowPlayingLayoutMetrics metrics;

  @override
  Widget build(BuildContext context) {
    // Real screen width — MediaQuery may be overridden by the side panel
    final realScreenWidth =
        View.of(context).physicalSize.width / View.of(context).devicePixelRatio;
    final isWideScreen = realScreenWidth > 800;
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
                      icon: isWideScreen
                          ? Obx(
                              () => Icon(
                                Get.find<ShellController>()
                                        .isNowPlayingFullscreen
                                        .value
                                    ? Icons.fullscreen_exit_rounded
                                    : Icons.fullscreen_rounded,
                              ),
                            )
                          : const Icon(Icons.keyboard_arrow_down_rounded),
                      onPressed: () {
                        if (isWideScreen) {
                          Get.find<ShellController>().toggleNowPlayingFullscreen();
                        } else {
                          pc.playerPanelController.close();
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

class _ExpandedLeftColumn extends StatefulWidget {
  const _ExpandedLeftColumn({
    required this.pc,
    required this.textColor,
    required this.mutedColor,
    required this.surfaceColor,
    required this.metrics,
  });

  final PlayerController pc;
  final Color textColor;
  final Color mutedColor;
  final Color surfaceColor;
  final _NowPlayingLayoutMetrics metrics;

  @override
  State<_ExpandedLeftColumn> createState() => _ExpandedLeftColumnState();
}

class _WideShortNowPlayingStrip extends StatelessWidget {
  const _WideShortNowPlayingStrip({
    required this.pc,
    required this.textColor,
    required this.mutedColor,
    required this.metrics,
  });

  final PlayerController pc;
  final Color textColor;
  final Color mutedColor;
  final _NowPlayingLayoutMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ultraCompact = constraints.maxHeight < 170;
        final artByHeight =
            constraints.maxHeight * (ultraCompact ? 0.72 : 0.80);
        final artByWidth = constraints.maxWidth * 0.18;
        final artSize = (artByHeight < artByWidth ? artByHeight : artByWidth)
            .clamp(96.0, 180.0);

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: metrics.horizontalPadding,
            vertical: metrics.verticalPadding,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Obx(() {
                if (pc.currentSong.value == null) {
                  return SizedBox(width: artSize, height: artSize);
                }
                return Container(
                  width: artSize,
                  height: artSize,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ImageWidget(
                    size: artSize,
                    song: pc.currentSong.value!,
                    isPlayerArtImage: true,
                  ),
                );
              }),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Obx(() {
                      final song = pc.currentSong.value;
                      return Text(
                        song?.title ?? '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w700,
                          fontSize: ultraCompact ? 18 : 20,
                        ),
                      );
                    }),
                    if (!ultraCompact) ...[
                      const SizedBox(height: 3),
                      Obx(() {
                        final song = pc.currentSong.value;
                        return Text(
                          song?.artist ?? '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: mutedColor,
                            fontSize: 13,
                          ),
                        );
                      }),
                    ],
                    SizedBox(height: ultraCompact ? 8 : 10),
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
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 5),
                              overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 10),
                              activeTrackColor: textColor,
                              inactiveTrackColor:
                                  textColor.withValues(alpha: 0.25),
                              thumbColor: textColor,
                            ),
                            child: Slider(
                              value: progress,
                              onChanged: (v) {
                                pc.seek(Duration(
                                    milliseconds:
                                        (v * total.inMilliseconds).round()));
                              },
                            ),
                          ),
                          if (!ultraCompact)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(current),
                                    style: TextStyle(
                                        fontSize: 11, color: mutedColor),
                                  ),
                                  Text(
                                    _formatDuration(total),
                                    style: TextStyle(
                                        fontSize: 11, color: mutedColor),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    }),
                    SizedBox(height: ultraCompact ? 6 : 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
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
                          IconButton(
                            onPressed: pc.prev,
                            icon: Icon(Icons.skip_previous_rounded,
                                size: 28, color: textColor),
                          ),
                          Obx(() {
                            final playing =
                                pc.buttonState.value == PlayButtonState.playing;
                            return GestureDetector(
                              onTap: () => pc.playPause(),
                              child: Container(
                                width: ultraCompact ? 48 : 52,
                                height: ultraCompact ? 48 : 52,
                                decoration: BoxDecoration(
                                  color: textColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color:
                                      Theme.of(context).scaffoldBackgroundColor,
                                  size: 30,
                                ),
                              ),
                            );
                          }),
                          IconButton(
                            onPressed: pc.next,
                            icon: Icon(Icons.skip_next_rounded,
                                size: 28, color: textColor),
                          ),
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
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ExpandedLeftColumnState extends State<_ExpandedLeftColumn> {
  bool _showVolumePanel = false;

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

class _RightPanel extends StatelessWidget {
  const _RightPanel({
    required this.pc,
    required this.textColor,
    required this.mutedColor,
  });

  final PlayerController pc;
  final Color textColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TabBar(
              labelColor: textColor,
              unselectedLabelColor: mutedColor,
              indicatorColor: theme.colorScheme.primary,
              tabs: [
                Tab(text: context.l10n.upNext),
                Tab(text: context.l10n.lyrics),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  context.l10n.playingFrom,
                  style: TextStyle(fontSize: 12, color: mutedColor),
                ),
                Expanded(
                  child: Obx(() => Text(
                        pc.playinfrom.value.nameString,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      )),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              children: [
                _UpNextList(
                    pc: pc, textColor: textColor, mutedColor: mutedColor),
                Obx(() => pc.isLyricsLoading.isTrue
                    ? const Center(child: LoadingIndicator())
                    : _LyricsPanel(pc: pc)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpNextList extends StatelessWidget {
  const _UpNextList({
    required this.pc,
    required this.textColor,
    required this.mutedColor,
  });

  final PlayerController pc;
  final Color textColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final queue = pc.currentQueue;
      final currentIndex = pc.currentSongIndex.value;
      if (queue.isEmpty) {
        return Center(
          child: Text(
            context.l10n.songs,
            style: TextStyle(color: mutedColor, fontSize: 14),
          ),
        );
      }
      final current = currentIndex >= 0 && currentIndex < queue.length
          ? queue[currentIndex]
          : null;
      final queueIndices = List.generate(queue.length, (i) => i);

      return LayoutBuilder(
        builder: (context, constraints) {
          final showPinnedCurrent =
              current != null && constraints.maxHeight >= 180;
          return Column(
            children: [
              if (showPinnedCurrent)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        ImageWidget(size: 44, song: current),
                        const SizedBox(width: 10),
                        Icon(Icons.graphic_eq_rounded,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                current.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                current.artist ?? '—',
                                style:
                                    TextStyle(fontSize: 12, color: mutedColor),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: queueIndices.length,
                  itemBuilder: (context, index) {
                    final i = queueIndices[index];
                    final item = queue[i];
                    final isCurrent = i == currentIndex;
                    final primary = Theme.of(context).colorScheme.primary;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? primary.withValues(alpha: 0.22)
                                : Colors.transparent,
                            border: Border.all(
                              color: isCurrent
                                  ? primary.withValues(alpha: 0.65)
                                  : Colors.transparent,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              if (isCurrent)
                                Container(
                                  width: 4,
                                  height: 60,
                                  color: primary,
                                ),
                              Expanded(
                                child: ListTile(
                                  dense: true,
                                  leading: SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: ImageWidget(size: 40, song: item),
                                  ),
                                  title: Text(
                                    item.title,
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: isCurrent
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    item.artist ?? '—',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isCurrent
                                          ? mutedColor.withValues(alpha: 0.95)
                                          : mutedColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () => pc.seekByIndex(i),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    });
  }
}

class _LyricsPanel extends StatelessWidget {
  const _LyricsPanel({required this.pc});

  final PlayerController pc;

  @override
  Widget build(BuildContext context) {
    return const LyricsWidget(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    );
  }
}
