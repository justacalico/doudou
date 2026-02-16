import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../providers/app_state.dart';
import '../../../../models/jellyfin_models.dart';
import '../../../../services/base_service.dart';
import '../../home/home.dart';
import '../../libary/library.dart';
import '../../settings/settings.dart';
import '../../search/search.dart';
import '../../downloads/downloads.dart';
import '../player/mini_player.dart';
import '../tracks/track_list_item.dart';
import '../../widgets/isle.dart';
import '../../widgets/apple_design/apple_theme.dart';
import '../../widgets/apple_design/liquid_glass.dart';

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

  Future<void> _checkIfAndroidAuto() async {
    final size = MediaQuery.of(context).size;
    final aspectRatio = size.width / size.height;

    bool isQuestDevice = false;
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final manufacturer = androidInfo.manufacturer.toLowerCase();
      final model = androidInfo.model.toLowerCase();
      final brand = androidInfo.brand.toLowerCase();

      isQuestDevice =
          manufacturer.contains('oculus') ||
          manufacturer.contains('meta') ||
          brand.contains('oculus') ||
          brand.contains('meta') ||
          model.contains('quest') ||
          model.contains('pacific') ||
          model.contains('hollywood') ||
          model.contains('eureka');
    } catch (e) {
      // Ignore device info errors
    }

    if (isQuestDevice) return;

    if (aspectRatio > 1.5 && size.width > 600) {
      setState(() {
        _isAndroidAuto = true;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final appState = Provider.of<AppState>(context, listen: false);
        if (appState.isLoggedIn) {
          try {
            await appState.loadLibraryData();
            if (appState.albums.isEmpty || appState.tracks.isEmpty) {
              await Future.delayed(const Duration(seconds: 2));
              await appState.loadLibraryData();
            }
          } catch (e) {
            // Ignore loading errors
          }
        }
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

  Future<void> _refreshAndroidAutoData(AppState appState) async {
    setState(() {});

    try {
      if (!appState.isLoggedIn) return;

      await appState.loadLibraryData();

      final audioHandler = appState.audioHandler;
      if (audioHandler != null) {
        try {
          audioHandler.updateMediaLibrary(
            albums: appState.albums,
            artists: appState.artists,
            tracks: appState.tracks,
            playlists: appState.playlists,
          );
        } catch (e) {
          // Non-critical error
        }
      }
    } catch (e) {
      // Handle silently
    }

    setState(() {});
  }

  Widget _buildTabContent(int index, AppState appState) {
    final l10n = AppLocalizations.of(context);
    Widget content;

    switch (index) {
      case 0:
        content = const HomeContent();
        break;
      case 1:
        content = const LibraryContent();
        break;
      case 2:
        content = const DownloadsScreen();
        break;
      case 3:
        content = const SearchScreen();
        break;
      case 4:
        content = const SettingsScreen();
        break;
      default:
        content = const HomeContent();
    }

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: Stack(
        children: [
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
          Positioned.fill(
            top: appState.isOfflineMode ? 40 : 0,
            bottom: 0,
            child: content,
          ),
          if (!appState.useDynamicIsle &&
              index != 4 &&
              !(index == 3 && MediaQuery.of(context).viewInsets.bottom > 0))
            Positioned(
              left: 0,
              right: 0,
              bottom: 97,
              child: const MiniPlayer(),
            ),
        ],
      ),
    );
  }

  Widget _buildAndroidAutoUI(AppState appState) {
    return Container(
      color: const Color(0xFF000000),
      child: Column(
        children: [
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
                border: Border.all(
                  color: CupertinoColors.systemOrange,
                  width: 2,
                ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
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
          if (appState.albums.isEmpty &&
              appState.tracks.isEmpty &&
              !appState.isLoading)
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
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
    try {
      final tracks = await appState.getAlbumTracks(album.id);
      if (tracks.isNotEmpty) {
        await appState.playPlaylist(tracks, 0);
      }
    } catch (e) {
      // Don't throw - prevent crashes in Android Auto
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
              return TrackListItem(
                track: track,
                onTap: () => _playFavoriteTrack(appState, track, index),
                showAlbumArt: true,
                showTrackNumber: false,
                showDuration: true,
                showDownloadButton: true,
                showFavoriteButton: true,
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
    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isLocalMusic =
        appState.mediaServiceManager.currentServerType == ServerType.local;

    // Return loading indicator if localization is not ready yet
    if (l10n == null) {
      return const Center(child: CupertinoActivityIndicator());
    }

    // Build tab contents based on local music mode
    // For local music: Home, Library, Search, Settings (4 tabs)
    // For server music: Home, Library, Downloads, Search, Settings (5 tabs)
    final tabContents = isLocalMusic
        ? <Widget>[
            _buildTabContent(0, appState), // Home
            _buildTabContent(1, appState), // Library
            _buildTabContent(3, appState), // Search (index 3 in switch)
            _buildTabContent(4, appState), // Settings (index 4 in switch)
          ]
        : <Widget>[
            _buildTabContent(0, appState), // Home
            _buildTabContent(1, appState), // Library
            _buildTabContent(2, appState), // Downloads
            _buildTabContent(3, appState), // Search
            _buildTabContent(4, appState), // Settings
          ];

    return Stack(
      children: [
        // Main content - positioned to leave room for navbar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: 0, // Content can extend to bottom, navbar overlays it
          child: IndexedStack(
            index: _tabController.index,
            children: tabContents,
          ),
        ),

        // Dynamic Isle - only show on mobile and when enabled in settings
        if (appState.useDynamicIsle) const DynamicIsle(),

        // iOS 26-style liquid glass tab bar positioned at the bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: bottomPadding,
          child: LiquidGlassNavBar(
            currentIndex: _tabController.index,
            onTap: (index) {
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
            items: [
              LiquidGlassNavItem(
                icon: CupertinoIcons.house,
                activeIcon: CupertinoIcons.house_fill,
                label: l10n.navHome,
              ),
              LiquidGlassNavItem(
                icon: CupertinoIcons.music_note_list,
                activeIcon: CupertinoIcons.music_note_list,
                label: l10n.navLibrary,
              ),
              if (!isLocalMusic)
                LiquidGlassNavItem(
                  icon: CupertinoIcons.arrow_down_circle,
                  activeIcon: CupertinoIcons.arrow_down_circle_fill,
                  label: l10n.navDownloads,
                ),
              LiquidGlassNavItem(
                icon: CupertinoIcons.search,
                activeIcon: CupertinoIcons.search,
                label: l10n.navSearch,
              ),
              LiquidGlassNavItem(
                icon: CupertinoIcons.gear,
                activeIcon: CupertinoIcons.gear_solid,
                label: l10n.navSettings,
              ),
            ],
            accentColor: AppleColors.systemPink,
          ),
        ),
      ],
    );
  }
}
