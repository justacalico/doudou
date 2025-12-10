import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'dart:ui';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_state.dart';
import '../../../models/jellyfin_models.dart';
import '../../home/home.dart';
import '../../libary/library.dart';
import '../../settings/settings.dart';
import '../../search/search.dart';
import '../../downloads/downloads.dart';
import '../player/mini_player.dart';
import '../../../widgets/isle.dart';
import '../../../widgets/apple_design/apple_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late CupertinoTabController _tabController;
  int _previousIndex = 0;
  bool _isAndroidAuto = false;
  int _selectedAutoSection =
      -1; // -1: Home, 0: Albums, 1: Playlists, 2: Favorites

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
      // Only check for Android Auto on Android platform
      if (Platform.isAndroid) {
        _checkIfAndroidAuto();
      }
    });
  }

  void _checkIfAndroidAuto() {
    final size = MediaQuery.of(context).size;
    final aspectRatio = size.width / size.height;

    if (kDebugMode) {
      print(
        'Screen detection - Width: ${size.width}, Height: ${size.height}, Aspect Ratio: $aspectRatio',
      );
    }

    // Android Auto screens are typically landscape and wide (around 2.5:1 to 3:1 ratio)
    // Also check if we're running on Android with specific screen characteristics
    // Lowered threshold for better detection
    if (aspectRatio > 1.5 && size.width > 600) {
      setState(() {
        _isAndroidAuto = true;
      });
      if (kDebugMode) {
        print('Android Auto mode detected!');
      }

      // Ensure proper data loading for Android Auto with multiple attempts
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final appState = Provider.of<AppState>(context, listen: false);
        
        // Force reload library data for Android Auto to ensure fresh content
        if (appState.isLoggedIn) {
          if (kDebugMode) {
            print('Loading library data for Android Auto...');
          }
          
          try {
            await appState.loadLibraryData();
            
            // If still no data after first load, try again
            if (appState.albums.isEmpty || appState.tracks.isEmpty) {
              if (kDebugMode) {
                print('First load incomplete, retrying...');
              }
              await Future.delayed(const Duration(seconds: 2));
              await appState.loadLibraryData();
            }
            
            if (kDebugMode) {
              print('Android Auto data loaded - Albums: ${appState.albums.length}, Tracks: ${appState.tracks.length}');
            }
          } catch (e) {
            if (kDebugMode) {
              print('Error loading data for Android Auto: $e');
            }
          }
        } else {
          if (kDebugMode) {
            print('User not logged in for Android Auto');
          }
        }
      });
    } else {
      if (kDebugMode) {
        print('Regular mobile mode detected');
      }
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

  Future<void> _refreshAndroidAutoData(AppState appState) async {
    if (kDebugMode) {
      print('Refreshing Android Auto data...');
    }
    
    // Show that refresh is in progress
    setState(() {});
    
    try {
      if (!appState.isLoggedIn) {
        if (kDebugMode) {
          print('Cannot refresh - user not logged in');
        }
        // Try to handle the case where user needs to login
        return;
      }

      await appState.loadLibraryData();
      
      // Update AudioHandler with fresh data for Android Auto MediaBrowser
      final audioHandler = appState.audioHandler;
      if (audioHandler != null) {
        try {
          // Update the media library in audio handler for MediaBrowser
          audioHandler.updateMediaLibrary(
            albums: appState.albums,
            artists: appState.artists,
            tracks: appState.tracks,
            playlists: appState.playlists,
          );
          
          if (kDebugMode) {
            print('Updated AudioHandler MediaBrowser with fresh library data');
          }
        } catch (e) {
          if (kDebugMode) {
            print('Warning: Failed to update AudioHandler MediaBrowser: $e');
          }
          // Don't throw - this is not critical for the UI
        }
      }
      
      // If still no data after load, show debug info
      if (kDebugMode) {
        print('After refresh - Albums: ${appState.albums.length}, Tracks: ${appState.tracks.length}, Artists: ${appState.artists.length}, Playlists: ${appState.playlists.length}');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('Error refreshing Android Auto data: $e');
      }
      
      // In a real app, you might want to show a user-visible error message
      // For Android Auto, we need to be more resilient and not crash
      // The UI will show the "No Content Available" message instead
    }
    
    // Force rebuild to show updated state
    setState(() {});
  }

  Widget _buildTabContent(int index, AppState appState) {
    final l10n = AppLocalizations.of(context);
    Widget content;
    String title;
    bool showNavBar = true;

    switch (index) {
      case 0:
        content = const HomeContent();
        title = l10n.navHome;
        showNavBar = false; // Home has custom header
        break;
      case 1:
        content = const LibraryContent();
        title = l10n.navLibrary;
        showNavBar = false; // Library has custom header
        break;
      case 2:
        content = const DownloadsScreen();
        title = l10n.navDownloads;
        showNavBar = false; // Downloads has custom header
        break;
      case 3:
        content = const SearchScreen();
        title = l10n.navSearch;
        showNavBar = false; // Search has custom header
        break;
      case 4:
        content = const SettingsScreen();
        title = l10n.navSettings;
        showNavBar = false; // Settings has custom header
        break;
      default:
        content = const HomeContent();
        title = l10n.navHome;
        showNavBar = false;
    }

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: showNavBar
          ? CupertinoNavigationBar(
              middle: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: CupertinoColors.white),
                  ),
                  if (appState.isOfflineMode)
                    Text(
                      l10n.offlineMode,
                      style: const TextStyle(
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
            )
          : null,
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
                    Text(
                      l10n.offlineModeDownloadsOnly,
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minSize: 0,
                      child: Text(
                        l10n.retry,
                        style: const TextStyle(
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
            bottom:
                0, // Let content extend to the bottom, overlays will handle spacing
            child: content,
          ),
          // Only show mini player when Dynamic Isle is disabled, not on settings screen (index 4)
          // Also hide on search screen (index 3) when keyboard is open
          if (!appState.useDynamicIsle &&
              index != 4 &&
              !(index == 3 && MediaQuery.of(context).viewInsets.bottom > 0))
            Positioned(
              left: 0,
              right: 0,
              bottom:
                  97, // Position mini player above glassmorphism nav bar (65px + 16px margin + 16px gap)
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
          // Debug indicator
          if (kDebugMode)
            Container(
              padding: const EdgeInsets.all(8),
              color: CupertinoColors.systemGreen,
              child: Text(
                'ANDROID AUTO MODE - Albums: ${appState.albums.length}, Tracks: ${appState.tracks.length}, Loading: ${appState.isLoading}',
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          // Connection status indicator for Android Auto
          if (!appState.isLoading && 
              appState.albums.isEmpty && 
              appState.tracks.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CupertinoColors.systemOrange, width: 2),
              ),
              child: const Row(
                children: [
                  Icon(
                    CupertinoIcons.wifi_exclamationmark,
                    color: CupertinoColors.systemOrange,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No Content Available',
                          style: TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Please ensure you are logged in and your Jellyfin server is accessible. Tap Refresh to try again.',
                          style: TextStyle(
                            color: CupertinoColors.systemGrey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Top navigation bar with Home, Albums, Playlists, Favorites
          Container(
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                _buildAutoNavButton('Home', -1, CupertinoIcons.house_fill),
                const SizedBox(width: 20),
                _buildAutoNavButton('Albums', 0, CupertinoIcons.music_albums),
                const SizedBox(width: 20),
                _buildAutoNavButton(
                  'Playlists',
                  1,
                  CupertinoIcons.music_note_list,
                ),
                const SizedBox(width: 20),
                _buildAutoNavButton('Favorites', 2, CupertinoIcons.heart_fill),
                const Spacer(),
                // Add refresh button for Android Auto
                GestureDetector(
                  onTap: () => _refreshAndroidAutoData(appState),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.refresh,
                          color: CupertinoColors.systemBlue,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Refresh',
                          style: TextStyle(
                            color: CupertinoColors.systemBlue,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
              color: isSelected
                  ? CupertinoColors.white
                  : CupertinoColors.systemGrey2,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? CupertinoColors.white
                    : CupertinoColors.systemGrey2,
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
      case -1: // Home
        return _buildAutoHomeSection(appState);
      case 0: // Albums
        return _buildAutoAlbumsSection(appState);
      case 1: // Playlists
        return _buildAutoPlaylistsSection(appState);
      case 2: // Favorites
        return _buildAutoFavoritesSection(appState);
      default:
        return _buildAutoHomeSection(appState);
    }
  }

  Widget _buildAutoHomeSection(AppState appState) {
    // Check if we need to show loading state
    if (appState.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CupertinoActivityIndicator(
              radius: 20,
              color: CupertinoColors.systemRed,
            ),
            SizedBox(height: 16),
            Text(
              'Loading your music library...',
              style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 18),
            ),
          ],
        ),
      );
    }

    // Check if user is not logged in
    if (!appState.isLoggedIn) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.person_circle,
              size: 60,
              color: CupertinoColors.systemGrey,
            ),
            SizedBox(height: 16),
            Text(
              'Not connected to server',
              style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Please check your connection settings',
              style: TextStyle(
                color: CupertinoColors.systemGrey2,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome section
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome to Doudou',
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  appState.tracks.isNotEmpty 
                    ? 'Your music, everywhere you go - ${appState.tracks.length} tracks available'
                    : 'Your music, everywhere you go',
                  style: const TextStyle(
                    color: CupertinoColors.systemGrey2,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 24),

                // Quick action buttons - only show if we have tracks
                if (appState.tracks.isNotEmpty)
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickActionButton(
                          'Shuffle All',
                          CupertinoIcons.shuffle,
                          () async {
                            await appState.shuffleAllTracks();
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildQuickActionButton(
                          'Favorites',
                          CupertinoIcons.heart_fill,
                          () {
                            setState(() {
                              _selectedAutoSection = 2; // Go to favorites
                            });
                          },
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Show message if no content is available
          if (appState.albums.isEmpty && appState.tracks.isEmpty && !appState.isLoading)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2C2C2E), width: 1),
                ),
                child: Column(
                  children: [
                    const Icon(
                      CupertinoIcons.music_note,
                      size: 48,
                      color: CupertinoColors.systemGrey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Music Found',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Make sure your Jellyfin server has music content and the connection is working properly.',
                      style: TextStyle(
                        color: CupertinoColors.systemGrey2,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => _refreshAndroidAutoData(appState),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Try Again',
                          style: TextStyle(
                            color: CupertinoColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Recent albums section - only show if we have albums
          if (appState.albums.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Albums (${appState.albums.length} total)',
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Album grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.8,
                        ),
                    itemCount: appState.albums.length > 6
                        ? 6
                        : appState.albums.length,
                    itemBuilder: (context, index) {
                      final album = appState.albums[index];
                      return GestureDetector(
                        onTap: () => _playAlbum(appState, album),
                        child: Container(
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
                                  child: album.imageUrl != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.network(
                                            appState.jellyfinService
                                                .getImageUrl(
                                                  album.imageUrl!,
                                                  width: 150,
                                                  height: 150,
                                                ),
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                                  return const Center(
                                                    child: Icon(
                                                      CupertinoIcons
                                                          .music_albums,
                                                      size: 40,
                                                      color: CupertinoColors
                                                          .systemGrey,
                                                    ),
                                                  );
                                                },
                                          ),
                                        )
                                      : const Center(
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
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2C2C2E), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: CupertinoColors.systemRed, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoAlbumsSection(AppState appState) {
    // If still loading library data, show loading indicator
    if (appState.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CupertinoActivityIndicator(
              radius: 20,
              color: CupertinoColors.systemRed,
            ),
            SizedBox(height: 16),
            Text(
              'Loading albums...',
              style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 18),
            ),
          ],
        ),
      );
    }

    // If no albums loaded yet, trigger refresh
    if (appState.albums.isEmpty && !appState.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (appState.isLoggedIn) {
          appState.loadLibraryData();
        }
      });

      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CupertinoActivityIndicator(
              radius: 20,
              color: CupertinoColors.systemRed,
            ),
            SizedBox(height: 16),
            Text(
              'Loading albums...',
              style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 18),
            ),
          ],
        ),
      );
    }

    if (appState.albums.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.music_albums,
              size: 60,
              color: CupertinoColors.systemGrey,
            ),
            SizedBox(height: 16),
            Text(
              'No albums available',
              style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 18),
            ),
          ],
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
        return GestureDetector(
          onTap: () => _playAlbum(appState, album),
          child: Container(
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
                    child: album.imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              appState.getImageUrl(
                                album.imageUrl!,
                                width: 200,
                                height: 200,
                              ),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(
                                    CupertinoIcons.music_albums,
                                    size: 40,
                                    color: CupertinoColors.systemGrey,
                                  ),
                                );
                              },
                            ),
                          )
                        : const Center(
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
                  child: Column(
                    children: [
                      Text(
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
                      if (album.artistName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          album.artistName!,
                          style: const TextStyle(
                            color: CupertinoColors.systemGrey2,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _playAlbum(AppState appState, Album album) async {
    if (kDebugMode) {
      print('Android Auto: Starting album playback - ${album.name}');
    }
    
    try {
      final tracks = await appState.getAlbumTracks(album.id);
      if (tracks.isNotEmpty) {
        if (kDebugMode) {
          print('Android Auto: Playing album with ${tracks.length} tracks');
        }
        await appState.playPlaylist(tracks, 0);
        
        if (kDebugMode) {
          print('Android Auto: Album playback initiated successfully');
        }
      } else {
        if (kDebugMode) {
          print('Android Auto: Album ${album.name} has no tracks');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Android Auto: Error playing album ${album.name}: $e');
      }
      // Don't throw - prevent crashes in Android Auto
      // The UI will continue to work even if one album fails
    }
  }

  Widget _buildAutoPlaylistsSection(AppState appState) {
    // If still loading library data, show loading indicator
    if (appState.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CupertinoActivityIndicator(
              radius: 20,
              color: CupertinoColors.systemRed,
            ),
            SizedBox(height: 16),
            Text(
              'Loading playlists...',
              style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 18),
            ),
          ],
        ),
      );
    }

    // If no playlists loaded yet, trigger refresh
    if (appState.playlists.isEmpty && !appState.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (appState.isLoggedIn) {
          appState.loadLibraryData();
        }
      });

      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CupertinoActivityIndicator(
              radius: 20,
              color: CupertinoColors.systemRed,
            ),
            SizedBox(height: 16),
            Text(
              'Loading playlists...',
              style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 18),
            ),
          ],
        ),
      );
    }

    if (appState.playlists.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.music_note_list,
              size: 60,
              color: CupertinoColors.systemGrey,
            ),
            SizedBox(height: 16),
            Text(
              'No playlists available',
              style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Create playlists to organize your music',
              style: TextStyle(
                color: CupertinoColors.systemGrey2,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.9,
      ),
      itemCount: appState.playlists.length,
      itemBuilder: (context, index) {
        final playlist = appState.playlists[index];
        return GestureDetector(
          onTap: () => _playPlaylist(appState, playlist),
          child: Container(
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
                    child: playlist.imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              appState.getImageUrl(
                                playlist.imageUrl!,
                                width: 150,
                                height: 150,
                              ),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(
                                    CupertinoIcons.music_note_list,
                                    size: 40,
                                    color: CupertinoColors.systemGrey,
                                  ),
                                );
                              },
                            ),
                          )
                        : const Center(
                            child: Icon(
                              CupertinoIcons.music_note_list,
                              size: 40,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      Text(
                        playlist.name,
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${playlist.trackCount} ${playlist.trackCount == 1 ? 'song' : 'songs'}',
                        style: const TextStyle(
                          color: CupertinoColors.systemGrey2,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _playPlaylist(AppState appState, Playlist playlist) async {
    try {
      final tracks = await appState.getPlaylistTracks(playlist.id);
      if (tracks.isNotEmpty) {
        await appState.playPlaylist(tracks, 0);
      }
    } catch (e) {
      // Handle error silently for now
    }
  }

  Widget _buildAutoFavoritesSection(AppState appState) {
    final favoriteTracks = appState.favoriteTracks;

    // If still loading library data, show loading indicator
    if (appState.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CupertinoActivityIndicator(
              radius: 20,
              color: CupertinoColors.systemRed,
            ),
            SizedBox(height: 16),
            Text(
              'Loading your music library...',
              style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 18),
            ),
          ],
        ),
      );
    }

    // If no tracks are loaded yet but not in loading state, trigger a refresh
    if (appState.tracks.isEmpty && !appState.isLoading) {
      // Trigger library data load
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (appState.isLoggedIn) {
          appState.loadLibraryData();
        }
      });

      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CupertinoActivityIndicator(
              radius: 20,
              color: CupertinoColors.systemRed,
            ),
            SizedBox(height: 16),
            Text(
              'Loading your music library...',
              style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 18),
            ),
          ],
        ),
      );
    }

    // If tracks are loaded but no favorites
    if (favoriteTracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.heart,
              size: 60,
              color: CupertinoColors.systemGrey,
            ),
            const SizedBox(height: 16),
            const Text(
              'No favorite songs',
              style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the heart icon on songs to add them here',
              style: TextStyle(
                color: CupertinoColors.systemGrey2,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Add button to navigate to home or albums to find music to favorite
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedAutoSection = -1; // Go to home
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemRed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Browse Music',
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header with play controls
        Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Favorites info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: CupertinoColors.systemRed.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  CupertinoIcons.heart_fill,
                  color: CupertinoColors.systemRed,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Favorite Songs',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: CupertinoColors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${favoriteTracks.length} song${favoriteTracks.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: CupertinoColors.systemGrey2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Play all button
              GestureDetector(
                onTap: () => _playFavorites(appState, false),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemRed,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.play_fill,
                        color: CupertinoColors.white,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Play All',
                        style: TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Shuffle button
              GestureDetector(
                onTap: () => _playFavorites(appState, true),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF2C2C2E),
                      width: 2,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.shuffle,
                        color: CupertinoColors.white,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Shuffle',
                        style: TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Favorites list
        Expanded(
          child: ListView.builder(
            itemCount: favoriteTracks.length,
            itemBuilder: (context, index) {
              final track = favoriteTracks[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: GestureDetector(
                  onTap: () => _playFavoriteTrack(appState, track, index),
                  child: Row(
                    children: [
                      // Album artwork
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2C2E),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: track.imageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  appState.getImageUrl(
                                    track.imageUrl!,
                                    width: 100,
                                    height: 100,
                                  ),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(
                                      child: Icon(
                                        CupertinoIcons.music_note,
                                        size: 20,
                                        color: CupertinoColors.systemGrey,
                                      ),
                                    );
                                  },
                                ),
                              )
                            : const Center(
                                child: Icon(
                                  CupertinoIcons.music_note,
                                  size: 20,
                                  color: CupertinoColors.systemGrey,
                                ),
                              ),
                      ),

                      const SizedBox(width: 16),

                      // Track info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.name,
                              style: const TextStyle(
                                color: CupertinoColors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            if (track.artistName != null)
                              Text(
                                track.artistName!,
                                style: const TextStyle(
                                  color: CupertinoColors.systemGrey2,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),

                      // Heart icon
                      const Icon(
                        CupertinoIcons.heart_fill,
                        color: CupertinoColors.systemRed,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _playFavorites(AppState appState, bool shuffle) async {
    final favoriteTracks = appState.favoriteTracks;
    if (favoriteTracks.isNotEmpty) {
      if (shuffle) {
        await appState.shuffleFavoriteTracks();
      } else {
        await appState.playPlaylist(favoriteTracks, 0);
      }
    }
  }

  void _playFavoriteTrack(AppState appState, Track track, int index) async {
    final favoriteTracks = appState.favoriteTracks;
    await appState.playPlaylist(favoriteTracks, index);
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

    return StreamBuilder<PlaybackState>(
      stream: appState.playbackState,
      builder: (context, playbackStateSnapshot) {
        return StreamBuilder<MediaItem?>(
          stream: appState.mediaItem,
          builder: (context, mediaItemSnapshot) {
            final currentTrack = audioHandler?.currentTrack;
            final isPlaying = playbackStateSnapshot.data?.playing == true;

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

            final isFavorite = appState.favoriteTracks.any(
              (track) => track.id == currentTrack.id,
            );

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
                      child: currentTrack.imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                appState.getImageUrl(
                                  currentTrack.imageUrl!,
                                  width: 300,
                                  height: 300,
                                ),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(
                                      CupertinoIcons.music_albums,
                                      size: 80,
                                      color: CupertinoColors.systemGrey,
                                    ),
                                  );
                                },
                              ),
                            )
                          : const Center(
                              child: Icon(
                                CupertinoIcons.music_albums,
                                size: 80,
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Track info and controls
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
                        Column(
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
                                  onPressed: () async {
                                    if (isPlaying) {
                                      await audioHandler.pause();
                                    } else {
                                      await audioHandler.play();
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
                                      ? CupertinoColors.systemRed.withOpacity(
                                          0.2,
                                        )
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
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
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
          // For Android Auto, we want to be extra responsive to state changes
          return StreamBuilder<PlaybackState>(
            stream: appState.audioHandler?.playbackState,
            builder: (context, playbackSnapshot) {
              return _buildAndroidAutoUI(appState);
            },
          );
        }

        // When offline mode changes, update the tab to show downloads
        if (appState.isOfflineMode && _tabController.index != 2) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _tabController.index = 2;
            _previousIndex = 2; // Update tracking for double-tap detection
          });
        }

        // Always use mobile layout with bottom navigation
        // Desktop layout is handled by the responsive app switcher in main.dart
        // which loads DesktopLayout instead of HomeScreen for large screens
        return _buildMobileLayout(appState);
      },
    );
  }

  Widget _buildMobileLayout(AppState appState) {
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

        // Dynamic Isle - only show on mobile and when enabled in settings
        if (appState.useDynamicIsle)
          const DynamicIsle(),

        // Apple-style glassmorphism tab bar positioned at the bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.only(
              left: AppleDesignSystem.spacing16,
              right: AppleDesignSystem.spacing16,
              bottom: MediaQuery.of(context).padding.bottom + AppleDesignSystem.spacing8,
              top: AppleDesignSystem.spacing8,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppleDesignSystem.radiusLarge),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: AppleDesignSystem.blurRegular,
                  sigmaY: AppleDesignSystem.blurRegular,
                ),
                child: Container(
                  height: 65,
                  decoration: BoxDecoration(
                    // Apple glassmorphism effect
                    color: AppleColors.glassDark,
                    borderRadius: BorderRadius.circular(AppleDesignSystem.radiusLarge),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 0.5,
                    ),
                    // Enhanced shadow for floating effect
                    boxShadow: AppleDesignSystem.shadowLarge(Colors.black),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildAppleTabBarItem(0, CupertinoIcons.house_fill, appState),
                      _buildAppleTabBarItem(1, CupertinoIcons.music_note_list, appState),
                      _buildAppleTabBarItem(2, CupertinoIcons.arrow_down_circle, appState),
                      _buildAppleTabBarItem(3, CupertinoIcons.search, appState),
                      _buildAppleTabBarItem(4, CupertinoIcons.settings, appState),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppleTabBarItem(int index, IconData icon, AppState appState) {
    final isActive = _tabController.index == index;
    final primaryColor = CupertinoColors.systemPurple;

    return Expanded(
      child: GestureDetector(
        onTap: () {
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
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppleDesignSystem.durationFast,
          curve: AppleDesignSystem.springCurve,
          height: 65,
          alignment: Alignment.center,
          child: AnimatedScale(
            scale: isActive ? 1.0 : 0.9,
            duration: AppleDesignSystem.durationFast,
            curve: AppleDesignSystem.springCurve,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: isActive 
                      ? primaryColor 
                      : AppleColors.labelSecondaryDark,
                ),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: AppleDesignSystem.durationFast,
                  width: isActive ? 5 : 0,
                  height: 5,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
