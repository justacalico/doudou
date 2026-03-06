import 'dart:ui';
import '/utils/app_l10n.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'lyrics_widget.dart';
import '../player_controller.dart';

class LyricsBottomSheet extends StatelessWidget {
  const LyricsBottomSheet({super.key});

  static Future<void> show(BuildContext context) async {
    final pc = Get.find<PlayerController>();
    if (pc.currentSong.value == null) return;
    await pc.ensureLyricsLoadedForSheet();
    if (!context.mounted) return;
    final size = MediaQuery.of(context).size;
    final height = size.height * 0.8;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 520),
      builder: (ctx) => Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(ctx)
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
              child: const LyricsBottomSheet(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pc = Get.find<PlayerController>();
    final theme = Theme.of(context);
    return Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Text(
                  context.l10n.lyrics,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Obx(() {
                  final hasSynced =
                      pc.lyrics['synced'] != null &&
                      (pc.lyrics['synced'] as String).trim().isNotEmpty;
                  if (!hasSynced) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "SYNC",
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Obx(() {
            final song = pc.currentSong.value;
            if (song == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                '${song.title} • ${song.artist ?? "—"}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }),
          const Divider(height: 1),
      const Expanded(
            child: LyricsWidget(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            ),
          ),
        ],
      );
  }
}
