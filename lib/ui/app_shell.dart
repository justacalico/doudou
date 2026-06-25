import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:doudou/models/album.dart';
import 'package:doudou/models/artist.dart';
import 'package:doudou/services/constant.dart';
import 'package:doudou/ui/constants/doudou_design.dart';
import 'package:doudou/ui/design/doudou_layout.dart';

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
  bool? _lastUseBottomNav;
  double? _lastMinPanelHeight;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<ShellController>()) {
      Get.put(ShellController(), permanent: true);
    }
  }

  Future<bool> _tryPopNestedContentRoute() async {
    final nestedNav =
        Get.nestedKey(ScreenNavigationSetup.contentId)?.currentState;
    if (nestedNav == null || !nestedNav.canPop()) return false;
    return nestedNav.maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final playerController = Get.find<PlayerController>();
    final settingsController = Get.find<SettingsScreenController>();
    final homeScreenController = Get.find<HomeScreenController>();
    final shellController = Get.find<ShellController>();
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    final isWideScreen = width > 800;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (playerController.playerPanelController.isPanelOpen) {
          playerController.playerPanelController.close();
        } else {
          if (await _tryPopNestedContentRoute()) {
            return;
          }
          if (ScreenNavigationSetup.canPopContent) {
            ScreenNavigationSetup.popContent();
          } else {
            if (homeScreenController.tabIndex.value != 0) {
              shellController.useBottomNav.value
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
            final isBottomNavEnabled =
                settingsController.isBottomNavBarEnabled.value;
            final sidebarMode = settingsController.sidebarMode.value;
            final layout = DoudouLayout.of(context);
            // TV always uses side navigation — ignore bottom nav setting
            final useBottomNav = !layout.isTV &&
                (layout.useBottomNav ||
                    isBottomNavEnabled ||
                    width < kSidebarMinWidth);

            final desiredMinHeight = useBottomNav
                ? 80.0
                : (isWideScreen
                    ? 105.0 + Get.mediaQuery.padding.bottom
                    : 75.0 + Get.mediaQuery.padding.bottom);

            if (_lastUseBottomNav != useBottomNav ||
                _lastMinPanelHeight != desiredMinHeight) {
              _lastUseBottomNav = useBottomNav;
              _lastMinPanelHeight = desiredMinHeight;
              if (shellController.useBottomNav.value != useBottomNav) {
                homeScreenController.remapTabIndexForNavModeChange(
                    useBottomNav: useBottomNav);
                shellController.setUseBottomNav(useBottomNav);
              }
              if (playerController.playerPanelMinHeight.value !=
                  desiredMinHeight) {
                playerController.playerPanelMinHeight.value = desiredMinHeight;
              }
            }

            // Auto-collapse sidebar on narrower layouts while still using side navigation.
            // TV always gets full-width sidebar — no minimize button
            final autoMinimizedSidebar = !useBottomNav && width < 800 && !layout.isTV;
            final effectiveSidebarMinimized = switch (sidebarMode) {
              SidebarMode.auto => autoMinimizedSidebar || _sidebarMinimized,
              SidebarMode.collapsed => !layout.isTV,  // TV ignores collapsed mode
              SidebarMode.expanded => false,
            };
            final sidebarWidth = effectiveSidebarMinimized ? 84.0 : 260.0;

            return Scaffold(
              key: playerController.homeScaffoldkey,
              drawerScrimColor: Colors.transparent,
              bottomNavigationBar: useBottomNav
                  ? const BottomNavBar()
                  : null,
              endDrawer: GetPlatform.isDesktop || isWideScreen || layout.isTV
                  ? const QueueDrawer()
                  : null,
              body: Builder(
                builder: (shellContext) {
                  if (shellController.overlayContext != shellContext) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      shellController.setOverlayContext(shellContext);
                    });
                  }

                  final chrome = _ShellChrome(
                    useBottomNav: useBottomNav,
                    sidebarWidth: sidebarWidth,
                    isWideScreen: isWideScreen,
                    effectiveSidebarMinimized: effectiveSidebarMinimized,
                    sidebarMode: sidebarMode,
                    onSidebarMinimizeChanged: (v) =>
                        setState(() => _sidebarMinimized = v),
                  );

                  return Obx(() {
                    final hasCurrentSong =
                        playerController.currentSong.value != null;
                    final panelMinHeight = useBottomNav
                        ? 0.0
                        : (hasCurrentSong
                            ? playerController.playerPanelMinHeight.value
                            : 0.0);
                    final panelHeader = useBottomNav
                        ? null
                        : (hasCurrentSong
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
                      // Disable drag on TV — no touchscreen, D-pad only
                      isDraggable: !isWideScreen && !(layout.isTV),
                      onSwipeUp: () {
                        playerController.queuePanelController.open();
                      },
                      panel: const Player(),
                      body: chrome,
                      header: panelHeader,
                    );
                  });
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ShellChrome extends StatelessWidget {
  const _ShellChrome({
    required this.useBottomNav,
    required this.sidebarWidth,
    required this.isWideScreen,
    required this.effectiveSidebarMinimized,
    required this.sidebarMode,
    required this.onSidebarMinimizeChanged,
  });

  final bool useBottomNav;
  final double sidebarWidth;
  final bool isWideScreen;
  final bool effectiveSidebarMinimized;
  final SidebarMode sidebarMode;
  final ValueChanged<bool> onSidebarMinimizeChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        useBottomNav
            ? const SizedBox.shrink()
            : AnimatedContainer(
                duration: () {
                  final settings = Get.find<SettingsScreenController>();
                  final factor = settings.animationSpeedFactor;
                  if (factor == 0) return Duration.zero;
                  const baseMs = 240;
                  return Duration(milliseconds: (baseMs * factor).round());
                }(),
                curve: Curves.easeOutCubic,
                width: sidebarWidth,
                child: FocusTraversalGroup(
                  child: SideNavBar(
                    minimized: effectiveSidebarMinimized,
                    onMinimizeChanged: sidebarMode == SidebarMode.auto
                        ? onSidebarMinimizeChanged
                        : (_) {},
                  ),
                ),
              ),
        Expanded(
          child: FocusTraversalGroup(
            child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  kDoudouZinc900.withValues(alpha: 0.45),
                  kDoudouBackground,
                ],
              ),
            ),
            child: Focus(
              autofocus: false,
              child: Navigator(
                key: Get.nestedKey(ScreenNavigationSetup.contentId),
                observers: [ScreenNavigationSetup.contentNavigatorObserver],
                initialRoute: ScreenNavigationSetup.homeScreen,
                onGenerateRoute: _contentRouteGenerator,
              ),
            ),
          ),
          ),
        ),
      ],
    );
  }
}

