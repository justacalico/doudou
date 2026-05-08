import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:doudou/ui/constants/doudou_design.dart';
import 'package:doudou/ui/design/doudou_colors.dart';
import 'package:doudou/ui/shell_controller.dart';
import 'package:ionicons/ionicons.dart';
import 'package:widget_marquee/widget_marquee.dart';

import '/ui/widgets/lyrics_dialog.dart';
import '/ui/widgets/song_info_dialog.dart';
import '/ui/player/player_controller.dart';
import '../../widgets/add_to_playlist.dart';
import '../../widgets/sleep_timer_bottom_sheet.dart';
import '../../widgets/song_download_btn.dart';
import '../../widgets/image_widget.dart';
import '../../widgets/mini_player_progress_bar.dart';
import 'animated_play_button.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final playerController = Get.find<PlayerController>();
    final size = MediaQuery.of(context).size;
    return Obx(() {
      final bottomNavEnabled = Get.find<ShellController>().useBottomNav.value;
      final isMobilePill = bottomNavEnabled;
      final content = isMobilePill
          ? _MobileMiniPlayer(controller: playerController)
          : _DesktopMiniPlayer(controller: playerController, size: size);
      return Visibility(
        visible: playerController.isPlayerpanelTopVisible.value &&
            playerController.currentSong.value != null,
        child: SizedBox(
          height: playerController.playerPanelMinHeight.value,
          width: size.width,
          child: Obx(() => Opacity(
                opacity: playerController.playerPaneOpacity.value,
                child: content,
              )),
        ),
      );
    });
  }
}

