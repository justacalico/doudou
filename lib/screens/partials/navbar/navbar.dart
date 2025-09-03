import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
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
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CupertinoTabScaffold(
          tabBar: CupertinoTabBar(
            backgroundColor: const Color(0x00000000), // Fully transparent
            activeColor: CupertinoColors.systemRed, // Red for active tab
            inactiveColor: CupertinoColors.systemGrey2,
            border: null, // Remove default border
            items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house_fill),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.music_note_list),
            label: 'Library',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.arrow_down_circle),
            label: 'Downloads',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.settings),
            label: 'Settings',
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
        
        return Consumer<AppState>(
          builder: (context, appState, child) {
            return CupertinoPageScaffold(
              backgroundColor: const Color(0xFF000000), // Dark background
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
                  // Main content with offset for offline banner
                  Positioned.fill(
                    top: appState.isOfflineMode ? 40 : 0,
                    child: content,
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: MiniPlayer(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
