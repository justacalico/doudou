import 'package:flutter/material.dart';
import '/utils/app_l10n.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:doudou/ui/design/doudou_colors.dart';
import 'package:doudou/ui/design/doudou_motion.dart';
import 'package:doudou/ui/design/doudou_tokens.dart';
import 'package:doudou/ui/screens/Home/home_screen_controller.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final homeScreenController = Get.find<HomeScreenController>();
    final theme = Theme.of(context);
    final c = context.doudouColors;

    return Obx(() {
      final idx = homeScreenController.tabIndex.value;
      final safeIdx = idx.clamp(0, 3);
      final items = [
        _NavItem(
          icon: Icons.home_rounded,
          outlinedIcon: Icons.home_outlined,
          label: context.l10n.home,
        ),
        _NavItem(
          icon: Icons.search_rounded,
          outlinedIcon: Icons.search_outlined,
          label: context.l10n.search,
        ),
        _NavItem(
          icon: Icons.library_music_rounded,
          outlinedIcon: Icons.library_music_outlined,
          label: context.l10n.library,
        ),
        _NavItem(
          icon: Icons.settings_rounded,
          outlinedIcon: Icons.settings_outlined,
          label: context.l10n.settings,
        ),
      ];

      return Center(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 8,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ClipRRect(
              borderRadius: DoudouRadii.r20,
              child: Container(
                height: 62,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: c.surfaceOverlay,
                  borderRadius: DoudouRadii.r20,
                  border: Border.all(color: c.borderSubtle),
                ),
                child: Row(
                  children: List.generate(items.length, (index) {
                    final selected = index == safeIdx;
                    final item = items[index];
                    final fg = selected ? c.accentPrimary : c.textTertiary;

                    return Expanded(
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkResponse(
                          radius: 28,
                          containedInkWell: true,
                          highlightShape: BoxShape.rectangle,
                          onTap: () {
                            if (index == safeIdx) return;
                            HapticFeedback.selectionClick();
                            homeScreenController.onBottonBarTabSelected(index);
                          },
                          child: AnimatedContainer(
                            duration: DoudouMotion.selection,
                            curve: DoudouMotion.standard,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: selected
                                  ? c.accentMuted.withValues(alpha: 0.20)
                                  : Colors.transparent,
                              borderRadius: DoudouRadii.r16,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  selected ? item.icon : item.outlinedIcon,
                                  size: DoudouIconSize.nav,
                                  color: fg,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 9,
                                    height: 1.0,
                                    fontWeight: FontWeight.w600,
                                    color: fg,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _NavItem {
  _NavItem(
      {required this.icon, required this.outlinedIcon, required this.label});

  final IconData icon;
  final IconData outlinedIcon;
  final String label;
}
