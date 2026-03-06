import 'package:flutter/material.dart';
import '/utils/app_l10n.dart';
import 'package:get/get.dart';
import 'package:doudou/ui/player/player_controller.dart';
import 'package:doudou/ui/screens/Home/home_screen_controller.dart';
import 'package:doudou/ui/widgets/animated_side_bar_local.dart';

class SideNavBar extends StatefulWidget {
  const SideNavBar({
    super.key,
    required this.minimized,
    required this.onMinimizeChanged,
  });

  final bool minimized;
  final ValueChanged<bool> onMinimizeChanged;

  @override
  State<SideNavBar> createState() => _SideNavBarState();
}

class _SideNavBarState extends State<SideNavBar> {
  ValueNotifier<int>? _tabIndexNotifier;
  Worker? _tabIndexWorker;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tabIndexNotifier == null) {
      final controller = Get.find<HomeScreenController>();
      _tabIndexNotifier = ValueNotifier<int>(controller.tabIndex.value);
      _tabIndexWorker =
          ever(controller.tabIndex, (v) => _tabIndexNotifier!.value = v);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _tabIndexWorker?.dispose();
    _tabIndexNotifier?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final homeScreenController = Get.find<HomeScreenController>();
    final playerController = Get.find<PlayerController>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sideBarColor = scheme.surface;
    final animatedContainerColor = scheme.surfaceContainerHighest;
    final hoverColor = animatedContainerColor.withValues(alpha: 0.7);
    final splashColor = scheme.secondary.withValues(alpha: 0.5);
    final highlightColor = scheme.secondary.withValues(alpha: 0.35);
    final sidebar = SideBarAnimatedLocal(
      initialIndex: homeScreenController.tabIndex.value,
      currentIndexListenable: _tabIndexNotifier,
      onTap: homeScreenController.onSideBarTabSelected,
      minimized: widget.minimized,
      onMinimizeChanged: widget.onMinimizeChanged,
      sideBarColor: sideBarColor,
      animatedContainerColor: animatedContainerColor,
      hoverColor: hoverColor,
      splashColor: splashColor,
      highlightColor: highlightColor,
      widthSwitch: 800,
      mainLogoImage: 'assets/icons/icon.png',
      appName: 'Doudou',
      shrinkSidebarLabel: 'Shrink sidebar',
      sidebarItems: [
        SideBarItemLocal(
          iconSelected: Icons.home,
          iconUnselected: Icons.home_outlined,
          text: context.l10n.home,
        ),
        SideBarItemLocal(
          iconSelected: Icons.audiotrack,
          iconUnselected: Icons.audiotrack,
          text: context.l10n.songs,
        ),
        SideBarItemLocal(
          iconSelected: Icons.library_music,
          iconUnselected: Icons.library_music_outlined,
          text: context.l10n.playlists,
        ),
        SideBarItemLocal(
          iconSelected: Icons.album,
          iconUnselected: Icons.album_outlined,
          text: context.l10n.albums,
        ),
        SideBarItemLocal(
          iconSelected: Icons.person,
          text: context.l10n.artists,
        ),
        SideBarItemLocal(
          iconSelected: Icons.settings,
          iconUnselected: Icons.settings_outlined,
          text: context.l10n.settings,
        ),
      ],
    );
    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: sidebar),
        Obx(() => SizedBox(
            height: playerController.currentSong.value != null
                ? playerController.playerPanelMinHeight.value
                : 0.0)),
      ],
    );
  }
}
