import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:doudou/ui/constants/doudou_design.dart';
import 'package:doudou/ui/design/doudou_colors.dart';
import 'package:doudou/ui/shell_controller.dart';
import 'package:ionicons/ionicons.dart';

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
          height: 92,
          decoration: BoxDecoration(
            color: c.surfaceBase,
            border: Border(
              top: BorderSide(
                color: c.borderSubtle,
                width: 0.5,
              ),
            ),
          ),
          child: Column(
            children: [
              GetX<PlayerController>(builder: (pc) {
                return Padding(
                  padding: const EdgeInsets.only(
                    left: 20,
                    top: 10,
                    right: 20,
                    bottom: 0,
                  ),
                  child: ProgressBar(
                    timeLabelLocation: compactDesktop
                        ? TimeLabelLocation.none
                        : TimeLabelLocation.sides,
                    thumbRadius: 4,
                    barHeight: 2,
                    thumbGlowRadius: 0,
                    baseBarColor: c.borderStrong.withValues(alpha: 0.3),
                    bufferedBarColor: c.accentMuted.withValues(alpha: 0.2),
                    progressBarColor: c.accentPrimary,
                    thumbColor: c.accentPrimary,
                    timeLabelTextStyle: textTheme.labelSmall?.copyWith(
                      color: c.textTertiary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    progress: pc.progressBarStatus.value.current,
                    total: pc.progressBarStatus.value.total,
                    buffered: pc.progressBarStatus.value.buffered,
                    onSeek: pc.seek,
                  ),
                );
              }),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
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
                                    borderRadius: BorderRadius.circular(6),
                                    child: ImageWidget(
                                      size: 44,
                                      song: controller.currentSong.value!,
                                    ),
                                  ),
                                )
                              : const SizedBox(
                                  height: 44,
                                  width: 44,
                                ),
                        ],
                      ),
                      const SizedBox(width: 14),
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
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                controller.currentSong.value?.title ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.titleMedium?.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                controller.currentSong.value?.artist ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  color: c.textSecondary,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: controlClusterWidth,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                _ControlIconButton(
                                  icon: controller.isCurrentSongFav.isFalse
                                      ? Icons.favorite_border
                                      : Icons.favorite,
                                  onPressed: controller.toggleFavourite,
                                  isActive: controller.isCurrentSongFav.isTrue,
                                  color: c.accentPrimary,
                                ),
                                if (!compactDesktop) ...[
                                  const SizedBox(width: 4),
                                  _ControlIconButton(
                                    icon: Ionicons.shuffle,
                                    onPressed: controller.toggleShuffleMode,
                                    isActive: controller.isShuffleModeEnabled.isTrue,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(width: 8),
                            _ControlIconButton(
                              icon: Icons.skip_previous,
                              onPressed: (controller.currentQueue.isEmpty ||
                                      (controller.currentQueue.first.id ==
                                          controller.currentSong.value?.id))
                                  ? null
                                  : controller.prev,
                              iconSize: 22,
                            ),
                            const SizedBox(width: 6),
                            _PlayButton(
                              controller: controller,
                              size: 36,
                            ),
                            const SizedBox(width: 6),
                            Obx(() {
                              final isLastSong = controller
                                      .currentQueue.isEmpty ||
                                  (!(controller.isShuffleModeEnabled.isTrue ||
                                          controller.isQueueLoopModeEnabled.isTrue) &&
                                      (controller.currentQueue.last.id ==
                                          controller.currentSong.value?.id));
                              return _ControlIconButton(
                                icon: Icons.skip_next,
                                onPressed: isLastSong ? null : controller.next,
                                iconSize: 22,
                                isDisabled: isLastSong,
                              );
                            }),
                            const SizedBox(width: 8),
                            Row(
                              children: [
                                if (!compactDesktop)
                                  _ControlIconButton(
                                    icon: Icons.all_inclusive,
                                    onPressed: controller.toggleLoopMode,
                                    isActive: controller.isLoopModeEnabled.isTrue,
                                  ),
                                _ControlIconButton(
                                  icon: Icons.lyrics_outlined,
                                  onPressed: () {
                                    controller.showLyrics();
                                    showDialog(
                                            builder: (context) =>
                                                const LyricsDialog(),
                                            context: context)
                                        .whenComplete(() {
                                      controller.isDesktopLyricsDialogOpen = false;
                                      controller.showLyricsflag.value = false;
                                    });
                                    controller.isDesktopLyricsDialogOpen = true;
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: size.width < 1004 ? 0 : 20.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (!compactDesktop)
                                SizedBox(
                                  height: 20,
                                  width: 180,
                                  child: Obx(() {
                                    final volume = controller.volume.value;
                                    return Row(
                                      children: [
                                        _ControlIconButton(
                                          icon: volume == 0
                                              ? Icons.volume_off
                                              : volume > 0 && volume < 50
                                                  ? Icons.volume_down
                                                  : Icons.volume_up,
                                          onPressed: controller.mute,
                                          iconSize: 16,
                                        ),
                                        Expanded(
                                          child: SliderTheme(
                                            data: SliderTheme.of(context)
                                                .copyWith(
                                              trackHeight: 2,
                                              thumbShape:
                                                  const RoundSliderThumbShape(
                                                enabledThumbRadius: 4.0,
                                              ),
                                              overlayShape:
                                                  const RoundSliderOverlayShape(
                                                overlayRadius: 6.0,
                                              ),
                                              activeTrackColor: c.accentPrimary,
                                              inactiveTrackColor:
                                                  c.borderStrong.withValues(alpha: 0.3),
                                            ),
                                            child: Slider(
                                              value: controller.volume.value / 100,
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
                                    _ControlIconButton(
                                      icon: Icons.queue_music,
                                      onPressed: () {
                                        controller.homeScaffoldkey.currentState!
                                            .openEndDrawer();
                                      },
                                    ),
                                    if (!compactDesktop) ...[
                                      const SizedBox(width: 4),
                                      _ControlIconButton(
                                        icon: controller.isSleepTimerActive.isTrue
                                            ? Icons.timer
                                            : Icons.timer_outlined,
                                        onPressed: () {
                                          showModalBottomSheet(
                                            constraints: const BoxConstraints(
                                              maxWidth: 500,
                                            ),
                                            shape: const RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.vertical(
                                                top: Radius.circular(12.0),
                                              ),
                                            ),
                                            isScrollControlled: true,
                                            context: Get.find<ShellController>()
                                                .overlayContextOrFallback!,
                                            barrierColor:
                                                Colors.transparent.withAlpha(100),
                                            builder: (context) =>
                                                const SleepTimerBottomSheet(),
                                          );
                                        },
                                      ),
                                    ],
                                    const SizedBox(width: 4),
                                    if (compactDesktop)
                                      Obx(() {
                                        final volume = controller.volume.value;
                                        return _ControlIconButton(
                                          icon: volume == 0
                                              ? Icons.volume_off
                                              : volume < 50
                                                  ? Icons.volume_down
                                                  : Icons.volume_up,
                                          onPressed: controller.mute,
                                        );
                                      }),
                                    const SongDownloadButton(
                                      calledFromPlayer: true,
                                      iconSize: 18,
                                    ),
                                    const SizedBox(width: 4),
                                    _ControlIconButton(
                                      icon: Icons.playlist_add,
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
                                    ),
                                    if (size.width > 965) ...[
                                      const SizedBox(width: 4),
                                      _ControlIconButton(
                                        icon: Icons.info,
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
                                      ),
                                    ],
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
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ControlIconButton extends StatefulWidget {
  const _ControlIconButton({
    required this.icon,
    required this.onPressed,
    this.iconSize = 18,
    this.isActive = false,
    this.isDisabled = false,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double iconSize;
  final bool isActive;
  final bool isDisabled;
  final Color? color;

  @override
  State<_ControlIconButton> createState() => _ControlIconButtonState();
}

class _ControlIconButtonState extends State<_ControlIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.doudouColors;
    final iconColor = widget.isDisabled
        ? c.textDisabled
        : (widget.isActive
            ? (widget.color ?? c.accentPrimary)
            : (_hover ? c.textPrimary : c.textSecondary));

    return MouseRegion(
      cursor: widget.onPressed != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: widget.onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          padding: const EdgeInsets.all(6),
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: iconColor,
          ),
        ),
      ),
    );
  }
}

class _PlayButton extends StatefulWidget {
  const _PlayButton({
    required this.controller,
    required this.size,
  });

  final PlayerController controller;
  final double size;

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.doudouColors;
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () {
          final state = widget.controller.buttonState.value;
          if (state == PlayButtonState.loading) return;
          state == PlayButtonState.playing
              ? widget.controller.pause()
              : widget.controller.play();
        },
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: _hover ? c.accentPrimary : c.surfaceOverlay.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Obx(() {
            final state = widget.controller.buttonState.value;
            final isPlaying = state == PlayButtonState.playing;
            final isLoading = state == PlayButtonState.loading;

            if (isLoading) {
              return const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              );
            }

            return Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              size: widget.size * 0.45,
              color: _hover ? Colors.white : c.textPrimary,
            );
          }),
        ),
      ),
    );
  }
}

