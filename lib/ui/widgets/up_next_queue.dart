import 'package:flutter/material.dart';
import '/utils/app_l10n.dart';
import '/l10n/app_localizations.dart';
import 'package:get/get.dart';
import 'package:doudou/ui/player/player_controller.dart';
import 'package:widget_marquee/widget_marquee.dart';

import '../shell_controller.dart';
import 'image_widget.dart';
import 'snackbar.dart';
import 'songinfo_bottom_sheet.dart';

class UpNextQueue extends StatelessWidget {
  const UpNextQueue(
      {super.key,
      this.onReorderEnd,
      this.onReorderStart,
      this.isQueueInSlidePanel = true});
  final void Function(int)? onReorderStart;
  final void Function(int)? onReorderEnd;
  final bool isQueueInSlidePanel;

  @override
  Widget build(BuildContext context) {
    final playerController = Get.find<PlayerController>();
    return Container(
      color: isQueueInSlidePanel
          ? Theme.of(context).bottomSheetTheme.backgroundColor
          : Colors.transparent,
      child: Obx(() {
        final queue = playerController.currentQueue;
        final isShuffled = playerController.isShuffleModeEnabled.isTrue;
        final currentIndex = playerController.currentSongIndex.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Queue",
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Playing from queue",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: AppLocalizations.of(Get.context!)!.close,
                    onPressed: () {
                      if (isQueueInSlidePanel) {
                        Get.find<PlayerController>()
                            .queuePanelController
                            .close();
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: playerController.toggleShuffleMode,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: isShuffled
                            ? Theme.of(context).colorScheme.secondary
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shuffle_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            "SHUFFLED",
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => playerController.clearQueue(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.close_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            "Clear Queue",
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ReorderableListView.builder(
                footer: SizedBox(height: Get.mediaQuery.padding.bottom),
                scrollController: isQueueInSlidePanel
                    ? playerController.scrollController
                    : null,
                onReorder: (int oldIndex, int newIndex) {
                  if (playerController.isShuffleModeEnabled.isTrue) {
                    ScaffoldMessenger.of(Get.context!).showSnackBar(snackbar(
                        Get.context!, AppLocalizations.of(Get.context!)!.queuerearrangingDeniedMsg,
                        size: SnackBarSize.BIG));
                    return;
                  }
                  playerController.onReorder(oldIndex, newIndex);
                },
                onReorderStart: onReorderStart,
                onReorderEnd: onReorderEnd,
                itemCount: queue.length,
                padding: EdgeInsets.only(
                    top: 8, bottom: isQueueInSlidePanel ? 80 : 0),
                physics: const AlwaysScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final homeScaffoldContext =
                      Get.find<ShellController>().overlayContextOrFallback!;
                  final item = queue[index];
                  final isCurrent = index == currentIndex;
                  return Material(
                    key: ValueKey<String>(item.id),
                    child: Dismissible(
                      key: ValueKey<String>('queue_dismiss_${item.id}'),
                      direction: DismissDirection.horizontal,
                      confirmDismiss: (_) async => !isCurrent,
                      onDismissed: (_) => playerController.removeFromQueue(item),
                      child: ListTile(
                        onTap: () => playerController.seekByIndex(index),
                        onLongPress: () {
                          showModalBottomSheet(
                            constraints: const BoxConstraints(maxWidth: 500),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(10.0)),
                            ),
                            isScrollControlled: true,
                            context: Get.find<ShellController>()
                                .overlayContextOrFallback!,
                            barrierColor: Colors.transparent.withAlpha(100),
                            builder: (context) => SongInfoBottomSheet(
                              item,
                              calledFromQueue: true,
                            ),
                          ).whenComplete(() => Get.delete<SongInfoController>());
                        },
                        contentPadding: EdgeInsets.only(
                          top: 0,
                          left: GetPlatform.isAndroid ? 30 : 0,
                          right: 25,
                        ),
                        tileColor: isCurrent
                            ? Theme.of(homeScaffoldContext)
                                .colorScheme
                                .secondary
                            : Theme.of(homeScaffoldContext)
                                .bottomSheetTheme
                                .backgroundColor,
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (GetPlatform.isDesktop)
                              IconButton(
                                onPressed: () {
                                  if (isCurrent) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      snackbar(
                                        context,
                                        context
                                            .l10n.songRemovedfromQueueCurrSong,
                                        size: SnackBarSize.BIG,
                                      ),
                                    );
                                    return;
                                  }
                                  playerController.removeFromQueue(item);
                                },
                                icon: const Icon(Icons.close),
                              ),
                            ImageWidget(size: 50, song: item),
                          ],
                        ),
                        title: isCurrent
                            ? Marquee(
                                delay: const Duration(milliseconds: 300),
                                duration: const Duration(seconds: 5),
                                id: "queue_${item.id}_${item.title.hashCode}",
                                child: Text(
                                  item.title,
                                  maxLines: 1,
                                  style: Theme.of(homeScaffoldContext)
                                      .textTheme
                                      .titleMedium,
                                ),
                              )
                            : Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(homeScaffoldContext)
                                    .textTheme
                                    .titleMedium,
                              ),
                        subtitle: Text(
                          "${item.artist}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: isCurrent
                              ? Theme.of(homeScaffoldContext)
                                  .textTheme
                                  .titleSmall!
                                  .copyWith(
                                    color: Theme.of(homeScaffoldContext)
                                        .textTheme
                                        .titleMedium!
                                        .color!
                                        .withValues(alpha: 0.35),
                                  )
                              : Theme.of(homeScaffoldContext)
                                  .textTheme
                                  .titleSmall,
                        ),
                        trailing: ReorderableDragStartListener(
                          enabled: !GetPlatform.isDesktop,
                          index: index,
                          child: Container(
                            padding: EdgeInsets.only(
                              right: (GetPlatform.isDesktop) ? 20 : 5,
                              left: 20,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                if (!GetPlatform.isDesktop)
                                  const Icon(Icons.drag_handle),
                                isCurrent
                                    ? const Icon(
                                        Icons.equalizer,
                                        color: Colors.white,
                                      )
                                    : Text(
                                        item.extras?['length'] ?? "",
                                        style: Theme.of(homeScaffoldContext)
                                            .textTheme
                                            .titleSmall,
                                      ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      }),
    );
  }
}
