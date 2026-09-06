import 'package:flutter/material.dart';
import '/utils/app_l10n.dart';

import 'package:get/get.dart';

import '/ui/player/components/lyrics_bottom_sheet.dart';
import '/ui/widgets/sleep_timer_bottom_sheet.dart';
import '/ui/shell_controller.dart';
import '/ui/widgets/sliding_up_panel.dart';
import '/ui/widgets/song_download_btn.dart';
import '/ui/widgets/songinfo_bottom_sheet.dart';
import '/ui/widgets/up_next_queue.dart';
import '../player_controller.dart';

class PlayerMobileBottomBar extends StatelessWidget {
  const PlayerMobileBottomBar({
    super.key,
    this.volumeAction,
    this.dense = false,
    this.iconColor,
  });

  final Widget? volumeAction;
  final bool dense;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final pc = Get.find<PlayerController>();
    final theme = Theme.of(context);
    final effectiveIconColor =
        iconColor ?? theme.textTheme.titleMedium?.color ?? theme.colorScheme.onSurface;
    final iconSize = dense ? 22.0 : 26.0;
    final horizontalPadding = dense ? 10.0 : 20.0;
    final topPadding = dense ? 6.0 : 12.0;
    final bottomPadding =
        (dense ? 6.0 : 12.0) + MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: horizontalPadding,
        right: horizontalPadding,
        top: topPadding,
        bottom: bottomPadding,
      ),
      child: Row(
        mainAxisAlignment: dense
            ? MainAxisAlignment.spaceBetween
            : MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            onPressed: () => _openQueue(context, pc),
            icon: Icon(Icons.queue_music_rounded, size: iconSize),
            color: effectiveIconColor,
            tooltip: "Queue",
          ),
          Obx(() => IconButton(
                onPressed: pc.toggleFavourite,
                icon: Icon(
                  pc.isCurrentSongFav.isTrue
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: iconSize,
                ),
                color: pc.isCurrentSongFav.isTrue
                    ? theme.colorScheme.error
                    : effectiveIconColor,
                tooltip: "Favorite",
              )),
          if (volumeAction != null) volumeAction!,
          IconButton(
            onPressed: () {
              final ctx = Get.find<ShellController>().overlayContextOrFallback;
              if (ctx != null) LyricsBottomSheet.show(ctx);
            },
            icon: Icon(Icons.mic_rounded, size: iconSize),
            color: effectiveIconColor,
            tooltip: context.l10n.lyrics,
          ),
          IconButton(
            onPressed: () {
              final ctx = Get.find<ShellController>().overlayContextOrFallback;
              if (ctx == null) return;
              showModalBottomSheet(
                constraints: const BoxConstraints(maxWidth: 500),
                shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(10.0)),
                ),
                isScrollControlled: true,
                context: ctx,
                barrierColor: Colors.transparent.withAlpha(100),
                builder: (context) => const SleepTimerBottomSheet(),
              );
            },
            icon: Obx(
              () => Icon(
                pc.isSleepTimerActive.isTrue
                    ? Icons.timer
                    : Icons.timer_outlined,
                size: iconSize,
              ),
            ),
            color: effectiveIconColor,
            tooltip: context.l10n.sleepTimer,
          ),
          SongDownloadButton(
            calledFromPlayer: true,
            iconSize: iconSize,
            iconColor: effectiveIconColor,
          ),
          IconButton(
            onPressed: () {
              if (pc.currentSong.value == null) return;
              showModalBottomSheet(
                constraints: const BoxConstraints(maxWidth: 500),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                ),
                isScrollControlled: true,
                context: context,
                barrierColor: Colors.transparent.withAlpha(100),
                builder: (c) => SongInfoBottomSheet(
                  pc.currentSong.value!,
                  calledFromPlayer: true,
                ),
              ).whenComplete(() => Get.delete<SongInfoController>());
            },
            icon: Icon(Icons.more_horiz_rounded, size: iconSize),
            color: effectiveIconColor,
            tooltip: "More",
          ),
        ],
      ),
    );
  }

  void _openQueue(BuildContext context, PlayerController pc) {
    if (context.findAncestorWidgetOfExactType<SlidingUpPanel>() != null) {
      pc.queuePanelController.open();
      return;
    }

    final ctx = Get.find<ShellController>().overlayContextOrFallback;
    if (ctx == null) return;

    showModalBottomSheet(
      constraints: const BoxConstraints(maxWidth: 500),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10.0)),
      ),
      isScrollControlled: true,
      context: ctx,
      barrierColor: Colors.transparent.withAlpha(100),
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.of(sheetContext).size.height * 0.8,
        child: const UpNextQueue(isQueueInSlidePanel: false),
      ),
    );
  }
}

