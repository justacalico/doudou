import '/utils/app_l10n.dart';

import 'package:get/get.dart';
import 'package:flutter/material.dart';

import '/ui/player/components/gesture_player.dart';
import '/ui/player/components/standard_player.dart';
import '/ui/screens/Settings/settings_screen_controller.dart';
import '../widgets/snackbar.dart';
import '../widgets/up_next_queue.dart';
import '/ui/player/player_controller.dart';
import '../widgets/sliding_up_panel.dart';

/// Player screen
/// Contains the player ui
///
/// Player ui can be standard player or gesture player
class Player extends StatelessWidget {
  const Player({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final PlayerController playerController = Get.find<PlayerController>();
    final settingsScreenController = Get.find<SettingsScreenController>();
    return Scaffold(
      /// SlidingUpPanel is used to create a panel that can slide up and down
      /// It is used to show the current queue panel in mobile
      body: Obx(
        () => SlidingUpPanel(
          boxShadow: const [],
          minHeight: 0,
          maxHeight: size.height,
          isDraggable: !GetPlatform.isDesktop,
          controller: playerController.queuePanelController,
          collapsed: const SizedBox.shrink(),

          /// Panel for queue
          panelBuilder: (ScrollController sc, onReorderStart, onReorderEnd) {
            playerController.scrollController = sc;
            return Stack(
              children: [
                /// Stack first child
                /// UpNextQueue widget contains list of songs in queue
                UpNextQueue(
                  onReorderEnd: onReorderEnd,
                  onReorderStart: onReorderStart,
                  scrollController: sc,
                ),

                /// Stack second child
                /// This contains the bottom bar with queue loop, shuffle, clear queue buttons
                /// and number of songs in queue
                /// BackdropFilter is used to blur the background
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: 60 + Get.mediaQuery.padding.bottom,
                    padding: const EdgeInsets.only(
                      top: 15,
                      bottom: 10,
                      left: 10,
                      right: 10,
                    ),
                    decoration: BoxDecoration(
                      color: (Theme.of(context).bottomSheetTheme.backgroundColor ??
                              Theme.of(context).canvasColor)
                          .withValues(alpha: 0.94),
                      border: Border(
                        top: BorderSide(
                          color: Theme.of(context)
                              .dividerColor
                              .withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Obx(
                            () => Text(
                              "${playerController.currentQueue.length} ${context.l10n.songs}",
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.color,
                                  ),
                            ),
                          ),
                          InkWell(
                            onTap: playerController.toggleQueueLoopMode,
                            child: Obx(
                              () => Container(
                                height: 30,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 15),
                                decoration: BoxDecoration(
                                  color: playerController
                                          .isQueueLoopModeEnabled.isFalse
                                      ? Colors.white24
                                      : Colors.white.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Center(child: Text(context.l10n.queueLoop)),
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              if (playerController.isShuffleModeEnabled.isTrue) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  snackbar(
                                    context,
                                    context.l10n.queueShufflingDeniedMsg,
                                    size: SnackBarSize.BIG,
                                  ),
                                );
                                return;
                              }
                              playerController.shuffleQueue();
                            },
                            child: Container(
                              height: 30,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 15),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Center(
                                child: Icon(Icons.shuffle, color: Colors.black),
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: playerController.clearQueue,
                            child: Container(
                              height: 30,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 15),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Center(
                                child: Icon(Icons.playlist_remove,
                                    color: Colors.black),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },

          /// show player ui based on selected player ui in settings
          /// Gesture player is only applicable for mobile
          body: settingsScreenController.playerUi.value == 0
              ? const StandardPlayer()
              : const GesturePlayer(),
        ),
      ),
    );
  }
}
