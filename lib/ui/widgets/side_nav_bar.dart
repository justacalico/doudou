import 'package:flutter/material.dart';
import '/utils/app_l10n.dart';
import 'package:get/get.dart';
import 'package:doudou/ui/design/doudou_colors.dart';
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
    final c = context.doudouColors;
    final sidebar = SideBarAnimatedLocal(
      initialIndex: homeScreenController.tabIndex.value,
      currentIndexListenable: _tabIndexNotifier,
      onTap: homeScreenController.onSideBarTabSelected,
      minimized: widget.minimized,
      onMinimizeChanged: widget.onMinimizeChanged,
      sideBarColor: c.raisedBackground,
      animatedContainerColor: c.surfaceSelected,
      hoverColor: c.stateHover,
      splashColor: c.statePressed,
      highlightColor: c.stateHover,
      selectedIconColor: c.accentPrimary,
      unselectedIconColor: c.textTertiary,
      unSelectedTextColor: c.textTertiary,
      dividerColor: c.borderSubtle,
      widthSwitch: 800,
      mainLogoImage: 'assets/icons/icon.png',
      appName: 'Doudou',
      useDoudouLogo: true,
      shrinkSidebarLabel: context.l10n.shrinkSidebar,
      sidebarItems: [
        SideBarItemLocal(
          iconSelected: Icons.home,
          iconUnselected: Icons.home_outlined,
          text: context.l10n.home,
        ),
        SideBarItemLocal(
          iconSelected: Icons.search_rounded,
          iconUnselected: Icons.search_outlined,
          text: context.l10n.search,
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
    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: c.borderSubtle),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: sidebar),
          Obx(() => SizedBox(
              height: playerController.currentSong.value != null
                  ? playerController.playerPanelMinHeight.value
                  : 0.0)),
        ],
      ),
    );
  }
}
