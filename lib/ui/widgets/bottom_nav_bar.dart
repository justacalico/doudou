import 'package:flutter/material.dart';
import '/utils/app_l10n.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:doudou/ui/player/components/mini_player.dart';
import 'package:doudou/ui/player/player_controller.dart';
import 'package:doudou/ui/screens/Home/home_screen_controller.dart';

import 'scroll_to_hide.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final homeScreenController = Get.find<HomeScreenController>();
    final playerController = Get.find<PlayerController>();

    return Obx(() {
      final idx = homeScreenController.tabIndex.value;
      final safeIdx = idx.clamp(0, 3);

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          ScrollToHideWidget(
            isVisible: playerController.isPanelGTHOpened.isFalse,
            child: NavigationBar(
              selectedIndex: safeIdx,
              onDestinationSelected: (index) {
                if (index == safeIdx) return;
                HapticFeedback.selectionClick();
                homeScreenController.onBottonBarTabSelected(index);
              },
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home_rounded),
                  label: context.l10n.home,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.search_outlined),
                  selectedIcon: const Icon(Icons.search_rounded),
                  label: context.l10n.search,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.library_music_outlined),
                  selectedIcon: const Icon(Icons.library_music_rounded),
                  label: context.l10n.library,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings_rounded),
                  label: context.l10n.settings,
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}
