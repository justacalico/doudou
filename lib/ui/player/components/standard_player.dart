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
import '../../widgets/sliding_up_panel.dart';

part 'standard_player_lyrics_panel.dart';

part 'standard_player_up_next_list.dart';

part 'standard_player_right_panel.dart';

part 'standard_player_expanded_now_playing.dart';

part 'standard_player_compact_controls.dart';

part 'standard_player_mobile_volume_overlay.dart';

part 'standard_player_compact_progress_bar.dart';

part 'standard_player_compact_now_playing.dart';

part 'standard_player_expandedleftcolumnstatebase.dart';
part 'standard_player_expandedleftcolumnstatebuild.dart';

part 'standard_player_standardplayerstatebase.dart';
part 'standard_player_standardplayerstatebuild.dart';

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

bool _isInSlidingPanel(BuildContext context) {
  return context.findAncestorWidgetOfExactType<SlidingUpPanel>() != null;
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

class _StandardPlayerState extends State<StandardPlayer>
    with _StandardPlayerStateBase, _StandardPlayerStateBuildMixin {
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

class _ExpandedLeftColumnState extends State<_ExpandedLeftColumn>
    with _ExpandedLeftColumnStateBase, _ExpandedLeftColumnStateBuildMixin {
}


