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

  Widget _buildTabContent(int index, AppState appState) {
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
      backgroundColor: CupertinoColors.black,
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
        backgroundColor: const Color(0xFF000000),
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
          // Main content with offset for offline banner only - no bottom padding
          Positioned.fill(
            top: appState.isOfflineMode ? 40 : 0,
            bottom: 0, // Let content extend to the bottom, overlays will handle spacing
            child: content,
          ),
          // Only show mini player when not on settings screen (index 4) - positioned as overlay
          if (index != 4)
            Positioned(
              left: 0,
              right: 0,
              bottom: 97, // Position mini player above glassmorphism nav bar (65px + 16px margin + 16px gap)
              child: const MiniPlayer(),
            ),
        ],
      ),
    );
  }

  Widget _buildTabBarItem(int index, IconData icon, AppState appState) {
    final isActive = _tabController.index == index;
    
    return Expanded(
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          setState(() {
            if (_tabController.index == index) {
              // Double tap - reload tab
              _reloadCurrentTab(index);
            } else {
              _tabController.index = index;
              _previousIndex = index;
            }
          });
        },
        child: Container(
          height: 65,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 26,
            color: isActive 
                ? CupertinoColors.systemRed
                : CupertinoColors.systemGrey2,
          ),
        ),
      ),
    );
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
            // Main content without tab scaffold
            IndexedStack(
              index: _tabController.index,
              children: [
                _buildTabContent(0, appState), // Home
                _buildTabContent(1, appState), // Library
                _buildTabContent(2, appState), // Downloads
                _buildTabContent(3, appState), // Search
                _buildTabContent(4, appState), // Settings
              ],
            ),
            
            // Custom glassmorphism tab bar positioned at the bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 65,
                margin: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        // Glassmorphism effect
                        color: const Color(0xFF000000).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFFFFFFF).withOpacity(0.2),
                          width: 1,
                        ),
                        // Enhanced shadow for floating effect
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x40000000),
                            offset: Offset(0, 8),
                            blurRadius: 16,
                          ),
                          BoxShadow(
                            color: Color(0x20000000),
                            offset: Offset(0, 4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildTabBarItem(0, CupertinoIcons.house_fill, appState),
                          _buildTabBarItem(1, CupertinoIcons.music_note_list, appState),
                          _buildTabBarItem(2, CupertinoIcons.arrow_down_circle, appState),
                          _buildTabBarItem(3, CupertinoIcons.search, appState),
                          _buildTabBarItem(4, CupertinoIcons.settings, appState),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
