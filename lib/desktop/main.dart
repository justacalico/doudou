import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import '../providers/app_state.dart';
import '../screens/login/login.dart';
import 'pages/home.dart';
import 'pages/albums.dart';
import 'pages/playlists.dart';
import 'pages/artists.dart';
import 'pages/search.dart';
import 'pages/library.dart';
import 'pages/settings.dart';
import 'pages/details/album_details.dart';
import 'pages/details/artist_details.dart';
import 'pages/details/playlist_details.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize sqflite for Linux/Windows/macOS
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.linux ||
                  defaultTargetPlatform == TargetPlatform.windows ||
                  defaultTargetPlatform == TargetPlatform.macOS)) {
    // Initialize the ffi database factory for desktop platforms
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  // Initialize MediaKit for Linux audio support
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
    JustAudioMediaKit.ensureInitialized();
  }
  
  // Desktop-specific orientation settings (allow all orientations)
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }
  
  runApp(const DesktopDoudouApp());
}

class DesktopDoudouApp extends StatelessWidget {
  const DesktopDoudouApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppState(),
      child: _buildAppWithPlatformServices(
        Consumer<AppState>(
          builder: (context, appState, child) {
            return MaterialApp(
              title: 'Doudou - Jellyfin Music Player',
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: appState.accentColor,
                  brightness: Brightness.light,
                ),
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: appState.accentColor,
                  brightness: Brightness.dark,
                ),
              ),
              themeMode: appState.themeMode,
              home: Consumer<AppState>(
                builder: (context, appState, child) {
                  // Show loading screen while initializing
                  if (!appState.isInitialized) {
                    return const Scaffold(
                      body: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text(
                              'Loading Desktop App...',
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  
                  if (appState.isLoggedIn) {
                    return const DesktopHomeLayout();
                  } else {
                    return const LoginScreen();
                  }
                },
              ),
              debugShowCheckedModeBanner: false,
            );
          },
        ),
      ),
    );
  }

  /// Wraps the app with platform-specific services for desktop
  Widget _buildAppWithPlatformServices(Widget app) {
    // On macOS, use AudioServiceWidget for background audio support
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      return AudioServiceWidget(child: app);
    }
    
    // On other desktop platforms and web, return the app directly
    return app;
  }
}

class DesktopHomeLayout extends StatefulWidget {
  const DesktopHomeLayout({super.key});

  @override
  State<DesktopHomeLayout> createState() => _DesktopHomeLayoutState();
}

class _DesktopHomeLayoutState extends State<DesktopHomeLayout> {
  int _selectedIndex = 0;
  
  // Navigation stack for detail views
  final List<Widget> _navigationStack = [];
  
  final List<String> _navigationItems = [
    'Home',
    'Search',
    'Library',
    'Playlists',
    'Albums',
    'Artists',
    'Settings',
  ];
  
  // Method to navigate to detail view
  void navigateToDetail(Widget detailWidget) {
    setState(() {
      _navigationStack.add(detailWidget);
    });
  }
  
  // Method to go back from detail view
  void navigateBack() {
    if (_navigationStack.isNotEmpty) {
      setState(() {
        _navigationStack.removeLast();
      });
    }
  }

  final List<IconData> _navigationIcons = [
    Icons.home_outlined,
    Icons.search,
    Icons.library_music_outlined,
    Icons.playlist_play_outlined,
    Icons.album_outlined,
    Icons.person_outline,
    Icons.settings_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: Column(
        children: [
          // Main content area with sidebar
          Expanded(
            child: Row(
              children: [
                // Left Sidebar
                Container(
                  width: 240,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(
                      right: BorderSide(
                        color: theme.colorScheme.outline.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      // App title/logo area
                      Container(
                        height: 64,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Icon(
                              Icons.music_note,
                              size: 28,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Doudou',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const Divider(height: 1),
                      
                      // Navigation items
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _navigationItems.length,
                          itemBuilder: (context, index) {
                            final isSelected = index == _selectedIndex;
                            return Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              child: ListTile(
                                selected: isSelected,
                                selectedTileColor: theme.colorScheme.primaryContainer,
                                leading: Icon(
                                  _navigationIcons[index],
                                  color: isSelected 
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                                ),
                                title: Text(
                                  _navigationItems[index],
                                  style: TextStyle(
                                    color: isSelected 
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                    fontWeight: isSelected 
                                      ? FontWeight.w600 
                                      : FontWeight.normal,
                                  ),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                onTap: () {
                                  setState(() {
                                    _selectedIndex = index;
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Main content area
                Expanded(
                  child: Container(
                    color: theme.colorScheme.background,
                    child: Column(
                      children: [
                        // Back button bar for detail views
                        if (_navigationStack.isNotEmpty)
                          Container(
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              border: Border(
                                bottom: BorderSide(
                                  color: theme.colorScheme.outline.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: navigateBack,
                                  icon: const Icon(Icons.arrow_back),
                                  tooltip: 'Back',
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Back to ${_navigationItems[_selectedIndex]}',
                                  style: theme.textTheme.titleMedium,
                                ),
                              ],
                            ),
                          ),
                        
                        // Main content
                        Expanded(
                          child: _navigationStack.isNotEmpty 
                            ? _navigationStack.last 
                            : _buildMainContent(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Bottom Player Bar
          _buildBottomPlayerBar(theme),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return _buildSearchContent();
      case 2:
        return _buildLibraryContent();
      case 3:
        return _buildPlaylistsContent();
      case 4:
        return _buildAlbumsContent();
      case 5:
        return _buildArtistsContent();
      case 6:
        return _buildSettingsContent();
      default:
        return _buildHomeContent();
    }
  }

  Widget _buildHomeContent() {
    return HomePage(onNavigateToDetail: navigateToDetail);
  }

  Widget _buildSearchContent() {
    return SearchPage(onNavigateToDetail: navigateToDetail);
  }

  Widget _buildLibraryContent() {
    return LibraryPage(onNavigateToDetail: navigateToDetail);
  }

  Widget _buildPlaylistsContent() {
    return PlaylistsPage(onNavigateToDetail: navigateToDetail);
  }

  Widget _buildAlbumsContent() {
    return AlbumsPage(onNavigateToDetail: navigateToDetail);
  }

  Widget _buildArtistsContent() {
    return ArtistsPage(onNavigateToDetail: navigateToDetail);
  }

  Widget _buildSettingsContent() {
    return const SettingsPage();
  }

  Widget _buildBottomPlayerBar(ThemeData theme) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Album art placeholder
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.music_note,
                color: theme.colorScheme.onSurfaceVariant,
                size: 28,
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Track info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'No track playing',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Select a song to play',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            // Player controls
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.skip_previous),
                  iconSize: 28,
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.play_arrow),
                  iconSize: 32,
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.skip_next),
                  iconSize: 28,
                ),
              ],
            ),
            
            const SizedBox(width: 16),
            
            // Volume and additional controls
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.favorite_border),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.volume_up),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.fullscreen),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}