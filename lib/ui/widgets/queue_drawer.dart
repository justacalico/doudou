import 'package:flutter/material.dart';
import '/utils/app_l10n.dart';
import 'package:get/get.dart';

import '../player/player_controller.dart';
import '../design/doudou_colors.dart';
import '../design/doudou_motion.dart';
import '../design/doudou_tokens.dart';
import 'snackbar.dart';
import 'up_next_queue.dart';

class QueueDrawer extends StatefulWidget {
  const QueueDrawer({super.key});

  @override
  State<QueueDrawer> createState() => _QueueDrawerState();
}

class _QueueDrawerState extends State<QueueDrawer> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerController = Get.find<PlayerController>();
    final c = context.doudouColors;
    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      decoration: BoxDecoration(
        color: c.raisedBackground,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(16)),
        border: Border(
          left: BorderSide(color: c.borderSubtle),
          top: BorderSide(color: c.borderSubtle),
        ),
      ),
      margin: EdgeInsets.only(
        top: 5,
        bottom: GetPlatform.isDesktop ? 12 : 106,
      ),
      child: SizedBox(
        child: Column(
          children: [
            SizedBox(
              height: 60,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Obx(() {
                      final count = playerController.currentQueue.length;
                      return Text(
                        "$count ${context.l10n.songs}",
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: c.textTertiary),
                      );
                    }),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.l10n.upNext,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: c.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Obx(() {
                          final enabled =
                              playerController.isQueueLoopModeEnabled.isTrue;
                          return _QueueChip(
                            label: context.l10n.queueLoop,
                            selected: enabled,
                            onTap: playerController.toggleQueueLoopMode,
                          );
                        }),
                        const SizedBox(width: 8),
                        _QueueIconButton(
                          tooltip: context.l10n.shuffleQueue,
                          icon: Icons.shuffle_rounded,
                          onTap: () {
                            if (playerController.isShuffleModeEnabled.isTrue) {
                              showAppSnackBar(
                                context.l10n.queueShufflingDeniedMsg,
                                size: SnackBarSize.BIG,
                              );
                              return;
                            }
                            playerController.shuffleQueue();
                          },
                        ),
                        const SizedBox(width: 4),
                        _QueueIconButton(
                          tooltip: context.l10n.removeFromQueue,
                          icon: Icons.playlist_remove_rounded,
                          onTap: playerController.clearQueue,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: UpNextQueue(
                isQueueInSlidePanel: false,
                scrollController: _scrollController,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueChip extends StatelessWidget {
  const _QueueChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.doudouColors;
    final fg = selected ? c.textPrimary : c.textSecondary;
    return Material(
      color: selected ? c.surfaceSelected : Colors.transparent,
      borderRadius: DoudouRadii.r20,
      child: InkWell(
        onTap: onTap,
        borderRadius: DoudouRadii.r20,
        hoverColor: c.stateHover,
        splashColor: c.statePressed,
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: DoudouMotion.selection,
          curve: DoudouMotion.standard,
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: DoudouRadii.r20,
            border: Border.all(
              color: selected ? c.borderStrong : c.borderSubtle,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: fg, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

class _QueueIconButton extends StatelessWidget {
  const _QueueIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.doudouColors;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: DoudouRadii.r12,
        child: InkWell(
          onTap: onTap,
          borderRadius: DoudouRadii.r12,
          hoverColor: c.stateHover,
          splashColor: c.statePressed,
          highlightColor: Colors.transparent,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, size: 18, color: c.textSecondary),
          ),
        ),
      ),
    );
  }
}
