import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:doudou/models/album.dart';
import 'package:doudou/models/artist.dart';
import 'package:doudou/services/constant.dart';

import 'navigator.dart';
import 'player/player.dart';
import 'player/components/mini_player.dart';
import 'player/player_controller.dart';
import 'screens/Album/album_screen.dart';
import 'screens/Artists/artist_screen.dart';
import 'screens/Home/home_screen.dart';
import 'screens/Home/home_screen_controller.dart';
import 'screens/Playlist/playlist_screen.dart';
import 'screens/Search/search_result_screen.dart';
import 'screens/Search/search_screen.dart';
import 'screens/Settings/settings_screen_controller.dart';
import 'shell_controller.dart';
import 'widgets/bottom_nav_bar.dart';
import 'widgets/scroll_to_hide.dart';
import 'widgets/side_nav_bar.dart';
import 'widgets/queue_drawer.dart';
import 'widgets/sliding_up_panel.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _sidebarMinimized = false;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<ShellController>()) {
      Get.put(ShellController(), permanent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerController = Get.find<PlayerController>();
    final settingsController = Get.find<SettingsScreenController>();
    final homeScreenController = Get.find<HomeScreenController>();
    final shellController = Get.find<ShellController>();
    final wasBottomNav = shellController.useBottomNav.value;
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    final isWideScreen = width > 800;
    final useBottomNav = width < kSidebarMinWidth ||
        settingsController.isBottomNavBarEnabled.isTrue;

    if (wasBottomNav != useBottomNav) {
      homeScreenController.remapTabIndexForNavModeChange(
          useBottomNav: useBottomNav);
    }

    shellController.setUseBottomNav(useBottomNav);

    if (useBottomNav) {
      const minHeight = 80.0;
      if (playerController.playerPanelMinHeight.value != minHeight) {
        playerController.playerPanelMinHeight.value = minHeight;
      }
    } else {
      final minHeight = isWideScreen
          ? 105.0 + Get.mediaQuery.padding.bottom
          : 75.0 + Get.mediaQuery.padding.bottom;
      if (playerController.playerPanelMinHeight.value != minHeight) {
        playerController.playerPanelMinHeight.value = minHeight;
      }
    }

    final sidebarMode = settingsController.sidebarMode.value;

    // Auto-collapse sidebar on narrower layouts while still using side navigation.
    final autoMinimizedSidebar = !useBottomNav && width < 800;
    final effectiveSidebarMinimized = switch (sidebarMode) {
      SidebarMode.auto => autoMinimizedSidebar || _sidebarMinimized,
      SidebarMode.collapsed => true,
      SidebarMode.expanded => false,
    };
    final sidebarWidth = effectiveSidebarMinimized ? 84.0 : 260.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (playerController.playerPanelController.isPanelOpen) {
          playerController.playerPanelController.close();
        } else {
          if (ScreenNavigationSetup.canPopContent) {
            ScreenNavigationSetup.popContent();
          } else {
            if (homeScreenController.tabIndex.value != 0) {
              useBottomNav
                  ? homeScreenController.onBottonBarTabSelected(0)
                  : homeScreenController.onSideBarTabSelected(0);
            } else if (playerController.buttonState.value ==
                PlayButtonState.playing) {
              SystemNavigator.pop();
            } else {
              await Get.find<AudioHandler>().customAction("saveSession");
              exit(0);
            }
          }
        }
      },
      child: CallbackShortcuts(
        bindings: {
          LogicalKeySet(LogicalKeyboardKey.space): playerController.playPause
        },
        child: Obx(
          () {
            final useBottomNavObx = width < kSidebarMinWidth ||
                settingsController.isBottomNavBarEnabled.isTrue;
            final hasCurrentSong = playerController.currentSong.value != null;
            return Scaffold(
              key: playerController.homeScaffoldkey,
              extendBody: true,
              drawerScrimColor: Colors.transparent,
              bottomNavigationBar: useBottomNavObx
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasCurrentSong)
                          InkWell(
                            onTap: playerController.playerPanelController.open,
                            child: const MiniPlayer(),
                          ),
                        ScrollToHideWidget(
                          isVisible: playerController.isPanelGTHOpened.isFalse,
                          child: const BottomNavBar(),
                        ),
                      ],
                    )
                  : null,
              endDrawer: GetPlatform.isDesktop || isWideScreen
                  ? const QueueDrawer()
                  : null,
              body: Builder(
                builder: (shellContext) {
                  shellController.setOverlayContext(shellContext);
                  return Obx(
                    () {
                      final useBottomNavBody = width < kSidebarMinWidth ||
                          settingsController.isBottomNavBarEnabled.isTrue;
                      final hasCurrentSongBody =
                          playerController.currentSong.value != null;
                      final panelMinHeight = useBottomNavBody
                          ? 0.0
                          : (hasCurrentSongBody
                              ? playerController.playerPanelMinHeight.value
                              : 0.0);
                      final panelHeader = useBottomNavBody
                          ? null
                          : (hasCurrentSongBody
                              ? (!isWideScreen
                                  ? InkWell(
                                      onTap: playerController
                                          .playerPanelController.open,
                                      child: const MiniPlayer(),
                                    )
                                  : const MiniPlayer())
                              : null);
                      return SlidingUpPanel(
                        onPanelSlide: playerController.panellistener,
                        controller: playerController.playerPanelController,
                        minHeight: panelMinHeight,
                        maxHeight: size.height,
                        isDraggable: !isWideScreen,
                        onSwipeUp: () {
                          playerController.queuePanelController.open();
                        },
                        panel: const Player(),
                        body: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            useBottomNavBody
                                ? const SizedBox.shrink()
                                : AnimatedContainer(
                                    duration: () {
                                      final settings =
                                          Get.find<SettingsScreenController>();
                                      final factor =
                                          settings.animationSpeedFactor;
                                      if (factor == 0) {
                                        return Duration.zero;
                                      }
                                      const baseMs = 500;
                                      final effectiveMs =
                                          (baseMs * factor).round();
                                      return Duration(
                                          milliseconds: effectiveMs);
                                    }(),
                                    curve: Curves.easeOut,
                                    width: sidebarWidth,
                                    child: SideNavBar(
                                      minimized: effectiveSidebarMinimized,
                                      onMinimizeChanged:
                                          sidebarMode == SidebarMode.auto
                                              ? (v) => setState(
                                                  () => _sidebarMinimized = v)
                                              : (_) {},
                                    ),
                                  ),
                            Expanded(
                              child: Navigator(
                                key: Get.nestedKey(
                                    ScreenNavigationSetup.contentId),
                                initialRoute: ScreenNavigationSetup.homeScreen,
                                onGenerateRoute: _contentRouteGenerator,
                              ),
                            ),
                          ],
                        ),
                        header: panelHeader,
                      );
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

Route<dynamic>? _contentRouteGenerator(RouteSettings settings) {
  Get.routing.args = settings.arguments;
  switch (settings.name) {
    case ScreenNavigationSetup.homeScreen:
      return GetPageRoute(page: () => const HomeScreen(), settings: settings);
    case ScreenNavigationSetup.albumScreen:
      final id = (settings.arguments as (Album?, String)).$2;
      return GetPageRoute(
          page: () => AlbumScreen(key: Key(id)), settings: settings);
    case ScreenNavigationSetup.playlistScreen:
      final id = (settings.arguments as List)[1] as String;
      return GetPageRoute(
          page: () => PlaylistScreen(key: Key(id)), settings: settings);
    case ScreenNavigationSetup.searchScreen:
      return GetPageRoute(page: () => const SearchScreen(), settings: settings);
    case ScreenNavigationSetup.searchResultScreen:
      return GetPageRoute(
          page: () => const SearchResultScreen(), settings: settings);
    case ScreenNavigationSetup.artistScreen:
      final args = settings.arguments as List;
      final id = args[0] ? args[1] : (args[1] as Artist).browseId;
      return GetPageRoute(
          page: () => ArtistScreen(key: Key(id)), settings: settings);
    default:
      return null;
  }
}
