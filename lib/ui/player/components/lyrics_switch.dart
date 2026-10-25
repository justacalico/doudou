import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '/utils/app_l10n.dart';
import 'package:doudou/ui/design/doudou_colors.dart';

import '../player_controller.dart';

class LyricsSwitch extends StatelessWidget {
  const LyricsSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final PlayerController playerController = Get.find<PlayerController>();
    return Obx(
      () => playerController.showLyricsflag.value
          ? Container(
              decoration: BoxDecoration(
                color: context.doudouColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.doudouColors.borderSubtle, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SwitchOption(
                    label: context.l10n.synced,
                    isSelected: playerController.lyricsMode.value == 0,
                    onTap: () => playerController.changeLyricsMode(0),
                  ),
                  _SwitchOption(
                    label: context.l10n.plain,
                    isSelected: playerController.lyricsMode.value == 1,
                    onTap: () => playerController.changeLyricsMode(1),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _SwitchOption extends StatelessWidget {
  const _SwitchOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? context.doudouColors.accentPrimary.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? context.doudouColors.accentPrimary
                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