class _MobileMiniPlayer extends StatelessWidget {
  const _MobileMiniPlayer({required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final c = context.doudouColors;
    final song = controller.currentSong.value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(kDoudouRadiusCard),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: c.surfaceOverlay,
                borderRadius: BorderRadius.circular(kDoudouRadiusCard),
                border: Border.all(color: c.borderSubtle),
                boxShadow: const [],
              ),
              child: Stack(
                children: [
                  Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                      child: Row(
                        children: [
                          if (song != null)
                            GestureDetector(
                              onTap: controller.playerPanelController.open,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: ImageWidget(
                                  size: 48,
                                  song: song,
                                ),
                              ),
                            )
                          else
                            const SizedBox(height: 48, width: 48),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onHorizontalDragEnd: (details) {
                                final v = details.primaryVelocity ?? 0;
                                if (v < 0) {
                                  controller.next();
                                } else if (v > 0) {
                                  controller.prev();
                                }
                              },
                              onTap: controller.playerPanelController.open,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    song?.title ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    song?.artist ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.bodySmall?.copyWith(
                                      fontSize: 11,
                                      color: textTheme.bodySmall?.color
                                          ?.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Obx(() {
                                final state = controller.buttonState.value;
                                final isPlaying =
                                    state == PlayButtonState.playing;
                                final isLoading =
                                    state == PlayButtonState.loading;

                                return IconButton(
                                  iconSize: 28,
                                  onPressed: () {
                                    if (isLoading) return;
                                    isPlaying
                                        ? controller.pause()
                                        : controller.play();
                                  },
                                  icon: isLoading
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              c.accentPrimary,
                                            ),
                                          ),
                                        )
                                      : Icon(
                                          isPlaying
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded,
                                          color: c.textPrimary,
                                        ),
                                );
                              }),
                              IconButton(
                                iconSize: 28,
                                onPressed: controller.next,
                                icon: Icon(Icons.skip_next_rounded,
                                    color: c.textPrimary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: SizedBox(
                        height: 2,
                        child: GetX<PlayerController>(
                          init: controller,
                          builder: (pc) => MiniPlayerProgressBar(
                            progressBarStatus: pc.progressBarStatus.value,
                            progressBarColor: context.doudouColors.accentPrimary,
                          ),
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
  }
}

class _DesktopMiniPlayer extends StatelessWidget {
  const _DesktopMiniPlayer({
    required this.controller,
    required this.size,
  });

  final PlayerController controller;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final c = context.doudouColors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final shortDesktop = constraints.maxHeight < 90;
        final compactDesktop = shortDesktop || size.width < 1100;
        final controlClusterWidth = compactDesktop ? 260.0 : 450.0;
        final primaryControlSize = compactDesktop ? 34.0 : 35.0;
        final playButtonSize = compactDesktop ? 50.0 : 58.0;

        if (shortDesktop) {
          return Container(
            height: 96,
            decoration: BoxDecoration(
              color: c.raisedBackground,
              border: Border(
                top: BorderSide(color: c.borderSubtle),
              ),
            ),
            child: Stack(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Row(
                    children: [
                      if (controller.currentSong.value != null)
                        GestureDetector(
                          onTap: controller.playerPanelController.open,
                          child: ImageWidget(
                              size: 42, song: controller.currentSong.value!),
                        )
                      else
                        const SizedBox(width: 42, height: 42),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: controller.playerPanelController.open,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                controller.currentSong.value?.title ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.titleSmall,
                              ),
                              Text(
                                controller.currentSong.value?.artist ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        iconSize: 18,
                        onPressed: controller.prev,
                        icon: Icon(Icons.skip_previous, color: c.textPrimary),
                      ),
                      const SizedBox(
                        width: 38,
                        height: 38,
                        child: Center(
                          child: IconTheme(
                            data: IconThemeData(color: Colors.white),
                            child: AnimatedPlayButton(iconSize: 30),
                          ),
                        ),
                      ),
                      IconButton(
                        iconSize: 18,
                        onPressed: controller.next,
                        icon: Icon(Icons.skip_next, color: c.textPrimary),
                      ),
                      IconButton(
                        iconSize: 18,
                        onPressed: () {
                          controller.homeScaffoldkey.currentState
                              ?.openEndDrawer();
                        },
                        icon: Icon(Icons.queue_music, color: c.textPrimary),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SizedBox(
                    height: 2,
                    child: GetX<PlayerController>(
                      init: controller,
                      builder: (pc) => MiniPlayerProgressBar(
                        progressBarStatus: pc.progressBarStatus.value,
                        progressBarColor: context.doudouColors.accentPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          height: 96,
          decoration: BoxDecoration(
            color: c.surfaceBase,
            border: Border(
              top: BorderSide(
                color: c.borderSubtle,
                width: 0.5,
              ),
            ),
          ),
          child: Center(
            child: Column(
              children: [
                GetX<PlayerController>(builder: (pc) {
                  return Padding(
                    padding: EdgeInsets.only(
                      left: 16,
                      top: compactDesktop ? 8 : 12,
                      right: 16,
                      bottom: 0,
                    ),
                    child: ProgressBar(
                      timeLabelLocation: compactDesktop
                          ? TimeLabelLocation.none
                          : TimeLabelLocation.sides,
                      thumbRadius: compactDesktop ? 5 : 6,
                      barHeight: 2.5,
                      thumbGlowRadius: 0,
                      baseBarColor: c.borderStrong.withValues(alpha: 0.5),
                      bufferedBarColor: c.accentMuted.withValues(alpha: 0.25),
                      progressBarColor: c.accentPrimary,
                      thumbColor: c.accentPrimary,
                      timeLabelTextStyle: textTheme.labelSmall?.copyWith(
                        color: c.textTertiary,
                        fontSize: 11,
                      ),
                      progress: pc.progressBarStatus.value.current,
                      total: pc.progressBarStatus.value.total,
                      buffered: pc.progressBarStatus.value.buffered,
                      onSeek: pc.seek,
                    ),
                  );
                }),
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: compactDesktop ? 8 : 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          controller.currentSong.value != null
                              ? GestureDetector(
                                  onTap: controller.playerPanelController.open,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: ImageWidget(
                                      size: 48,
                                      song: controller.currentSong.value!,
                                    ),
                                  ),
                                )
                              : const SizedBox(
                                  height: 48,
                                  width: 48,
                                ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onHorizontalDragEnd: (details) {
                            final v = details.primaryVelocity ?? 0;
                            if (v < 0) {
                              controller.next();
                            } else if (v > 0) {
                              controller.prev();
                            }
                          },
                          onTap: () {
                            controller.playerPanelController.open();
                          },
                          child: ColoredBox(
                            color: Colors.transparent,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 18,
                                  child: Text(
                                    controller.currentSong.value?.title ?? '',
                                    maxLines: 1,
                                    style: textTheme.titleMedium?.copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                SizedBox(
                                  height: 16,
                                  child: Marquee(
                                    id: "${controller.currentSong.value}_mini_desktop",
                                    delay: const Duration(milliseconds: 300),
                                    duration: const Duration(seconds: 5),
                                    child: Text(
                                      controller.currentSong.value?.artist ??
                                          '',
                                      maxLines: 1,
                                      style: textTheme.titleSmall?.copyWith(
                                        fontSize: 12,
                                        color: c.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: controlClusterWidth,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                    iconSize: 18,
                                    onPressed: controller.toggleFavourite,
                                    icon: Obx(() => Icon(
                                          controller.isCurrentSongFav.isFalse
                                              ? Icons.favorite_border
                                              : Icons.favorite,
                                          size: 18,
                                          color: controller.isCurrentSongFav.isTrue
                                              ? c.accentPrimary
                                              : c.textSecondary,
                                        ))),
                                if (!compactDesktop)
                                  IconButton(
                                      iconSize: 18,
                                      onPressed: controller.toggleShuffleMode,
                                      icon: Obx(() => Icon(
                                            Ionicons.shuffle,
                                            size: 18,
                                            color: controller
                                                    .isShuffleModeEnabled.value
                                                ? c.textPrimary
                                                : c.textDisabled,
                                          ))),
                              ],
                            ),
                            SizedBox(
                              width: 36,
                              child: InkWell(
                                onTap: (controller.currentQueue.isEmpty ||
                                        (controller.currentQueue.first.id ==
                                            controller.currentSong.value?.id))
                                    ? null
                                    : controller.prev,
                                child: Icon(
                                  Icons.skip_previous,
                                  color: c.textPrimary,
                                  size: primaryControlSize,
                                ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: c.surfaceOverlay.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: c.borderSubtle,
                                  width: 0.5,
                                ),
                              ),
                              width: playButtonSize,
                              height: playButtonSize,
                              child: Center(
                                child: IconTheme(
                                  data: IconThemeData(color: c.textPrimary),
                                  child: AnimatedPlayButton(
                                    iconSize: 32,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 36,
                              child: Obx(() {
                                final isLastSong = controller
                                        .currentQueue.isEmpty ||
                                    (!(controller.isShuffleModeEnabled.isTrue ||
                                            controller.isQueueLoopModeEnabled
                                                .isTrue) &&
                                        (controller.currentQueue.last.id ==
                                            controller.currentSong.value?.id));
                                return InkWell(
                                  onTap: isLastSong ? null : controller.next,
                                  child: Icon(
                                    Icons.skip_next,
                                    color: isLastSong
                                        ? c.textDisabled
                                        : c.textPrimary,
                                    size: primaryControlSize,
                                  ),
                                );
                              }),
                            ),
                            Row(
                              children: [
                                if (!compactDesktop)
                                  IconButton(
                                      iconSize: 18,
                                      onPressed: controller.toggleLoopMode,
                                      icon: Icon(
                                        Icons.all_inclusive,
                                        size: 18,
                                        color: controller.isLoopModeEnabled.value
                                            ? c.textPrimary
                                            : c.textDisabled,
                                      )),
                                IconButton(
                                    iconSize: 18,
                                    onPressed: () {
                                      controller.showLyrics();
                                      showDialog(
                                              builder: (context) =>
                                                  const LyricsDialog(),
                                              context: context)
                                          .whenComplete(() {
                                        controller.isDesktopLyricsDialogOpen =
                                            false;
                                        controller.showLyricsflag.value = false;
                                      });
                                      controller.isDesktopLyricsDialogOpen =
                                          true;
                                    },
                                    icon: Icon(
                                      Icons.lyrics_outlined,
                                      size: 18,
                                      color: c.textSecondary,
                                    )),
                              ],
                            ),
                            const SizedBox(width: 16),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: size.width < 1004 ? 0 : 30.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (!compactDesktop)
                                Container(
                                  padding: const EdgeInsets.only(
                                      right: 20, left: 10),
                                  height: 20,
                                  width: 220,
                                  child: Obx(() {
                                    final volume = controller.volume.value;
                                    return Row(
                                      children: [
                                        SizedBox(
                                          width: 18,
                                          child: InkWell(
                                            onTap: controller.mute,
                                            child: Icon(
                                              volume == 0
                                                  ? Icons.volume_off
                                                  : volume > 0 && volume < 50
                                                      ? Icons.volume_down
                                                      : Icons.volume_up,
                                              size: 18,
                                              color: c.textSecondary,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: SliderTheme(
                                            data: SliderTheme.of(context)
                                                .copyWith(
                                              trackHeight: 2,
                                              thumbShape:
                                                  const RoundSliderThumbShape(
                                                enabledThumbRadius: 5.0,
                                              ),
                                              overlayShape:
                                                  const RoundSliderOverlayShape(
                                                overlayRadius: 8.0,
                                              ),
                                            ),
                                            child: Slider(
                                              value:
                                                  controller.volume.value / 100,
                                              onChanged: (value) {
                                                controller.setVolume(
                                                    (value * 100).toInt());
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }),
                                ),
                              SizedBox(
                                height: compactDesktop ? 34 : 40,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        controller.homeScaffoldkey.currentState!
                                            .openEndDrawer();
                                      },
                                      icon: Icon(Icons.queue_music,
                                          size: 18,
                                          color: c.textSecondary),
                                    ),
                                    if (!compactDesktop)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(left: 8.0),
                                        child: IconButton(
                                          onPressed: () {
                                            showModalBottomSheet(
                                              constraints: const BoxConstraints(
                                                maxWidth: 500,
                                              ),
                                              shape:
                                                  const RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.vertical(
                                                  top: Radius.circular(12.0),
                                                ),
                                              ),
                                              isScrollControlled: true,
                                              context: Get.find<
                                                      ShellController>()
                                                  .overlayContextOrFallback!,
                                              barrierColor: Colors.transparent
                                                  .withAlpha(100),
                                              builder: (context) =>
                                                  const SleepTimerBottomSheet(),
                                            );
                                          },
                                          icon: Icon(
                                            controller.isSleepTimerActive.isTrue
                                                ? Icons.timer
                                                : Icons.timer_outlined,
                                            size: 18,
                                            color: c.textSecondary,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(width: 8),
                                    if (compactDesktop)
                                      Obx(() {
                                        final volume = controller.volume.value;
                                        return IconButton(
                                          onPressed: controller.mute,
                                          icon: Icon(
                                            volume == 0
                                                ? Icons.volume_off
                                                : volume < 50
                                                    ? Icons.volume_down
                                                    : Icons.volume_up,
                                            size: 18,
                                            color: c.textSecondary,
                                          ),
                                        );
                                      }),
                                    const SongDownloadButton(
                                      calledFromPlayer: true,
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed: () {
                                        final currentSong =
                                            controller.currentSong.value;
                                        if (currentSong != null) {
                                          showDialog(
                                            context: context,
                                            builder: (context) =>
                                                AddToPlaylist([currentSong]),
                                          ).whenComplete(() => Get.delete<
                                              AddToPlaylistController>());
                                        }
                                      },
                                      icon: Icon(Icons.playlist_add,
                                          size: 18,
                                          color: c.textSecondary),
                                    ),
                                    if (size.width > 965)
                                      IconButton(
                                        onPressed: () {
                                          final currentSong =
                                              controller.currentSong.value;
                                          if (currentSong != null) {
                                            showDialog(
                                              context: context,
                                              builder: (context) =>
                                                  SongInfoDialog(
                                                song: currentSong,
                                              ),
                                            );
                                          }
                                        },
                                        icon: Icon(
                                          Icons.info,
                                          size: 18,
                                          color: c.textSecondary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
