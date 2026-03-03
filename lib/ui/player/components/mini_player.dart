import 'dart:ui';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
    final isWideScreen = size.width > 800;
    final bottomNavEnabled = Get.find<ShellController>().useBottomNav.value;
    final isMobilePill = !isWideScreen || bottomNavEnabled;
    return Obx(() {
      return Visibility(
        visible: playerController.isPlayerpanelTopVisible.value &&
            playerController.currentSong.value != null,
        child: AnimatedOpacity(
          opacity: playerController.playerPaneOpacity.value,
          duration: Duration.zero,
          child: SizedBox(
            height: playerController.playerPanelMinHeight.value,
            width: size.width,
            child: isMobilePill
                ? _MobileMiniPlayer(
                    controller: playerController,
                  )
                : _DesktopMiniPlayer(
                    controller: playerController,
                    size: size,
                  ),
          ),
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
    final song = controller.currentSong.value;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Align(
        alignment: Alignment.topCenter,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 3,
                    child: GetX<PlayerController>(
                      init: controller,
                      builder: (c) => MiniPlayerProgressBar(
                        progressBarStatus: c.progressBarStatus.value,
                        progressBarColor:
                            theme.colorScheme.primary.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      children: [
                        if (song != null)
                          GestureDetector(
                            onTap: controller.playerPanelController.open,
                            child: ImageWidget(
                              size: 44,
                              song: song,
                            ),
                          )
                        else
                          const SizedBox(
                            height: 44,
                            width: 44,
                          ),
                        const SizedBox(width: 10),
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
                                  style: textTheme.titleMedium,
                                ),
                                const SizedBox(height: 2),
                                SizedBox(
                                  height: 18,
                                  child: Marquee(
                                    id: "${song}_mini",
                                    delay:
                                        const Duration(milliseconds: 400),
                                    duration: const Duration(seconds: 6),
                                    child: Text(
                                      song?.artist ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: textTheme.bodySmall?.copyWith(
                                        color: textTheme.bodySmall?.color
                                            ?.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 92,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              SizedBox.square(
                                dimension: 40,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: const Center(
                                    child: AnimatedPlayButton(
                                      iconSize: 26,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Obx(() {
                                final isLastSong =
                                    controller.currentQueue.isEmpty ||
                                        (!(controller.isShuffleModeEnabled
                                                .isTrue ||
                                            controller
                                                .isQueueLoopModeEnabled
                                                .isTrue) &&
                                            (controller.currentQueue.last.id ==
                                                controller.currentSong.value
                                                    ?.id));
                                final color = isLastSong
                                    ? theme.iconTheme.color
                                        ?.withValues(alpha: 0.25)
                                    : theme.iconTheme.color;
                                return GestureDetector(
                                  onTap: isLastSong ? null : controller.next,
                                  child: Icon(
                                    CupertinoIcons.forward_end_fill,
                                    size: 22,
                                    color: color,
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
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

    return Container(
      color: theme.bottomSheetTheme.backgroundColor,
      child: Center(
        child: Column(
          children: [
            GetX<PlayerController>(builder: (c) {
              return Padding(
                padding:
                    const EdgeInsets.only(left: 15, top: 8, right: 15, bottom: 0),
                child: ProgressBar(
                  timeLabelLocation: TimeLabelLocation.sides,
                  thumbRadius: 7,
                  barHeight: 4,
                  thumbGlowRadius: 15,
                  baseBarColor: theme.sliderTheme.inactiveTrackColor,
                  bufferedBarColor: theme.sliderTheme.valueIndicatorColor,
                  progressBarColor: theme.sliderTheme.activeTrackColor,
                  thumbColor: theme.sliderTheme.thumbColor,
                  timeLabelTextStyle: textTheme.titleMedium,
                  progress: c.progressBarStatus.value.current,
                  total: c.progressBarStatus.value.total,
                  buffered: c.progressBarStatus.value.buffered,
                  onSeek: c.seek,
                ),
              );
            }),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 17.0, vertical: 7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      controller.currentSong.value != null
                          ? ImageWidget(
                              size: 50,
                              song: controller.currentSong.value!,
                            )
                          : const SizedBox(
                              height: 50,
                              width: 50,
                            ),
                    ],
                  ),
                  const SizedBox(width: 10),
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
                              height: 20,
                              child: Text(
                                controller.currentSong.value?.title ?? '',
                                maxLines: 1,
                                style: textTheme.titleMedium,
                              ),
                            ),
                            SizedBox(
                              height: 20,
                              child: Marquee(
                                id:
                                    "${controller.currentSong.value}_mini_desktop",
                                delay: const Duration(milliseconds: 300),
                                duration: const Duration(seconds: 5),
                                child: Text(
                                  controller.currentSong.value?.artist ?? '',
                                  maxLines: 1,
                                  style: textTheme.titleSmall,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 450,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Row(
                          children: [
                            IconButton(
                                iconSize: 20,
                                onPressed: controller.toggleFavourite,
                                icon: Obx(() => Icon(
                                      controller.isCurrentSongFav.isFalse
                                          ? Icons.favorite_border
                                          : Icons.favorite,
                                      color: textTheme.titleMedium!.color,
                                    ))),
                            IconButton(
                                iconSize: 20,
                                onPressed: controller.toggleShuffleMode,
                                icon: Obx(() => Icon(
                                      Ionicons.shuffle,
                                      color: controller
                                              .isShuffleModeEnabled.value
                                          ? textTheme.titleLarge!.color
                                          : textTheme.titleLarge!.color!
                                              .withValues(alpha: 0.2),
                                    ))),
                          ],
                        ),
                        SizedBox(
                          width: 40,
                          child: InkWell(
                            onTap: (controller.currentQueue.isEmpty ||
                                    (controller.currentQueue.first.id ==
                                        controller.currentSong.value?.id))
                                ? null
                                : controller.prev,
                            child: Icon(
                              Icons.skip_previous,
                              color: textTheme.titleMedium!.color,
                              size: 35,
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          width: 58,
                          height: 58,
                          child: const Center(
                            child: AnimatedPlayButton(
                              iconSize: 43,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: Obx(() {
                            final isLastSong =
                                controller.currentQueue.isEmpty ||
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
                                    ? textTheme.titleLarge!.color!
                                        .withValues(alpha: 0.2)
                                    : textTheme.titleMedium!.color,
                                size: 35,
                              ),
                            );
                          }),
                        ),
                        Row(
                          children: [
                            IconButton(
                                iconSize: 20,
                                onPressed: controller.toggleLoopMode,
                                icon: Icon(
                                  Icons.all_inclusive,
                                  color: controller.isLoopModeEnabled.value
                                      ? textTheme.titleLarge!.color
                                      : textTheme.titleLarge!.color!
                                          .withValues(alpha: 0.2),
                                )),
                            IconButton(
                                iconSize: 20,
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
                                  controller.isDesktopLyricsDialogOpen = true;
                                },
                                icon: Icon(
                                  Icons.lyrics_outlined,
                                  color: textTheme.titleLarge!.color,
                                )),
                          ],
                        ),
                        const SizedBox(width: 20),
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
                          Container(
                            padding:
                                const EdgeInsets.only(right: 20, left: 10),
                            height: 20,
                            width: (size.width > 860) ? 220 : 180,
                            child: Obx(() {
                              final volume = controller.volume.value;
                              return Row(
                                children: [
                                  SizedBox(
                                    width: 20,
                                    child: InkWell(
                                      onTap: controller.mute,
                                      child: Icon(
                                        volume == 0
                                            ? Icons.volume_off
                                            : volume > 0 && volume < 50
                                                ? Icons.volume_down
                                                : Icons.volume_up,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 2,
                                        thumbShape:
                                            const RoundSliderThumbShape(
                                          enabledThumbRadius: 6.0,
                                        ),
                                        overlayShape:
                                            const RoundSliderOverlayShape(
                                          overlayRadius: 10.0,
                                        ),
                                      ),
                                      child: Slider(
                                        value: controller.volume.value / 100,
                                        onChanged: (value) {
                                          controller
                                              .setVolume((value * 100).toInt());
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ),
                          SizedBox(
                            height: 40,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  onPressed: () {
                                    controller.homeScaffoldkey.currentState!
                                        .openEndDrawer();
                                  },
                                  icon: const Icon(Icons.queue_music),
                                ),
                                if (size.width > 860)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(left: 10.0),
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
                                              top: Radius.circular(10.0),
                                            ),
                                          ),
                                          isScrollControlled: true,
                                          context:
                                              Get.find<ShellController>()
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
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 10),
                                const SongDownloadButton(
                                  calledFromPlayer: true,
                                ),
                                const SizedBox(width: 10),
                                IconButton(
                                  onPressed: () {
                                    final currentSong =
                                        controller.currentSong.value;
                                    if (currentSong != null) {
                                      showDialog(
                                        context: context,
                                        builder: (context) =>
                                            AddToPlaylist([currentSong]),
                                      ).whenComplete(() =>
                                          Get.delete<AddToPlaylistController>());
                                    }
                                  },
                                  icon: const Icon(Icons.playlist_add),
                                ),
                                if (size.width > 965)
                                  IconButton(
                                    onPressed: () {
                                      final currentSong =
                                          controller.currentSong.value;
                                      if (currentSong != null) {
                                        showDialog(
                                          context: context,
                                          builder: (context) => SongInfoDialog(
                                            song: currentSong,
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.info,
                                      size: 22,
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
  }
}
