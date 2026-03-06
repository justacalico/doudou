import 'dart:ui';

import 'package:flutter/material.dart';
import '/utils/app_l10n.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:doudou/ui/constants/doudou_design.dart';
import 'package:doudou/ui/screens/Home/home_screen_controller.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final homeScreenController = Get.find<HomeScreenController>();
    final theme = Theme.of(context);

    return Obx(() {
      final idx = homeScreenController.tabIndex.value;
      final safeIdx = idx.clamp(0, 3);
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
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 8,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ClipRRect(
              borderRadius:
                  BorderRadius.circular(kDoudouRadiusCard),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                    sigmaX: kDoudouBlurBar, sigmaY: kDoudouBlurBar),
                child: Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius:
                        BorderRadius.circular(kDoudouRadiusCard),
                    border: Border.all(
                      color: kDoudouBorder,
                      width: 1,
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
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedScale(
                                scale: selected ? 1.1 : 1.0,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  selected ? item.icon : item.outlinedIcon,
                                  size: 20,
                                  color: selected
                                      ? kDoudouPurpleLight
                                      : kDoudouZinc500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.label,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: selected
                                      ? kDoudouPurpleLight
                                      : kDoudouZinc500,
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