Route<dynamic>? _contentRouteGenerator(RouteSettings settings) {
  Get.routing.args = settings.arguments;
  switch (settings.name) {
    case ScreenNavigationSetup.homeScreen:
      return GetPageRoute(page: () => const HomeScreen(), settings: settings, transition: Transition.noTransition);
    case ScreenNavigationSetup.albumScreen:
      final id = (settings.arguments as (Album?, String)).$2;
      return GetPageRoute(
          page: () => AlbumScreen(key: Key(id)), settings: settings, transition: Transition.noTransition);
    case ScreenNavigationSetup.playlistScreen:
      final id = (settings.arguments as List)[1] as String;
      return GetPageRoute(
          page: () => PlaylistScreen(key: Key(id)), settings: settings, transition: Transition.noTransition);
    case ScreenNavigationSetup.searchScreen:
      return GetPageRoute(page: () => const SearchScreen(), settings: settings, transition: Transition.noTransition);
    case ScreenNavigationSetup.searchResultScreen:
      final query = (settings.arguments as String?) ?? '';
      return GetPageRoute(
          page: () => SearchResultScreen(
                key: ValueKey(
                    'search_result_${query}_${DateTime.now().microsecondsSinceEpoch}'),
              ),
          settings: settings,
          transition: Transition.noTransition);
    case ScreenNavigationSetup.artistScreen:
      final args = settings.arguments as List;
      final id = args[0] ? args[1] : (args[1] as Artist).browseId;
      return GetPageRoute(
          page: () => ArtistScreen(key: Key(id)), settings: settings, transition: Transition.noTransition);
    default:
      return null;
  }
}
