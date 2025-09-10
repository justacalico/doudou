import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_state.dart';
import '../../home/home.dart';
import '../../libary/library.dart';
import '../../settings/settings.dart';
import '../../search/search.dart';
import '../../downloads/downloads.dart';
import '../player/mini_player.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late CupertinoTabController _tabController;
  int _previousIndex = 0;
  
  @override
  void initState() {
    super.initState();
    _tabController = CupertinoTabController();
    
    // Listen to tab changes to detect double-taps
    _tabController.addListener(_handleTabChange);
    
    // Check after a delay if we should navigate to downloads (if in offline mode)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppState>(context, listen: false);
      if (appState.isOfflineMode) {
        // Navigate to downloads tab (index 2)
        _tabController.index = 2;
        _previousIndex = 2;
      }
    });
  }
  
  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    final currentIndex = _tabController.index;
    
    // If user tapped the same tab twice, reload/refresh that page
    if (currentIndex == _previousIndex) {
      _reloadCurrentTab(currentIndex);
    }
    
    _previousIndex = currentIndex;
  }

  void _reloadCurrentTab(int index) {
    final appState = Provider.of<AppState>(context, listen: false);
    
    switch (index) {
      case 0: // Home
        // Refresh home data and scroll to top
        appState.loadLibraryData();
        break;
      case 1: // Library
        // Refresh library data
        appState.loadLibraryData();
        break;
      case 2: // Downloads
        // Refresh download data - just trigger a rebuild since downloads update automatically
        break;
      case 3: // Search
        // Clear search and refresh
        // Search page will handle its own refresh internally
        break;
      case 4: // Settings
        // Refresh settings data (cache size, etc.)
        // Settings will refresh its own data
        break;
    }
    
    // Force rebuild by triggering a setState
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        // When offline mode changes, update the tab to show downloads
        if (appState.isOfflineMode && _tabController.index != 2) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _tabController.index = 2;
            _previousIndex = 2; // Update tracking for double-tap detection
          });
        }
        
        return Stack(
          children: [
            CupertinoTabScaffold(
              controller: _tabController,
              tabBar: CupertinoTabBar(
                backgroundColor: const Color(0xFF000000).withOpacity(0.95),
                activeColor: CupertinoColors.systemRed, // Red for active tab
                inactiveColor: CupertinoColors.systemGrey2,
                border: Border(
                  top: BorderSide(
                    color: CupertinoColors.white.withOpacity(0.2),
                    width: 0.5,
                  ),
                ),
                iconSize: 26, // Slightly smaller for better centering
                height: 65, // Slightly taller for better vertical centering
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.house_fill),
                    label: '', // Empty label to hide text
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.music_note_list),
                    label: '', // Empty label to hide text
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.arrow_down_circle),
                    label: '', // Empty label to hide text
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.search),
                    label: '', // Empty label to hide text
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.settings),
                    label: '', // Empty label to hide text
                  ),
                ],
              ),
              tabBuilder: (context, index) {
                Widget content;
                String title;
                bool showNavBar = true;
                
                switch (index) {
                  case 0:
                    content = const HomeContent();
                    title = 'Home';
                    showNavBar = false; // Home has custom header
                    break;
                  case 1:
                    content = const LibraryContent();
                    title = 'Library';
                    showNavBar = false; // Library has custom header
                    break;
                  case 2:
                    content = const DownloadsScreen();
                    title = 'Downloads';
                    showNavBar = false; // Downloads has custom header
                    break;
                  case 3:
                    content = const SearchScreen();
                    title = 'Search';
                    showNavBar = false; // Search has custom header
                    break;
                  case 4:
                    content = const SettingsScreen();
                    title = 'Settings';
                    showNavBar = false; // Settings has custom header
                    break;
                  default:
                    content = const HomeContent();
                    title = 'Home';
                    showNavBar = false;
                }
                
                return CupertinoPageScaffold(
                  backgroundColor: CupertinoColors.black, // Use CupertinoColors.black instead
                  navigationBar: showNavBar ? CupertinoNavigationBar(
                    middle: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title, style: const TextStyle(color: CupertinoColors.white)),
                        if (appState.isOfflineMode)
                          const Text(
                            'Offline Mode',
                            style: TextStyle(
                              color: CupertinoColors.systemOrange,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    backgroundColor: const Color(0xFF000000), // True black for OLED
                    border: null,
                    trailing: appState.isOfflineMode 
                      ? const Icon(
                          CupertinoIcons.wifi_slash,
                          color: CupertinoColors.systemOrange,
                          size: 20,
                        )
                      : null,
                  ) : null,
                  child: Stack(
                    children: [
                      // Offline banner
                      if (appState.isOfflineMode)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            color: CupertinoColors.systemOrange,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  CupertinoIcons.wifi_slash,
                                  color: CupertinoColors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Offline Mode - Downloads Only',
                                  style: TextStyle(
                                    color: CupertinoColors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  minSize: 0,
                                  child: const Text(
                                    'Retry',
                                    style: TextStyle(
                                      color: CupertinoColors.white,
                                      fontSize: 14,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                  onPressed: () => appState.checkConnectivity(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Main content with offset for offline banner and bottom padding for mini player + nav bar
                      Positioned.fill(
                        top: appState.isOfflineMode ? 40 : 0,
                        bottom: index == 4 ? 0 : 70, // Settings: no bottom padding, others: mini player height (70)
                        child: content,
                      ),
                      // Only show mini player when not on settings screen (index 4)
                      if (index != 4)
                        const Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0, // Position mini player at the very bottom
                          child: MiniPlayer(),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
