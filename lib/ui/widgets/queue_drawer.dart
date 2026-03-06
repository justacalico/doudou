import 'package:flutter/material.dart';
import '/utils/app_l10n.dart';
import 'package:get/get.dart';

import '../player/player_controller.dart';
import 'snackbar.dart';
import 'up_next_queue.dart';

class QueueDrawer extends StatelessWidget {
  const QueueDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final playerController = Get.find<PlayerController>();
    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(10)),
        border: Border(
          left: BorderSide(
              color: Theme.of(context).colorScheme.secondary),
          top: BorderSide(
              color: Theme.of(context).colorScheme.secondary),
        ),
      ),
      margin: const EdgeInsets.only(
        top: 5,
        bottom: 106,
      ),
      child: SizedBox(
        child: Column(
          children: [
            SizedBox(
              height: 60,
              child: ColoredBox(
                color: Theme.of(context).canvasColor,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(
                        left: 15.0, right: 15),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            "${playerController.currentQueue.length} ${context.l10n.songs}"),
                        Text(
                          context.l10n.upNext,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge,
                        ),
                        Row(
                          children: [
                            InkWell(
                              onTap: () {
                                playerController
                                    .toggleQueueLoopMode();
                              },
                              child: Obx(
                                () => Container(
                                  height: 30,
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 20),
                                  decoration: BoxDecoration(
                                    color: playerController
                                                .isQueueLoopModeEnabled
                                                .isFalse
                                            ? Colors.white24
                                            : Colors.white
                                                .withValues(alpha: 0.8),
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                  child: Center(
                                      child:
                                          Text(context.l10n.queueLoop)),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                if (playerController
                                    .isShuffleModeEnabled
                                    .isTrue) {
                                  showAppSnackBar(
                                      context.l10n.queueShufflingDeniedMsg,
                                      size: SnackBarSize.BIG);
                                  return;
                                }
                                playerController.shuffleQueue();
                              },
                              icon: const Icon(Icons.shuffle)),
                            IconButton(
                              onPressed: () {
                                playerController.clearQueue();
                              },
                              icon: const Icon(
                                  Icons.playlist_remove)),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Expanded(
              child: UpNextQueue(
                isQueueInSlidePanel: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
