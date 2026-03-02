import 'package:flutter/material.dart';
import 'dart:ui';

import 'package:get/get.dart';

import '/ui/player/components/lyrics_bottom_sheet.dart';
import '/ui/widgets/sleep_timer_bottom_sheet.dart';
import '/ui/shell_controller.dart';
import '/ui/widgets/song_download_btn.dart';
import '/ui/widgets/songinfo_bottom_sheet.dart';
import '/ui/widgets/up_next_queue.dart';
import '../player_controller.dart';

class PlayerMobileBottomBar extends StatelessWidget {
  const PlayerMobileBottomBar({
    super.key,
    this.volumeAction,
  });

  final Widget? volumeAction;

  @override
  Widget build(BuildContext context) {
    final pc = Get.find<PlayerController>();
    final theme = Theme.of(context);
    final iconColor = theme.textTheme.titleMedium?.color ??
        theme.colorScheme.onSurface;
    const iconSize = 26.0;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: 12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            onPressed: () {
              final ctx = Get.find<ShellController>().overlayContextOrFallback;
              if (ctx == null) return;
              final size = MediaQuery.of(ctx).size;
              final height = size.height * 0.8;
              showModalBottomSheet(
                context: ctx,
                isScrollControlled: true,
                useSafeArea: true,
                backgroundColor: Colors.transparent,
                barrierColor: Colors.transparent,
                constraints: const BoxConstraints(maxWidth: 520),
                builder: (c) => Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: Container(
                        height: height,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(c)
                              .colorScheme
                              .surface
                              .withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 22,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: const UpNextQueue(isQueueInSlidePanel: false),
                      ),
                    ),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.queue_music_rounded, size: iconSize),
            color: iconColor,
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
                    : iconColor,
                tooltip: "Favorite",
              )),
          if (volumeAction != null) volumeAction!,
          IconButton(
            onPressed: () {
              final ctx = Get.find<ShellController>().overlayContextOrFallback;
              if (ctx != null) LyricsBottomSheet.show(ctx);
            },
            icon: const Icon(Icons.mic_rounded, size: iconSize),
            color: iconColor,
            tooltip: "lyrics".tr,
          ),
          IconButton(
            onPressed: () {
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
            color: iconColor,
            tooltip: "sleepTimer".tr,
          ),
          const SongDownloadButton(
            calledFromPlayer: true,
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
            icon: const Icon(Icons.more_horiz_rounded, size: iconSize),
            color: iconColor,
            tooltip: "More",
          ),
        ],
      ),
    );
  }
}
