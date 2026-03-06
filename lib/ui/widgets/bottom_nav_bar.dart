import 'dart:ui';

import 'package:flutter/material.dart';
import '/utils/app_l10n.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:doudou/ui/screens/Home/home_screen_controller.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final homeScreenController = Get.find<HomeScreenController>();
    final theme = Theme.of(context);
    final surfaceLuminance = theme.colorScheme.surface.computeLuminance();
    final isLightSurface = surfaceLuminance > 0.15;
    final dockAlpha = isLightSurface ? 0.06 : (theme.brightness == Brightness.dark ? 0.14 : 0.24);
    final borderAlpha = isLightSurface ? 0.06 : (theme.brightness == Brightness.dark ? 0.14 : 0.22);
    final dockColor = theme.colorScheme.surface.withValues(alpha: dockAlpha);

    return Obx(() {
      final idx = homeScreenController.tabIndex.value;
      final safeIdx = idx < 0 ? 0 : (idx > 3 ? 3 : idx);
      final items = [
        _NavItem(
          icon: Icons.home_rounded,
          outlinedIcon: Icons.home_outlined,
          label: modifyNgetlabel(context.l10n.home),
        ),
        _NavItem(
          icon: Icons.search_rounded,
          outlinedIcon: Icons.search_outlined,
          label: modifyNgetlabel(context.l10n.search),
        ),
        _NavItem(
          icon: Icons.library_music_rounded,
          outlinedIcon: Icons.library_music_outlined,
          label: modifyNgetlabel(context.l10n.library),
        ),
        _NavItem(
          icon: Icons.settings_rounded,
          outlinedIcon: Icons.settings_outlined,
          label: modifyNgetlabel(context.l10n.settings),
        ),
      ];

      return Center(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).padding.bottom + 10,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: dockColor,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: borderAlpha),
                      width: 0.5,
                    ),
                    boxShadow: const [],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(items.length, (index) {
                      final selected = index == safeIdx;
                      final item = items[index];

                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (index == safeIdx) return;
                            HapticFeedback.selectionClick();
                            homeScreenController.onBottonBarTabSelected(index);
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? theme.colorScheme.primary
                                          .withValues(alpha: 0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  selected ? item.icon : item.outlinedIcon,
                                  size: 22,
                                  color: selected
                                      ? theme.colorScheme.primary
                                      : theme.iconTheme.color
                                          ?.withValues(alpha: 0.4),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.label,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 10,
                                  fontWeight: selected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: selected
                                      ? theme.colorScheme.primary
                                      : theme.textTheme.labelSmall?.color
                                          ?.withValues(alpha: 0.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  String modifyNgetlabel(String label) {
    if (label.length > 9) {
      return "${label.substring(0, 8)}..";
    }
    return label;
  }
}

class _NavItem {
  _NavItem(
      {required this.icon, required this.outlinedIcon, required this.label});

  final IconData icon;
  final IconData outlinedIcon;
  final String label;
}
