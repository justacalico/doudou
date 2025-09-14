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
  bool _isAndroidAuto = false;
  int _selectedAutoSection = 0; // 0: Albums, 1: Playlists, 2: Favorites
  
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
      // Check if we're in Android Auto after the first frame
      _checkIfAndroidAuto();
    });
  }

  void _checkIfAndroidAuto() {
    final size = MediaQuery.of(context).size;
    final aspectRatio = size.width / size.height;
    
    // Android Auto screens are typically landscape and wide (around 2.5:1 to 3:1 ratio)
    // Also check if we're running on Android with specific screen characteristics
    if (aspectRatio > 2.2 && size.width > 800) {
      setState(() {
        _isAndroidAuto = true;
      });
    }
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

  Widget _buildAndroidAutoUI(AppState appState) {
    return Container(
      color: const Color(0xFF000000),
      child: Column(
        children: [
          // Top navigation bar with Albums, Playlists, Favorites
          Container(
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                _buildAutoNavButton('Albums', 0, CupertinoIcons.music_albums),
                const SizedBox(width: 20),
                _buildAutoNavButton('Playlists', 1, CupertinoIcons.music_note_list),
                const SizedBox(width: 20),
                _buildAutoNavButton('Favorites', 2, CupertinoIcons.heart_fill),
                const Spacer(),
              ],
            ),
          ),
          
          // Main content area
          Expanded(
            child: Row(
              children: [
                // Left side - Selected section content
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    child: _buildAutoSectionContent(appState),
                  ),
                ),
                
                // Right side - Currently playing
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    child: _buildCurrentlyPlaying(appState),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoNavButton(String title, int index, IconData icon) {
    final isSelected = _selectedAutoSection == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAutoSection = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected 
            ? CupertinoColors.systemRed 
            : const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
              ? CupertinoColors.systemRed 
              : const Color(0xFF2C2C2E),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? CupertinoColors.white : CupertinoColors.systemGrey2,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? CupertinoColors.white : CupertinoColors.systemGrey2,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoSectionContent(AppState appState) {
    switch (_selectedAutoSection) {
      case 0: // Albums
        return _buildAutoAlbumsSection(appState);
      case 1: // Playlists
        return _buildAutoPlaylistsSection(appState);
      case 2: // Favorites
        return _buildAutoFavoritesSection(appState);
      default:
        return const Center(child: Text('Select a section'));
    }
  }

  Widget _buildAutoAlbumsSection(AppState appState) {
    if (appState.albums.isEmpty) {
      return const Center(
        child: Text(
          'No albums available',
          style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 18),
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: appState.albums.length,
      itemBuilder: (context, index) {
        final album = appState.albums[index];
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(
                      CupertinoIcons.music_albums,
                      size: 40,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  album.name,
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAutoPlaylistsSection(AppState appState) {
    return const Center(
      child: Text(
        'Playlists - Coming Soon',
        style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 18),
      ),
    );
  }

  Widget _buildAutoFavoritesSection(AppState appState) {
    return const Center(
      child: Text(
        'Favorites - Coming Soon',
        style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 18),
      ),
    );
  }

  Widget _buildCurrentlyPlaying(AppState appState) {
    final audioHandler = appState.audioHandler;
    if (audioHandler == null) {
      return const Center(
        child: Text(
          'No audio service available',
          style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 16),
        ),
      );
    }

    return StreamBuilder(
      stream: audioHandler.playerStateStream,
      builder: (context, snapshot) {
        final currentTrack = audioHandler.currentTrack;
        
        if (currentTrack == null) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.music_note,
                    size: 60,
                    color: CupertinoColors.systemGrey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No music playing',
                    style: TextStyle(
                      color: CupertinoColors.systemGrey,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // Album art
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      CupertinoIcons.music_albums,
                      size: 80,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Track info
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Text(
                      currentTrack.name,
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 8),
                    
                    if (currentTrack.artistName != null)
                      Text(
                        currentTrack.artistName!,
                        style: const TextStyle(
                          color: CupertinoColors.systemGrey2,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    
                    const Spacer(),
                    
                    // Control buttons
                    StreamBuilder(
                      stream: audioHandler.playerStateStream,
                      builder: (context, snapshot) {
                        final isPlaying = audioHandler.isPlaying;
                        final isFavorite = appState.favoriteTracks.any((track) => track.id == currentTrack.id);
                        
                        return Column(
                          children: [
                            // Main playback controls
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Previous button
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: audioHandler.hasPrevious == true 
                                    ? () => audioHandler.skipToPrevious()
                                    : null,
                                  child: Icon(
                                    CupertinoIcons.backward_fill,
                                    size: 32,
                                    color: audioHandler.hasPrevious == true 
                                      ? CupertinoColors.white
                                      : CupertinoColors.systemGrey3,
                                  ),
                                ),
                                
                                const SizedBox(width: 20),
                                
                                // Play/pause button
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    if (isPlaying) {
                                      audioHandler.pause();
                                    } else {
                                      audioHandler.play();
                                    }
                                  },
                                  child: Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: CupertinoColors.systemRed,
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: Icon(
                                      isPlaying 
                                        ? CupertinoIcons.pause_fill
                                        : CupertinoIcons.play_fill,
                                      size: 28,
                                      color: CupertinoColors.white,
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(width: 20),
                                
                                // Next button
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: audioHandler.hasNext == true 
                                    ? () => audioHandler.skipToNext()
                                    : null,
                                  child: Icon(
                                    CupertinoIcons.forward_fill,
                                    size: 32,
                                    color: audioHandler.hasNext == true 
                                      ? CupertinoColors.white
                                      : CupertinoColors.systemGrey3,
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Heart (favorite) button
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                appState.toggleFavorite(currentTrack);
                              },
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: isFavorite 
                                    ? CupertinoColors.systemRed.withOpacity(0.2)
                                    : const Color(0xFF2C2C2E),
                                  borderRadius: BorderRadius.circular(25),
                                  border: Border.all(
                                    color: isFavorite 
                                      ? CupertinoColors.systemRed
                                      : const Color(0xFF3C3C3E),
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  isFavorite 
                                    ? CupertinoIcons.heart_fill
                                    : CupertinoIcons.heart,
                                  size: 24,
                                  color: isFavorite 
                                    ? CupertinoColors.systemRed
                                    : CupertinoColors.systemGrey2,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        // Check if Android Auto mode should be used
        if (_isAndroidAuto) {
          return _buildAndroidAutoUI(appState);
        }
        
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
                height: 97, // 65px height + 32px margin (16px top + 16px bottom)
                padding: const EdgeInsets.all(16),
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
