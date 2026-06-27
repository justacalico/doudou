import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:doudou/ui/design/doudou_colors.dart';
import 'package:doudou/ui/shell_controller.dart';
import 'package:ionicons_plus/ionicons_plus.dart';

import '/services/tv_service.dart';
import '/ui/widgets/lyrics_dialog.dart';
import '/ui/widgets/song_info_dialog.dart';
import '/ui/player/player_controller.dart';
import '/ui/screens/Settings/settings_screen_controller.dart';
import '/models/server.dart';
import '../../widgets/add_to_playlist.dart';
import '../../widgets/sleep_timer_bottom_sheet.dart';
import '../../widgets/song_download_btn.dart';
import '../../widgets/image_widget.dart';
import '../../widgets/mini_player_progress_bar.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final playerController = Get.find<PlayerController>();
    final size = MediaQuery.of(context).size;
    return Obx(() {
      final bottomNavEnabled = Get.find<ShellController>().useBottomNav.value;
      final isTv =
          Get.isRegistered<TvService>() && Get.find<TvService>().isTV.value;
      final content = isTv
          ? _TvMiniPlayer(controller: playerController)
          : bottomNavEnabled
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
    return Container(
      height: 56,
      color: c.surfaceOverlay,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            child: Row(
              children: [
                if (song != null)
                  GestureDetector(
                    onTap: controller.playerPanelController.open,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: ImageWidget(
                        size: 40,
                        song: song,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 40, width: 40),
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
                    Obx(() => IconButton(
                          iconSize: 24,
                          onPressed: controller.toggleFavourite,
                          icon: Icon(
                            controller.isCurrentSongFav.isTrue
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: controller.isCurrentSongFav.isTrue
                                ? theme.colorScheme.error
                                : c.textPrimary,
                          ),
                        )),
                    Obx(() {
                      final state = controller.buttonState.value;
                      final isPlaying = state == PlayButtonState.playing;
                      final isLoading = state == PlayButtonState.loading;

                      return IconButton(
                        iconSize: 28,
                        onPressed: () {
                          if (isLoading) return;
                          isPlaying ? controller.pause() : controller.play();
                        },
                        icon: isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
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
                      icon: Icon(Icons.skip_next_rounded, color: c.textPrimary),
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
    );
  }
}

class _DesktopMiniPlayer extends StatefulWidget {
  const _DesktopMiniPlayer({
    required this.controller,
    required this.size,
  });

  final PlayerController controller;
  final Size size;

  @override
  State<_DesktopMiniPlayer> createState() => _DesktopMiniPlayerState();
}

class _DesktopMiniPlayerState extends State<_DesktopMiniPlayer> {
  final LayerLink _volumeLayerLink = LayerLink();
  OverlayEntry? _volumeOverlay;

  void _toggleVolumePopup() {
    if (_volumeOverlay != null) {
      _removeVolumePopup();
    } else {
      _showVolumePopup();
    }
  }

  void _showVolumePopup() {
    _volumeOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _removeVolumePopup,
            child: const SizedBox.expand(),
          ),
          CompositedTransformFollower(
            link: _volumeLayerLink,
            targetAnchor: Alignment.topCenter,
            followerAnchor: Alignment.bottomCenter,
            offset: const Offset(0, -8),
            child: _DesktopVolumePopup(
              controller: widget.controller,
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_volumeOverlay!);
  }

  void _removeVolumePopup() {
    _volumeOverlay?.remove();
    _volumeOverlay = null;
  }

  @override
  void dispose() {
    _removeVolumePopup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final size = widget.size;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final c = context.doudouColors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactDesktop = size.width < 1100;

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
                    timeLabelLocation: TimeLabelLocation.sides,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6),
                  child: Row(
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
                          const SizedBox(width: 14),
                          GestureDetector(
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
                                  _truncateTitle(
                                      controller.currentSong.value?.title ??
                                          ''),
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
                        ],
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Obx(() => _ControlIconButton(
                                      icon: controller.isCurrentSongFav.isFalse
                                          ? Icons.favorite_border
                                          : Icons.favorite,
                                      onPressed: controller.toggleFavourite,
                                      isActive:
                                          controller.isCurrentSongFav.isTrue,
                                      color: c.accentPrimary,
                                    )),
                                if (!compactDesktop) ...[
                                  const SizedBox(width: 4),
                                  Obx(() => _ControlIconButton(
                                        icon: Ionicons.shuffle,
                                        onPressed: controller.toggleShuffleMode,
                                        isActive: controller
                                            .isShuffleModeEnabled.isTrue,
                                      )),
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
                                          controller
                                              .isQueueLoopModeEnabled.isTrue) &&
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
                                  Obx(() {
                                    final settings =
                                        Get.find<SettingsScreenController>();
                                    final isYouTube =
                                        settings.activeServer?.type ==
                                            ServerType.youtubeMusic;
                                    if (!isYouTube)
                                      return const SizedBox.shrink();
                                    return _ControlIconButton(
                                      icon: Icons.all_inclusive,
                                      onPressed: controller.toggleLoopMode,
                                      isActive:
                                          controller.isLoopModeEnabled.isTrue,
                                    );
                                  }),
                                _ControlIconButton(
                                  icon: Icons.lyrics_outlined,
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
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
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
                                          data:
                                              SliderTheme.of(context).copyWith(
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
                                            inactiveTrackColor: c.borderStrong
                                                .withValues(alpha: 0.3),
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
                                            borderRadius: BorderRadius.vertical(
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
                                    CompositedTransformTarget(
                                      link: _volumeLayerLink,
                                      child: Obx(() {
                                        final volume = controller.volume.value;
                                        return _ControlIconButton(
                                          icon: volume == 0
                                              ? Icons.volume_off
                                              : volume < 50
                                                  ? Icons.volume_down
                                                  : Icons.volume_up,
                                          onPressed: _toggleVolumePopup,
                                          onSecondaryTap: controller.mute,
                                        );
                                      }),
                                    ),
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
                                        ).whenComplete(() => Get.delete<
                                            AddToPlaylistController>());
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

class _DesktopVolumePopup extends StatelessWidget {
  const _DesktopVolumePopup({required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 44,
        height: 150,
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.black.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.18)
                : Colors.black.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Obx(() {
                    final v = controller.volume.value;
                    return SliderTheme(
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
                          controller
                              .setVolume((value * 100).round().clamp(0, 100));
                        },
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 6),
              Obx(() {
                final v = controller.volume.value;
                return Icon(
                  v == 0
                      ? Icons.volume_off_rounded
                      : v < 50
                          ? Icons.volume_down_rounded
                          : Icons.volume_up_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _TvMiniPlayer extends StatelessWidget {
  const _TvMiniPlayer({required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final c = context.doudouColors;
    final song = controller.currentSong.value;

    return Container(
      decoration: BoxDecoration(
        color: c.surfaceBase,
        border: Border(
          top: BorderSide(color: c.borderSubtle, width: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        child: Row(
          children: [
            // Album art
            if (song != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ImageWidget(size: 48, song: song),
              )
            else
              const SizedBox(width: 48, height: 48),
            const SizedBox(width: 20),
            // Title and artist
            Expanded(
              child: GestureDetector(
                onTap: controller.playerPanelController.open,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      song?.title ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      song?.artist ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            // Timeline / progress bar
            SizedBox(
              width: 300,
              child: GetX<PlayerController>(
                init: controller,
                builder: (pc) => ProgressBar(
                  timeLabelLocation: TimeLabelLocation.sides,
                  thumbRadius: 5,
                  barHeight: 3,
                  thumbGlowRadius: 0,
                  baseBarColor: c.borderStrong.withValues(alpha: 0.3),
                  bufferedBarColor: c.accentMuted.withValues(alpha: 0.2),
                  progressBarColor: c.accentPrimary,
                  thumbColor: c.accentPrimary,
                  timeLabelTextStyle: textTheme.labelSmall?.copyWith(
                    color: c.textTertiary,
                    fontSize: 12,
                  ),
                  progress: pc.progressBarStatus.value.current,
                  total: pc.progressBarStatus.value.total,
                  buffered: pc.progressBarStatus.value.buffered,
                  onSeek: pc.seek,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _truncateTitle(String title, {int maxChars = 12}) {
  if (title.length <= maxChars) return title;
  return '${title.substring(0, 10)}…';
}

class _ControlIconButton extends StatefulWidget {
  const _ControlIconButton({
    required this.icon,
    required this.onPressed,
    this.onSecondaryTap,
    this.iconSize = 18,
    this.isActive = false,
    this.isDisabled = false,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final VoidCallback? onSecondaryTap;
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
      cursor: widget.onPressed != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: widget.onPressed,
        onSecondaryTap: widget.onSecondaryTap,
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
            color: _hover
                ? c.accentPrimary
                : c.surfaceOverlay.withValues(alpha: 0.6),
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
