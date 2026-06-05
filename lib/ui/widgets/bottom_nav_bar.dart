import 'package:flutter/material.dart';
import '/utils/app_l10n.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:doudou/ui/design/doudou_colors.dart';
import 'package:doudou/ui/design/doudou_motion.dart';
import 'package:doudou/ui/design/doudou_tokens.dart';
import 'package:doudou/ui/player/components/mini_player.dart';
import 'package:doudou/ui/player/player_controller.dart';
import 'package:doudou/ui/screens/Home/home_screen_controller.dart';

import 'scroll_to_hide.dart';

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({super.key});

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final homeScreenController = Get.find<HomeScreenController>();
    final playerController = Get.find<PlayerController>();
    final c = context.doudouColors;

    return Obx(() {
      final idx = homeScreenController.tabIndex.value;
      final safeIdx = idx.clamp(0, 3);
      final items = _navItems(context);
      final bottomPadding = MediaQuery.of(context).padding.bottom;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          ScrollToHideWidget(
            isVisible: playerController.isPanelGTHOpened.isFalse,
            child: Container(
              decoration: BoxDecoration(
                color: c.surfaceBase,
                border: Border(
                  top: BorderSide(color: c.borderSubtle, width: 0.5),
                ),
              ),
              child: SafeArea(
                top: false,
                left: false,
                right: false,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: DoudouSpace.s16,
                    right: DoudouSpace.s16,
                    bottom: bottomPadding > 0 ? DoudouSpace.s4 : DoudouSpace.s8,
                    top: DoudouSpace.s8,
                  ),
                  child: SizedBox(
                    height: 56,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final itemWidth = constraints.maxWidth / items.length;
                        const pillHeight = 40.0;
                        const pillWidth = 64.0;
                        final pillLeft =
                            (itemWidth * safeIdx) + (itemWidth - pillWidth) / 2;

                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedPositioned(
                              duration: DoudouMotion.selection,
                              curve: DoudouMotion.standard,
                              left: pillLeft,
                              child: Container(
                                width: pillWidth,
                                height: pillHeight,
                                decoration: BoxDecoration(
                                  color: c.surfaceSelected,
                                  borderRadius: DoudouRadii.r12,
                                ),
                              ),
                            ),
                            Row(
                              children: List.generate(items.length, (index) {
                                final selected = index == safeIdx;
                                final hovered = _hoveredIndex == index;
                                final item = items[index];
                                final iconColor = selected
                                    ? c.accentPrimary
                                    : (hovered
                                        ? c.textSecondary
                                        : c.textTertiary);
                                final labelColor = selected
                                    ? c.accentPrimary
                                    : (hovered
                                        ? c.textSecondary
                                        : c.textTertiary);

                                return Expanded(
                                  child: MouseRegion(
                                    onEnter: (_) => setState(
                                        () => _hoveredIndex = index),
                                    onExit: (_) => setState(() {
                                      if (_hoveredIndex == index) {
                                        _hoveredIndex = null;
                                      }
                                    }),
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        if (index == safeIdx) return;
                                        HapticFeedback.selectionClick();
                                        homeScreenController
                                            .onBottonBarTabSelected(index);
                                      },
                                      child: SizedBox(
                                        height: double.infinity,
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            AnimatedScale(
                                              duration: DoudouMotion.selection,
                                              curve: DoudouMotion.standard,
                                              scale: (selected || hovered)
                                                  ? 1.08
                                                  : 1.0,
                                              child: Icon(
                                                selected
                                                    ? item.icon
                                                    : item.outlinedIcon,
                                                size: DoudouIconSize.nav,
                                                color: iconColor,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              item.label,
                                              style: DoudouType.navLabel
                                                  .copyWith(color: labelColor),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _NavItem {
  _NavItem({
    required this.icon,
    required this.outlinedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData outlinedIcon;
  final String label;
}

List<_NavItem> _navItems(BuildContext context) => [
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
