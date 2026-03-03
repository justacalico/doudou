import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:doudou/ui/screens/Home/home_screen_controller.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  static const double _iconOnlyBreakpoint = 400;

  @override
  Widget build(BuildContext context) {
    final homeScreenController = Get.find<HomeScreenController>();
    final width = MediaQuery.sizeOf(context).width;
    final iconOnly = width < _iconOnlyBreakpoint;
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;

    return Obx(() {
      final idx = homeScreenController.tabIndex.value;
      final safeIdx = idx < 0 ? 0 : (idx > 3 ? 3 : idx);
      final items = [
        _NavItem(
          icon: Icons.home_rounded,
          label: modifyNgetlabel('home'.tr),
        ),
        _NavItem(
          icon: Icons.search_rounded,
          label: modifyNgetlabel('search'.tr),
        ),
        _NavItem(
          icon: Icons.library_music_rounded,
          label: modifyNgetlabel('library'.tr),
        ),
        _NavItem(
          icon: Icons.settings_rounded,
          label: modifyNgetlabel('settings'.tr),
        ),
      ];

      return Center(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: iconOnly ? 12 : 18,
                    vertical: iconOnly ? 8 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: surface.withValues(alpha: 0.88),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(items.length, (index) {
                      final selected = index == safeIdx;
                      final item = items[index];
                      final iconColor = selected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4);
                      final labelStyle = theme.textTheme.labelSmall?.copyWith(
                        color: selected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      );
                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (index == safeIdx) return;
                            HapticFeedback.selectionClick();
                            homeScreenController.onBottonBarTabSelected(index);
                          },
                          child: TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            tween: Tween<double>(
                              begin: 0.0,
                              end: selected ? 1.0 : 0.0,
                            ),
                            builder: (context, value, _) {
                              final scale = 1.0 + 0.1 * value;
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOut,
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? Colors.white.withValues(alpha: 0.1)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Transform.scale(
                                      scale: scale,
                                      child: Icon(
                                        item.icon,
                                        size: 20,
                                        color: iconColor,
                                      ),
                                    ),
                                  ),
                                  if (!iconOnly)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        item.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: labelStyle,
                                      ),
                                    ),
                                ],
                              );
                            },
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
  _NavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}
