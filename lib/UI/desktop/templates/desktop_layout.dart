import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_state.dart';
import '../../../models/jellyfin_models.dart';
import '../../../models/download_models.dart';
import '../../../services/audio/unified_audio_handler.dart';
import '../services/navigation_service.dart';
import '../pages/home.dart';
import '../pages/search.dart';
import '../pages/library.dart';
import '../pages/albums.dart';
import '../pages/artists.dart';
import '../pages/tracks.dart';
import '../pages/playlists.dart';
import '../pages/downloads.dart';
import '../pages/settings.dart';
import '../pages/details/media_details.dart';
import '../pages/details/artist_details.dart';
import '../widgets/universal_image.dart';
import 'desktop_theme.dart';

class DesktopLayout extends StatefulWidget {
  final int selectedIndex;
  final VoidCallback? onNavigationChanged;

  const DesktopLayout({
    super.key,
    this.selectedIndex = 0,
    this.onNavigationChanged,
  });

  /// Show add to playlist dialog
  static Future<void> showAddToPlaylistDialog(
    BuildContext context,
    Track track,
  ) async {
    final l10n = AppLocalizations.of(context);
    final appState = context.read<AppState>();
    final playlists = appState.playlists;

    if (playlists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.noPlaylistsAvailable),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) =>
          _AddToPlaylistDialog(track: track, playlists: playlists),
    );
  }

  @override
  State<DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends State<DesktopLayout>
    with TickerProviderStateMixin {
  final NavigationService _navigationService = NavigationService();
  final FocusNode _focusNode = FocusNode();
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.selectedIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _navigationService.selectedPageIndex.addListener(_onExternalNavigation);
    _navigationService.detailPageStack.addListener(_onDetailPageChange);
  }

  @override
  void dispose() {
    _navigationService.selectedPageIndex.removeListener(_onExternalNavigation);
    _navigationService.detailPageStack.removeListener(_onDetailPageChange);
    _pageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onExternalNavigation() {
    final newIndex = _navigationService.selectedPageIndex.value;
    if (newIndex != _currentIndex && newIndex < _pages.length) {
      setState(() => _currentIndex = newIndex);
      _pageController.jumpToPage(newIndex);
    }
  }

  void _onDetailPageChange() {
    // Trigger rebuild when detail page stack changes
    setState(() {});
  }

  void _navigateToPage(int index) {
    // Always clear detail pages when clicking sidebar, even if same page
    _navigationService.selectPage(index);
    if (index != _currentIndex) {
      setState(() => _currentIndex = index);
      _pageController.jumpToPage(index);
    }
  }

  List<_NavItem> get _navItems => [
    _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
    _NavItem(Icons.search_outlined, Icons.search_rounded, 'Search'),
    _NavItem(
      Icons.library_music_outlined,
      Icons.library_music_rounded,
      'Library',
    ),
  ];

  List<_NavItem> get _libraryItems => [
    _NavItem(Icons.album_outlined, Icons.album_rounded, 'Albums'),
    _NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Artists'),
    _NavItem(Icons.music_note_outlined, Icons.music_note_rounded, 'Tracks'),
    _NavItem(
      Icons.queue_music_outlined,
      Icons.queue_music_rounded,
      'Playlists',
    ),
    _NavItem(
      Icons.download_outlined,
      Icons.download_rounded,
      'Downloads',
    ),
  ];

  List<Widget> get _pages => const [
    HomePage(),
    SearchPage(),
    LibraryPage(),
    AlbumsPage(),
    ArtistsPage(),
    TracksPage(),
    PlaylistsPage(),
    DownloadsPage(),
    SettingsPage(),
  ];

  Widget? _buildDetailPage() {
    final detailPage = _navigationService.currentDetailPage;
    if (detailPage == null) return null;

    switch (detailPage.type) {
      case DetailPageType.album:
        return _AlbumDetailView(
          album: detailPage.data as Album,
          onBack: _navigationService.goBack,
        );
      case DetailPageType.artist:
        return _ArtistDetailView(
          artist: detailPage.data as Artist,
          onBack: _navigationService.goBack,
        );
      case DetailPageType.playlist:
        return _PlaylistDetailView(
          playlist: detailPage.data as Playlist,
          onBack: _navigationService.goBack,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailPage = _buildDetailPage();

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: DesktopTheme.backgroundDeep,
        body: Column(
          children: [
            // Main content area
            Expanded(
              child: Row(
                children: [
                  // Sidebar
                  _Sidebar(
                    currentIndex: _currentIndex,
                    navItems: _navItems,
                    libraryItems: _libraryItems,
                    onNavTap: _navigateToPage,
                    onSettingsTap: () => _navigateToPage(8),
                  ),
                  // Page content
                  Expanded(
                    child: ClipRect(
                      child:
                          detailPage ??
                          PageView(
                            controller: _pageController,
                            physics: const NeverScrollableScrollPhysics(),
                            children: _pages,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            // Bottom player bar
            const _PlayerBar(),
          ],
        ),
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final appState = context.read<AppState>();

    if (event.logicalKey == LogicalKeyboardKey.space) {
      appState.playPause();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
        HardwareKeyboard.instance.isControlPressed) {
      appState.skipToNext();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
        HardwareKeyboard.instance.isControlPressed) {
      appState.skipToPrevious();
    }
  }
}

/// Navigation item data
class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem(this.icon, this.activeIcon, this.label);
}

/// Sidebar navigation
class _Sidebar extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> navItems;
  final List<_NavItem> libraryItems;
  final ValueChanged<int> onNavTap;
  final VoidCallback onSettingsTap;

  const _Sidebar({
    required this.currentIndex,
    required this.navItems,
    required this.libraryItems,
    required this.onNavTap,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      width: DesktopTheme.sidebarWidth,
      decoration: const BoxDecoration(
        color: DesktopTheme.backgroundPrimary,
        border: Border(
          right: BorderSide(color: DesktopTheme.glassBorder, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo
                  Padding(
                    padding: const EdgeInsets.all(DesktopTheme.spacingLg),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: DesktopTheme.accentGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.music_note_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: DesktopTheme.spacingSm),
                        const Text(
                          'Doudou',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: DesktopTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Main navigation
                  ...navItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return _SidebarItem(
                      icon: item.icon,
                      activeIcon: item.activeIcon,
                      label: _getLocalizedLabel(l10n, index),
                      isSelected: currentIndex == index,
                      onTap: () => onNavTap(index),
                    );
                  }),

                  const SizedBox(height: DesktopTheme.spacingMd),

                  // Divider
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesktopTheme.spacingMd,
                    ),
                    child: Container(height: 1, color: DesktopTheme.glassBorder),
                  ),

                  const SizedBox(height: DesktopTheme.spacingMd),

                  // Library section header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesktopTheme.spacingLg,
                      vertical: DesktopTheme.spacingSm,
                    ),
                    child: Text(
                      l10n.library.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: DesktopTheme.textTertiary,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),

                  // Library items
                  ...libraryItems.asMap().entries.map((entry) {
                    final index = entry.key + 3; // Offset for main nav items
                    final item = entry.value;
                    return _SidebarItem(
                      icon: item.icon,
                      activeIcon: item.activeIcon,
                      label: _getLocalizedLibraryLabel(l10n, entry.key),
                      isSelected: currentIndex == index,
                      onTap: () => onNavTap(index),
                    );
                  }),
                ],
              ),
            ),
          ),

          // Settings (always at bottom)
          _SidebarItem(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings_rounded,
            label: l10n.settings,
            isSelected: currentIndex == 8,
            onTap: onSettingsTap,
          ),

          const SizedBox(height: DesktopTheme.spacingMd),
        ],
      ),
    );
  }

  String _getLocalizedLabel(AppLocalizations l10n, int index) {
    switch (index) {
      case 0:
        return l10n.navHome;
      case 1:
        return l10n.search;
      case 2:
        return l10n.library;
      default:
        return '';
    }
  }

  String _getLocalizedLibraryLabel(AppLocalizations l10n, int index) {
    switch (index) {
      case 0:
        return l10n.albums;
      case 1:
        return l10n.artists;
      case 2:
        return l10n.songs;
      case 3:
        return l10n.playlists;
      case 4:
        return l10n.downloads;
      default:
        return '';
    }
  }
}

/// Sidebar item widget
class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: DesktopTheme.durationFast,
          margin: const EdgeInsets.symmetric(
            horizontal: DesktopTheme.spacingSm,
            vertical: 2,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: DesktopTheme.spacingMd,
            vertical: DesktopTheme.spacingSm + 2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesktopTheme.radiusSm),
            color: widget.isSelected
                ? accentColor.withOpacity(0.15)
                : _isHovered
                ? DesktopTheme.glassOverlay
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(
                widget.isSelected ? widget.activeIcon : widget.icon,
                color: widget.isSelected
                    ? accentColor
                    : _isHovered
                    ? DesktopTheme.textPrimary
                    : DesktopTheme.textSecondary,
                size: 20,
              ),
              const SizedBox(width: DesktopTheme.spacingMd),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: widget.isSelected
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: widget.isSelected
                        ? accentColor
                        : _isHovered
                        ? DesktopTheme.textPrimary
                        : DesktopTheme.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom player bar
class _PlayerBar extends StatelessWidget {
  const _PlayerBar();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final audioHandler = appState.audioHandler;
        if (audioHandler == null) return const SizedBox.shrink();

        return StreamBuilder<MediaItem?>(
          stream: audioHandler.mediaItem,
          builder: (context, mediaSnapshot) {
            final mediaItem = mediaSnapshot.data;

            // Hide player bar when no track is playing
            if (mediaItem == null) return const SizedBox.shrink();

            return StreamBuilder<PlaybackState>(
              stream: audioHandler.playbackState,
              builder: (context, playbackSnapshot) {
                final playbackState = playbackSnapshot.data;
                final isPlaying = playbackState?.playing ?? false;

                return StreamBuilder<Duration>(
                  stream: audioHandler.positionStream,
                  builder: (context, positionSnapshot) {
                    final position = positionSnapshot.data ?? Duration.zero;

                    return StreamBuilder<Duration?>(
                      stream: audioHandler.durationStream,
                      builder: (context, durationSnapshot) {
                        final duration = durationSnapshot.data ?? Duration.zero;

                        return _PlayerBarContent(
                          mediaItem: mediaItem,
                          isPlaying: isPlaying,
                          position: position,
                          duration: duration,
                          appState: appState,
                          audioHandler: audioHandler,
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _PlayerBarContent extends StatelessWidget {
  final MediaItem? mediaItem;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final AppState appState;
  final dynamic audioHandler;

  const _PlayerBarContent({
    required this.mediaItem,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.appState,
    required this.audioHandler,
  });

  @override
  Widget build(BuildContext context) {
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Container(
      height: DesktopTheme.playerBarHeight,
      decoration: const BoxDecoration(
        color: DesktopTheme.backgroundSecondary,
        border: Border(
          top: BorderSide(color: DesktopTheme.glassBorder, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Progress bar at top
          _ProgressBar(
            progress: progress,
            position: position,
            duration: duration,
            onSeek: (value) {
              final newPosition = Duration(
                milliseconds: (value * duration.inMilliseconds).round(),
              );
              audioHandler.seek(newPosition);
            },
          ),
          // Player content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DesktopTheme.spacingLg,
              ),
              child: Row(
                children: [
                  // Left: Track info
                  Expanded(
                    flex: 1,
                    child: _TrackInfo(mediaItem: mediaItem, appState: appState),
                  ),
                  // Center: Playback controls
                  Expanded(
                    flex: 2,
                    child: _PlaybackControls(
                      isPlaying: isPlaying,
                      onPlayPause: appState.playPause,
                      onPrevious: appState.skipToPrevious,
                      onNext: appState.skipToNext,
                      onShuffle: () => audioHandler.setShuffleMode(
                        !(audioHandler.shuffleEnabled ?? false),
                      ),
                      onRepeat: () {
                        final currentMode = audioHandler.repeatMode;
                        final nextMode = currentMode == RepeatMode.none
                            ? RepeatMode.all
                            : currentMode == RepeatMode.all
                            ? RepeatMode.one
                            : RepeatMode.none;
                        audioHandler.setRepeatMode(nextMode);
                      },
                      isShuffled: audioHandler.shuffleEnabled ?? false,
                      repeatMode: audioHandler.repeatMode ?? RepeatMode.none,
                    ),
                  ),
                  // Right: Volume and extras
                  Expanded(
                    flex: 1,
                    child: _PlayerExtras(
                      audioHandler: audioHandler,
                      onQueueTap: () => _showNowPlaying(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNowPlaying(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black54,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: _NowPlayingOverlay(
              appState: appState,
              audioHandler: audioHandler,
            ),
          );
        },
      ),
    );
  }
}

/// Progress bar widget
class _ProgressBar extends StatefulWidget {
  final double progress;
  final Duration position;
  final Duration duration;
  final ValueChanged<double> onSeek;

  const _ProgressBar({
    required this.progress,
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar> {
  bool _isHovered = false;
  bool _isDragging = false;
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentProgress = _dragValue ?? widget.progress;
    final isExpanded = _isHovered || _isDragging;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onHorizontalDragStart: (details) {
          setState(() => _isDragging = true);
          _updateDrag(details.localPosition);
        },
        onHorizontalDragUpdate: (details) => _updateDrag(details.localPosition),
        onHorizontalDragEnd: (_) {
          if (_dragValue != null) widget.onSeek(_dragValue!);
          setState(() {
            _isDragging = false;
            _dragValue = null;
          });
        },
        onTapDown: (details) {
          _updateDrag(details.localPosition);
          if (_dragValue != null) widget.onSeek(_dragValue!);
          _dragValue = null;
        },
        child: SizedBox(
          height: isExpanded ? 6 : 4,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  // Background track
                  Container(
                    decoration: BoxDecoration(
                      color: DesktopTheme.backgroundElevated,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Active track
                  FractionallySizedBox(
                    widthFactor: currentProgress.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isExpanded
                            ? theme.colorScheme.primary
                            : DesktopTheme.textPrimary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _updateDrag(Offset localPosition) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final progress = (localPosition.dx / box.size.width).clamp(0.0, 1.0);
    setState(() => _dragValue = progress);
  }
}

/// Track info widget
class _TrackInfo extends StatelessWidget {
  final MediaItem? mediaItem;
  final AppState appState;

  const _TrackInfo({required this.mediaItem, required this.appState});

  @override
  Widget build(BuildContext context) {
    if (mediaItem == null) {
      return const SizedBox.shrink();
    }

    final trackId = mediaItem!.id;
    final isFavorite = appState.isFavorite(trackId);

    return Row(
      children: [
        // Album art
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesktopTheme.radiusSm),
            color: DesktopTheme.backgroundElevated,
          ),
          clipBehavior: Clip.antiAlias,
          child: mediaItem!.artUri != null
              ? buildSmartImage(
                  imageUrl: mediaItem!.artUri.toString(),
                  fit: BoxFit.cover,
                  errorBuilder: () => _buildPlaceholder(),
                )
              : _buildPlaceholder(),
        ),
        const SizedBox(width: DesktopTheme.spacingMd),
        // Track details
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mediaItem!.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: DesktopTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                mediaItem!.artist ?? 'Unknown Artist',
                style: TextStyle(
                  fontSize: 12,
                  color: DesktopTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        // Like button
        DesktopIconButton(
          icon: isFavorite
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          color: isFavorite ? const Color(0xFFEC4899) : null,
          tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
          onPressed: () {
            final track = appState.tracks.where((t) => t.id == trackId).firstOrNull;
            if (track != null) {
              appState.toggleFavorite(track);
            }
          },
        ),
        // More options button
        PopupMenuButton<String>(
          icon: Icon(
            Icons.more_horiz_rounded,
            color: DesktopTheme.textSecondary,
            size: 20,
          ),
          tooltip: 'More options',
          onSelected: (value) {
            final track = appState.tracks.where((t) => t.id == trackId).firstOrNull;
            if (track == null) return;
            
            switch (value) {
              case 'addToQueue':
                appState.addToQueue(track);
                break;
              case 'addToPlaylist':
                DesktopLayout.showAddToPlaylistDialog(context, track);
                break;
              case 'showAlbum':
                if (track.albumId != null) {
                  final album = appState.albums.where((a) => a.id == track.albumId).firstOrNull;
                  if (album != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => MediaDetailsPage.album(album: album),
                      ),
                    );
                  }
                }
                break;
              case 'showArtist':
                if (track.artistName != null) {
                  final artist = appState.artists.where((a) => a.name == track.artistName).firstOrNull;
                  if (artist != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ArtistDetailsPage(artist: artist),
                      ),
                    );
                  }
                }
                break;
              case 'download':
                _handleDownload(context, appState, track);
                break;
            }
          },
          itemBuilder: (context) {
            final l10n = AppLocalizations.of(context);
            final track = appState.tracks.where((t) => t.id == trackId).firstOrNull;
            
            // Get download status
            IconData downloadIcon = Icons.download_rounded;
            String downloadLabel = l10n.download;
            if (track != null) {
              final downloadStatus = appState.downloadService.getDownloadStatus(track.id);
              if (downloadStatus == DownloadStatus.downloaded) {
                downloadIcon = Icons.download_done_rounded;
                downloadLabel = 'Downloaded';
              } else if (downloadStatus == DownloadStatus.downloading) {
                downloadIcon = Icons.downloading_rounded;
                downloadLabel = l10n.downloading;
              }
            }
            
            return [
              PopupMenuItem(
                value: 'addToQueue',
                child: ListTile(
                  leading: const Icon(Icons.queue_music_rounded),
                  title: Text(l10n.addToQueue),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'addToPlaylist',
                child: ListTile(
                  leading: const Icon(Icons.playlist_add_rounded),
                  title: Text(l10n.addToPlaylist),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'showAlbum',
                child: ListTile(
                  leading: const Icon(Icons.album_rounded),
                  title: Text(l10n.showAlbum),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'showArtist',
                child: ListTile(
                  leading: const Icon(Icons.person_rounded),
                  title: Text(l10n.showArtist),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'download',
                child: ListTile(
                  leading: Icon(downloadIcon),
                  title: Text(downloadLabel),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ];
          },
        ),
      ],
    );
  }

  void _handleDownload(BuildContext context, AppState appState, Track track) {
    final l10n = AppLocalizations.of(context);
    final downloadStatus = appState.downloadService.getDownloadStatus(track.id);
    
    switch (downloadStatus) {
      case DownloadStatus.downloaded:
        // Show option to delete
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Downloaded'),
            content: Text('"${track.name}" is already downloaded.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.ok),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  appState.downloadService.deleteDownload(track.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.deleteDownload),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: Text(l10n.deleteDownload),
              ),
            ],
          ),
        );
        break;
      case DownloadStatus.downloading:
        // Show option to cancel
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.downloading),
            content: Text('"${track.name}" is currently downloading.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.ok),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  appState.downloadService.cancelDownload(track.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.cancelDownload),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: Text(l10n.cancelDownload),
              ),
            ],
          ),
        );
        break;
      case DownloadStatus.paused:
      case DownloadStatus.failed:
      case DownloadStatus.notDownloaded:
        appState.downloadService.downloadTrack(track);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.downloadStarted}: ${track.name}'),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      color: DesktopTheme.backgroundTertiary,
      child: const Icon(
        Icons.music_note_rounded,
        color: DesktopTheme.textTertiary,
        size: 24,
      ),
    );
  }
}

/// Playback controls widget
class _PlaybackControls extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onShuffle;
  final VoidCallback onRepeat;
  final bool isShuffled;
  final RepeatMode repeatMode;

  const _PlaybackControls({
    required this.isPlaying,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onShuffle,
    required this.onRepeat,
    required this.isShuffled,
    required this.repeatMode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Shuffle
        DesktopIconButton(
          icon: Icons.shuffle_rounded,
          isActive: isShuffled,
          activeColor: theme.colorScheme.primary,
          onPressed: onShuffle,
          tooltip: 'Shuffle',
        ),
        const SizedBox(width: DesktopTheme.spacingMd),
        // Previous
        DesktopIconButton(
          icon: Icons.skip_previous_rounded,
          size: 24,
          onPressed: onPrevious,
          tooltip: 'Previous',
        ),
        const SizedBox(width: DesktopTheme.spacingSm),
        // Play/Pause
        _PlayPauseButton(isPlaying: isPlaying, onPressed: onPlayPause),
        const SizedBox(width: DesktopTheme.spacingSm),
        // Next
        DesktopIconButton(
          icon: Icons.skip_next_rounded,
          size: 24,
          onPressed: onNext,
          tooltip: 'Next',
        ),
        const SizedBox(width: DesktopTheme.spacingMd),
        // Repeat
        DesktopIconButton(
          icon: repeatMode == RepeatMode.one
              ? Icons.repeat_one_rounded
              : Icons.repeat_rounded,
          isActive: repeatMode != RepeatMode.none,
          activeColor: theme.colorScheme.primary,
          onPressed: onRepeat,
          tooltip: 'Repeat',
        ),
      ],
    );
  }
}

/// Play/Pause button
class _PlayPauseButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onPressed;

  const _PlayPauseButton({required this.isPlaying, required this.onPressed});

  @override
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<_PlayPauseButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: DesktopTheme.durationFast,
          width: 40,
          height: 40,
          transform: Matrix4.identity()..scale(_isHovered ? 1.08 : 1.0),
          transformAlignment: Alignment.center,
          decoration: const BoxDecoration(
            color: DesktopTheme.textPrimary,
            shape: BoxShape.circle,
          ),
          child: Icon(
            widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: DesktopTheme.backgroundDeep,
            size: 24,
          ),
        ),
      ),
    );
  }
}

/// Player extras (volume, queue)
class _PlayerExtras extends StatefulWidget {
  final dynamic audioHandler;
  final VoidCallback onQueueTap;

  const _PlayerExtras({required this.audioHandler, required this.onQueueTap});

  @override
  State<_PlayerExtras> createState() => _PlayerExtrasState();
}

class _PlayerExtrasState extends State<_PlayerExtras> {
  bool _showVolume = false;
  double _volume = 1.0;
  dynamic _volumeSubscription;

  @override
  void initState() {
    super.initState();
    _volume = widget.audioHandler?.volume ?? 1.0;
    _volumeSubscription = widget.audioHandler?.volumeStream?.listen((vol) {
      if (mounted) setState(() => _volume = vol);
    });
  }

  @override
  void dispose() {
    _volumeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Queue button
        DesktopIconButton(
          icon: Icons.queue_music_rounded,
          tooltip: 'Queue',
          onPressed: widget.onQueueTap,
        ),
        const SizedBox(width: DesktopTheme.spacingSm),
        // Volume
        MouseRegion(
          onEnter: (_) => setState(() => _showVolume = true),
          onExit: (_) => setState(() => _showVolume = false),
          child: Row(
            children: [
              DesktopIconButton(
                icon: _volume == 0
                    ? Icons.volume_off_rounded
                    : _volume < 0.5
                    ? Icons.volume_down_rounded
                    : Icons.volume_up_rounded,
                onPressed: () {
                  final newVolume = _volume == 0 ? 1.0 : 0.0;
                  setState(() => _volume = newVolume);
                  widget.audioHandler?.setVolume(newVolume);
                },
              ),
              AnimatedContainer(
                duration: DesktopTheme.durationFast,
                width: _showVolume ? 80 : 0,
                child: _showVolume
                    ? SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12,
                          ),
                          activeTrackColor: DesktopTheme.textPrimary,
                          inactiveTrackColor: DesktopTheme.backgroundElevated,
                          thumbColor: DesktopTheme.textPrimary,
                        ),
                        child: Slider(
                          value: _volume,
                          onChanged: (value) {
                            setState(() => _volume = value);
                            widget.audioHandler?.setVolume(value);
                          },
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        const SizedBox(width: DesktopTheme.spacingSm),
        // Fullscreen/Now Playing
        DesktopIconButton(
          icon: Icons.open_in_full_rounded,
          tooltip: 'Now Playing',
          onPressed: widget.onQueueTap,
        ),
      ],
    );
  }
}

/// Now Playing overlay
class _NowPlayingOverlay extends StatefulWidget {
  final AppState appState;
  final dynamic audioHandler;

  const _NowPlayingOverlay({
    required this.appState,
    required this.audioHandler,
  });

  @override
  State<_NowPlayingOverlay> createState() => _NowPlayingOverlayState();
}

class _NowPlayingOverlayState extends State<_NowPlayingOverlay>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() => _selectedTab = _tabController.index);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Check if "The Mind Electric" easter egg should be active
  /// Returns true only during the backwards section (before 2:50)
  bool _isMindElectricBackwards(MediaItem? mediaItem, Duration position) {
    final title = mediaItem?.title.toLowerCase() ?? '';
    final artist = mediaItem?.artist?.toLowerCase() ?? '';
    final isMindElectric =
        (title.contains('mind electric') ||
            title.contains('the mind electric')) &&
        (artist.contains('miracle musical') ||
            artist.contains('tally hall') ||
            artist.contains('joe hawley'));
    // The song plays backwards until 2:50, then forwards
    const forwardTimestamp = Duration(minutes: 2, seconds: 50);
    return isMindElectric && position < forwardTimestamp;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return StreamBuilder<MediaItem?>(
      stream: widget.audioHandler?.mediaItem,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;

        return StreamBuilder<Duration>(
          stream: widget.audioHandler?.positionStream,
          builder: (context, positionSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            final isMindElectricBackwards = _isMindElectricBackwards(
              mediaItem,
              position,
            );

            // Easter egg: Flip everything horizontally during the backwards section
            // of "The Mind Electric" (before 2:50), then flip back to normal
            Widget content = Scaffold(
              backgroundColor: Colors.transparent,
              body: Stack(
                children: [
                  // Background with album art blur
                  if (mediaItem?.artUri != null)
                    Positioned.fill(
                      child: buildSmartImage(
                        imageUrl: mediaItem!.artUri.toString(),
                        fit: BoxFit.cover,
                        errorBuilder: () =>
                            Container(color: DesktopTheme.backgroundDeep),
                      ),
                    ),
                  // Dark overlay
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            DesktopTheme.backgroundDeep.withOpacity(0.5),
                            DesktopTheme.backgroundDeep.withOpacity(0.85),
                            DesktopTheme.backgroundDeep.withOpacity(0.95),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Content
                  SafeArea(
                    child: Column(
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.all(DesktopTheme.spacingMd),
                          child: Row(
                            children: [
                              DesktopIconButton(
                                icon: Icons.keyboard_arrow_down_rounded,
                                size: 28,
                                onPressed: () => Navigator.pop(context),
                              ),
                              const Spacer(),
                              DesktopIconButton(
                                icon: Icons.more_horiz_rounded,
                                onPressed: () {},
                              ),
                            ],
                          ),
                        ),
                        // Main content row
                        Expanded(
                          child: Row(
                            children: [
                              // Left: Album art and controls
                              Expanded(
                                flex: 3,
                                child: _NowPlayingMain(
                                  mediaItem: mediaItem,
                                  appState: widget.appState,
                                  audioHandler: widget.audioHandler,
                                ),
                              ),
                              // Right: Queue/Lyrics panel
                              Expanded(
                                flex: 2,
                                child: Container(
                                  margin: const EdgeInsets.only(
                                    right: DesktopTheme.spacingLg,
                                    bottom: DesktopTheme.spacingLg,
                                  ),
                                  decoration: BoxDecoration(
                                    color: DesktopTheme.backgroundDeep
                                        .withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(
                                      DesktopTheme.radiusMd,
                                    ),
                                    border: Border.all(
                                      color: DesktopTheme.glassBorder,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      // Tabs
                                      Padding(
                                        padding: const EdgeInsets.all(
                                          DesktopTheme.spacingMd,
                                        ),
                                        child: Row(
                                          children: [
                                            _TabButton(
                                              label: l10n.upNext,
                                              isSelected: _selectedTab == 0,
                                              onTap: () =>
                                                  _tabController.animateTo(0),
                                            ),
                                            const SizedBox(
                                              width: DesktopTheme.spacingMd,
                                            ),
                                            _TabButton(
                                              label: l10n.lyrics,
                                              isSelected: _selectedTab == 1,
                                              onTap: () =>
                                                  _tabController.animateTo(1),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Playing from
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: DesktopTheme.spacingMd,
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              '${l10n.playingFrom} ',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color:
                                                    DesktopTheme.textTertiary,
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                mediaItem?.album ??
                                                    l10n.unknownAlbum,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color:
                                                      DesktopTheme.textPrimary,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(
                                        height: DesktopTheme.spacingSm,
                                      ),
                                      // Tab content
                                      Expanded(
                                        child: TabBarView(
                                          controller: _tabController,
                                          children: [
                                            _QueueList(
                                              appState: widget.appState,
                                              audioHandler: widget.audioHandler,
                                            ),
                                            _LyricsView(mediaItem: mediaItem),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );

            // Apply the horizontal flip transformation for the easter egg
            // (only during the backwards section before 2:50)
            // Use AnimatedSwitcher for smooth transition when flipping
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 800),
              transitionBuilder: (child, animation) {
                // Create a flip animation around the Y axis
                final flipAnimation = Tween<double>(begin: 1.0, end: 0.0)
                    .animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeInOut,
                      ),
                    );
                return AnimatedBuilder(
                  animation: flipAnimation,
                  builder: (context, child) {
                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001) // perspective
                        ..rotateY(flipAnimation.value * 3.14159),
                      child: child,
                    );
                  },
                  child: child,
                );
              },
              child: isMindElectricBackwards
                  ? Directionality(
                      key: const ValueKey('flipped'),
                      textDirection: TextDirection.rtl,
                      child: Transform.flip(flipX: true, child: content),
                    )
                  : KeyedSubtree(key: const ValueKey('normal'), child: content),
            );
          },
        );
      },
    );
  }
}

/// Now playing main section
class _NowPlayingMain extends StatelessWidget {
  final MediaItem? mediaItem;
  final AppState appState;
  final dynamic audioHandler;

  const _NowPlayingMain({
    required this.mediaItem,
    required this.appState,
    required this.audioHandler,
  });

  void _navigateToAlbum(BuildContext context) {
    final albumId = mediaItem?.extras?['albumId'] as String?;
    final albumName = mediaItem?.album;

    if (albumId != null) {
      // Find album by ID
      final album = appState.albums.where((a) => a.id == albumId).firstOrNull;
      if (album != null) {
        Navigator.of(context).pop(); // Close now playing overlay
        NavigationService().navigateToAlbum(album);
        return;
      }
    }

    // Fallback: find by name
    if (albumName != null) {
      final album = appState.albums
          .where((a) => a.name == albumName)
          .firstOrNull;
      if (album != null) {
        Navigator.of(context).pop();
        NavigationService().navigateToAlbum(album);
      }
    }
  }

  void _navigateToArtist(BuildContext context) {
    final artistName = mediaItem?.artist;

    if (artistName != null) {
      final artist = appState.artists
          .where((a) => a.name == artistName)
          .firstOrNull;
      if (artist != null) {
        Navigator.of(context).pop(); // Close now playing overlay
        NavigationService().navigateToArtist(artist);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasAlbum = mediaItem?.album != null && mediaItem!.album!.isNotEmpty;
    final hasArtist =
        mediaItem?.artist != null && mediaItem!.artist!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(DesktopTheme.spacingXl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Album art
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(DesktopTheme.radiusMd),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: mediaItem?.artUri != null
                      ? buildSmartImage(
                          imageUrl: mediaItem!.artUri.toString(),
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: DesktopTheme.backgroundElevated,
                          child: const Icon(
                            Icons.music_note_rounded,
                            size: 100,
                            color: DesktopTheme.textTertiary,
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: DesktopTheme.spacingXl),
          // Track info
          Text(
            mediaItem?.title ?? 'No track playing',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: DesktopTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: DesktopTheme.spacingSm),
          // From: Album (clickable)
          if (hasAlbum)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => _navigateToAlbum(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.fromAlbum,
                      style: TextStyle(
                        fontSize: 14,
                        color: DesktopTheme.textTertiary,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        mediaItem!.album!,
                        style: TextStyle(
                          fontSize: 14,
                          color: DesktopTheme.textSecondary,
                          decoration: TextDecoration.underline,
                          decorationColor: DesktopTheme.textSecondary
                              .withOpacity(0.5),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (hasAlbum) const SizedBox(height: DesktopTheme.spacingXs),
          // By: Artist (clickable)
          if (hasArtist)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => _navigateToArtist(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.byArtist,
                      style: TextStyle(
                        fontSize: 14,
                        color: DesktopTheme.textTertiary,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        mediaItem!.artist!,
                        style: TextStyle(
                          fontSize: 14,
                          color: DesktopTheme.textSecondary,
                          decoration: TextDecoration.underline,
                          decorationColor: DesktopTheme.textSecondary
                              .withOpacity(0.5),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: DesktopTheme.spacingXl),
          // Progress
          _NowPlayingProgress(audioHandler: audioHandler),
          const SizedBox(height: DesktopTheme.spacingLg),
          // Controls
          _NowPlayingControls(
            appState: appState,
            audioHandler: audioHandler,
            mediaItem: mediaItem,
          ),
          const SizedBox(height: DesktopTheme.spacingLg),
        ],
      ),
    );
  }
}

/// Now playing progress bar
class _NowPlayingProgress extends StatelessWidget {
  final dynamic audioHandler;

  const _NowPlayingProgress({required this.audioHandler});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: audioHandler?.positionStream,
      builder: (context, positionSnapshot) {
        final position = positionSnapshot.data ?? Duration.zero;

        return StreamBuilder<Duration?>(
          stream: audioHandler?.durationStream,
          builder: (context, durationSnapshot) {
            final duration = durationSnapshot.data ?? Duration.zero;
            final progress = duration.inMilliseconds > 0
                ? position.inMilliseconds / duration.inMilliseconds
                : 0.0;

            return Column(
              children: [
                // Slider
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                    activeTrackColor: DesktopTheme.textPrimary,
                    inactiveTrackColor: DesktopTheme.backgroundElevated,
                    thumbColor: DesktopTheme.textPrimary,
                  ),
                  child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChanged: (value) {
                      final newPosition = Duration(
                        milliseconds: (value * duration.inMilliseconds).round(),
                      );
                      audioHandler?.seek(newPosition);
                    },
                  ),
                ),
                // Time labels
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesktopTheme.spacingMd,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(position),
                        style: TextStyle(
                          fontSize: 12,
                          color: DesktopTheme.textSecondary,
                        ),
                      ),
                      Text(
                        _formatDuration(duration),
                        style: TextStyle(
                          fontSize: 12,
                          color: DesktopTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Now playing controls
class _NowPlayingControls extends StatelessWidget {
  final AppState appState;
  final dynamic audioHandler;
  final MediaItem? mediaItem;

  const _NowPlayingControls({
    required this.appState,
    required this.audioHandler,
    this.mediaItem,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trackId = mediaItem?.id;
    final isFavorite = trackId != null ? appState.isFavorite(trackId) : false;

    return StreamBuilder<PlaybackState>(
      stream: audioHandler?.playbackState,
      builder: (context, snapshot) {
        final playbackState = snapshot.data;
        final isPlaying = playbackState?.playing ?? false;
        final isShuffled = audioHandler?.shuffleEnabled ?? false;
        final repeatMode = audioHandler?.repeatMode ?? RepeatMode.none;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Shuffle
            DesktopIconButton(
              icon: Icons.shuffle_rounded,
              size: 24,
              isActive: isShuffled,
              activeColor: theme.colorScheme.primary,
              onPressed: () => audioHandler?.setShuffleMode(!isShuffled),
            ),
            const SizedBox(width: DesktopTheme.spacingXl),
            // Previous
            DesktopIconButton(
              icon: Icons.skip_previous_rounded,
              size: 32,
              onPressed: appState.skipToPrevious,
            ),
            const SizedBox(width: DesktopTheme.spacingMd),
            // Play/Pause
            _LargePlayButton(
              isPlaying: isPlaying,
              onPressed: appState.playPause,
            ),
            const SizedBox(width: DesktopTheme.spacingMd),
            // Next
            DesktopIconButton(
              icon: Icons.skip_next_rounded,
              size: 32,
              onPressed: appState.skipToNext,
            ),
            const SizedBox(width: DesktopTheme.spacingXl),
            // Repeat
            DesktopIconButton(
              icon: repeatMode == RepeatMode.one
                  ? Icons.repeat_one_rounded
                  : Icons.repeat_rounded,
              size: 24,
              isActive: repeatMode != RepeatMode.none,
              activeColor: theme.colorScheme.primary,
              onPressed: () {
                final nextMode = repeatMode == RepeatMode.none
                    ? RepeatMode.all
                    : repeatMode == RepeatMode.all
                    ? RepeatMode.one
                    : RepeatMode.none;
                audioHandler?.setRepeatMode(nextMode);
              },
            ),
            const SizedBox(width: DesktopTheme.spacingXl),
            // Favorite
            DesktopIconButton(
              icon: isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              size: 24,
              color: isFavorite ? const Color(0xFFEC4899) : null,
              tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
              onPressed: trackId != null
                  ? () {
                      final track = appState.tracks
                          .where((t) => t.id == trackId)
                          .firstOrNull;
                      if (track != null) {
                        appState.toggleFavorite(track);
                      }
                    }
                  : null,
            ),
          ],
        );
      },
    );
  }
}

/// Large play button for now playing
class _LargePlayButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onPressed;

  const _LargePlayButton({required this.isPlaying, required this.onPressed});

  @override
  State<_LargePlayButton> createState() => _LargePlayButtonState();
}

class _LargePlayButtonState extends State<_LargePlayButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: DesktopTheme.durationFast,
          width: 64,
          height: 64,
          transform: Matrix4.identity()..scale(_isHovered ? 1.08 : 1.0),
          transformAlignment: Alignment.center,
          decoration: const BoxDecoration(
            color: DesktopTheme.textPrimary,
            shape: BoxShape.circle,
          ),
          child: Icon(
            widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: DesktopTheme.backgroundDeep,
            size: 32,
          ),
        ),
      ),
    );
  }
}

/// Tab button for Now Playing overlay
class _TabButton extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_TabButton> createState() => _TabButtonState();
}

class _TabButtonState extends State<_TabButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Column(
          children: [
            Text(
              widget.label.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: widget.isSelected
                    ? DesktopTheme.textPrimary
                    : _isHovered
                    ? DesktopTheme.textSecondary
                    : DesktopTheme.textTertiary,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: DesktopTheme.durationFast,
              width: widget.isSelected ? widget.label.length * 6.0 : 0,
              height: 2,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Queue list widget
class _QueueList extends StatelessWidget {
  final AppState appState;
  final dynamic audioHandler;

  const _QueueList({required this.appState, required this.audioHandler});

  @override
  Widget build(BuildContext context) {
    final queue = appState.queue;
    final currentIndex = audioHandler?.currentIndex ?? 0;

    if (queue.isEmpty) {
      return Center(
        child: Text(
          'Queue is empty',
          style: TextStyle(color: DesktopTheme.textTertiary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: DesktopTheme.spacingSm),
      itemCount: queue.length,
      itemBuilder: (context, index) {
        final track = queue[index];
        final isCurrentTrack = index == currentIndex;

        return _QueueItem(
          track: track,
          isCurrentTrack: isCurrentTrack,
          onTap: () => audioHandler?.skipToQueueItem(index),
        );
      },
    );
  }
}

/// Queue item widget
class _QueueItem extends StatefulWidget {
  final Track track;
  final bool isCurrentTrack;
  final VoidCallback onTap;

  const _QueueItem({
    required this.track,
    required this.isCurrentTrack,
    required this.onTap,
  });

  @override
  State<_QueueItem> createState() => _QueueItemState();
}

class _QueueItemState extends State<_QueueItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: DesktopTheme.durationFast,
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(
            horizontal: DesktopTheme.spacingSm,
            vertical: DesktopTheme.spacingSm,
          ),
          decoration: BoxDecoration(
            color: widget.isCurrentTrack
                ? theme.colorScheme.primary.withOpacity(0.15)
                : _isHovered
                ? DesktopTheme.glassOverlay
                : Colors.transparent,
            borderRadius: BorderRadius.circular(DesktopTheme.radiusSm),
          ),
          child: Row(
            children: [
              // Album art
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: DesktopTheme.backgroundElevated,
                ),
                clipBehavior: Clip.antiAlias,
                child: widget.track.imageUrl != null
                    ? buildSmartImage(
                        imageUrl: widget.track.imageUrl!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: () => const Icon(
                          Icons.music_note_rounded,
                          size: 20,
                          color: DesktopTheme.textTertiary,
                        ),
                      )
                    : const Icon(
                        Icons.music_note_rounded,
                        size: 20,
                        color: DesktopTheme.textTertiary,
                      ),
              ),
              const SizedBox(width: DesktopTheme.spacingSm),
              // Track info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.track.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: widget.isCurrentTrack
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: widget.isCurrentTrack
                            ? theme.colorScheme.primary
                            : DesktopTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.track.artistName ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: DesktopTheme.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Duration
              Text(
                _formatDuration(widget.track.duration),
                style: TextStyle(
                  fontSize: 12,
                  color: DesktopTheme.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(int? durationMs) {
    if (durationMs == null) return '--:--';
    final totalSeconds = durationMs ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Lyrics view placeholder
class _LyricsView extends StatelessWidget {
  final MediaItem? mediaItem;

  const _LyricsView({required this.mediaItem});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesktopTheme.spacingLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lyrics_outlined,
              size: 48,
              color: DesktopTheme.textTertiary,
            ),
            const SizedBox(height: DesktopTheme.spacingMd),
            Text(
              'Lyrics not available',
              style: TextStyle(fontSize: 14, color: DesktopTheme.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Add to playlist dialog
class _AddToPlaylistDialog extends StatelessWidget {
  final Track track;
  final List<Playlist> playlists;

  const _AddToPlaylistDialog({required this.track, required this.playlists});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Dialog(
      backgroundColor: DesktopTheme.backgroundSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesktopTheme.radiusMd),
      ),
      child: Container(
        width: 400,
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(DesktopTheme.spacingLg),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.addToPlaylist,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: DesktopTheme.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                    color: DesktopTheme.textSecondary,
                  ),
                ],
              ),
            ),
            // Divider
            Container(height: 1, color: DesktopTheme.glassBorder),
            // Playlist list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(
                  vertical: DesktopTheme.spacingSm,
                ),
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  final playlist = playlists[index];
                  return _PlaylistItem(
                    playlist: playlist,
                    onTap: () => _addToPlaylist(context, playlist),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addToPlaylist(BuildContext context, Playlist playlist) async {
    final appState = context.read<AppState>();
    final l10n = AppLocalizations.of(context);

    try {
      await appState.addToPlaylist(playlist.id, track.id);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.addedToPlaylist('track', playlist.name, track.name),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorAddingToPlaylist(e.toString())),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

/// Playlist item in add to playlist dialog
class _PlaylistItem extends StatefulWidget {
  final Playlist playlist;
  final VoidCallback onTap;

  const _PlaylistItem({required this.playlist, required this.onTap});

  @override
  State<_PlaylistItem> createState() => _PlaylistItemState();
}

class _PlaylistItemState extends State<_PlaylistItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: DesktopTheme.durationFast,
          margin: const EdgeInsets.symmetric(
            horizontal: DesktopTheme.spacingSm,
            vertical: 2,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: DesktopTheme.spacingMd,
            vertical: DesktopTheme.spacingSm,
          ),
          decoration: BoxDecoration(
            color: _isHovered ? DesktopTheme.glassOverlay : Colors.transparent,
            borderRadius: BorderRadius.circular(DesktopTheme.radiusSm),
          ),
          child: Row(
            children: [
              // Playlist icon/image
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: DesktopTheme.backgroundElevated,
                ),
                clipBehavior: Clip.antiAlias,
                child: widget.playlist.imageUrl != null
                    ? buildSmartImage(
                        imageUrl: widget.playlist.imageUrl!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: () => const Icon(
                          Icons.queue_music_rounded,
                          size: 24,
                          color: DesktopTheme.textTertiary,
                        ),
                      )
                    : const Icon(
                        Icons.queue_music_rounded,
                        size: 24,
                        color: DesktopTheme.textTertiary,
                      ),
              ),
              const SizedBox(width: DesktopTheme.spacingMd),
              // Playlist info
              Expanded(
                child: Text(
                  widget.playlist.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: DesktopTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// DETAIL VIEW WIDGETS - Inline pages that keep sidebar visible
// =============================================================================

/// Album detail view - displayed inline within the layout
class _AlbumDetailView extends StatefulWidget {
  final Album album;
  final VoidCallback onBack;

  const _AlbumDetailView({required this.album, required this.onBack});

  @override
  State<_AlbumDetailView> createState() => _AlbumDetailViewState();
}

class _AlbumDetailViewState extends State<_AlbumDetailView> {
  List<Track> _tracks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    final appState = context.read<AppState>();
    setState(() => _isLoading = true);

    try {
      _tracks = await appState.getAlbumTracks(widget.album.id);
      _tracks.sort((a, b) {
        final aTrack = a.trackNumber ?? 999;
        final bTrack = b.trackNumber ?? 999;
        return aTrack.compareTo(bTrack);
      });
    } catch (e) {
      _tracks = [];
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _getImageUrl(AppState appState, String? imageId) {
    if (imageId == null) return null;
    return appState.getImageUrl(imageId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Consumer<AppState>(
      builder: (context, appState, _) {
        final imageUrl = _getImageUrl(appState, widget.album.imageUrl);

        return Container(
          color: DesktopTheme.backgroundPrimary,
          child: Column(
            children: [
              // Header with back button
              _DetailHeader(
                onBack: widget.onBack,
                title: widget.album.name,
                subtitle: widget.album.artistName,
                imageUrl: imageUrl,
                year: widget.album.year?.toString(),
                trackCount: _tracks.length,
                onPlay: () => appState.playPlaylist(_tracks, 0),
                onShuffle: () {
                  final shuffled = List<Track>.from(_tracks)..shuffle();
                  appState.playPlaylist(shuffled, 0);
                },
              ),
              // Track list
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _tracks.isEmpty
                    ? Center(
                        child: Text(
                          l10n.noTracksFound,
                          style: TextStyle(color: DesktopTheme.textSecondary),
                        ),
                      )
                    : _TrackListView(
                        tracks: _tracks,
                        appState: appState,
                        showTrackNumber: true,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Artist detail view - displayed inline within the layout
class _ArtistDetailView extends StatefulWidget {
  final Artist artist;
  final VoidCallback onBack;

  const _ArtistDetailView({required this.artist, required this.onBack});

  @override
  State<_ArtistDetailView> createState() => _ArtistDetailViewState();
}

class _ArtistDetailViewState extends State<_ArtistDetailView> {
  List<Album> _albums = [];
  List<Track> _tracks = [];
  bool _isLoading = true;
  String _selectedTab = 'albums';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final appState = context.read<AppState>();
    setState(() => _isLoading = true);

    try {
      _albums = appState.albums
          .where((album) => album.artistName == widget.artist.name)
          .toList();
      _albums.sort((a, b) {
        final aYear = a.year ?? 0;
        final bYear = b.year ?? 0;
        return bYear.compareTo(aYear);
      });

      _tracks = appState.tracks
          .where((track) => track.artistName == widget.artist.name)
          .toList();
    } catch (e) {
      _albums = [];
      _tracks = [];
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _getImageUrl(AppState appState, String? imageId) {
    if (imageId == null) return null;
    return appState.getImageUrl(imageId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final navigationService = NavigationService();

    return Consumer<AppState>(
      builder: (context, appState, _) {
        final imageUrl = _getImageUrl(appState, widget.artist.imageUrl);

        return Container(
          color: DesktopTheme.backgroundPrimary,
          child: Column(
            children: [
              // Header with back button
              _DetailHeader(
                onBack: widget.onBack,
                title: widget.artist.name,
                subtitle:
                    '${_albums.length} ${l10n.albums} • ${_tracks.length} ${l10n.songs}',
                imageUrl: imageUrl,
                isCircular: true,
                onPlay: () => appState.playPlaylist(_tracks, 0),
                onShuffle: () {
                  final shuffled = List<Track>.from(_tracks)..shuffle();
                  appState.playPlaylist(shuffled, 0);
                },
              ),
              // Tab selector
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesktopTheme.spacingLg,
                  vertical: DesktopTheme.spacingSm,
                ),
                child: Row(
                  children: [
                    _TabChip(
                      label: l10n.albums,
                      isSelected: _selectedTab == 'albums',
                      onTap: () => setState(() => _selectedTab = 'albums'),
                    ),
                    const SizedBox(width: DesktopTheme.spacingSm),
                    _TabChip(
                      label: l10n.songs,
                      isSelected: _selectedTab == 'songs',
                      onTap: () => setState(() => _selectedTab = 'songs'),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _selectedTab == 'albums'
                    ? _AlbumGridView(
                        albums: _albums,
                        appState: appState,
                        onAlbumTap: (album) =>
                            navigationService.navigateToAlbum(album),
                      )
                    : _TrackListView(tracks: _tracks, appState: appState),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Playlist detail view - displayed inline within the layout
class _PlaylistDetailView extends StatefulWidget {
  final Playlist playlist;
  final VoidCallback onBack;

  const _PlaylistDetailView({required this.playlist, required this.onBack});

  @override
  State<_PlaylistDetailView> createState() => _PlaylistDetailViewState();
}

class _PlaylistDetailViewState extends State<_PlaylistDetailView> {
  List<Track> _tracks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    final appState = context.read<AppState>();
    setState(() => _isLoading = true);

    try {
      _tracks = await appState.getPlaylistTracks(widget.playlist.id);
    } catch (e) {
      _tracks = [];
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _getImageUrl(AppState appState, String? imageId) {
    if (imageId == null) return null;
    return appState.getImageUrl(imageId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Consumer<AppState>(
      builder: (context, appState, _) {
        final imageUrl = _getImageUrl(appState, widget.playlist.imageUrl);

        return Container(
          color: DesktopTheme.backgroundPrimary,
          child: Column(
            children: [
              // Header with back button
              _DetailHeader(
                onBack: widget.onBack,
                title: widget.playlist.name,
                subtitle: '${_tracks.length} ${l10n.songs}',
                imageUrl: imageUrl,
                onPlay: () => appState.playPlaylist(_tracks, 0),
                onShuffle: () {
                  final shuffled = List<Track>.from(_tracks)..shuffle();
                  appState.playPlaylist(shuffled, 0);
                },
              ),
              // Track list
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _tracks.isEmpty
                    ? Center(
                        child: Text(
                          l10n.noTracksFound,
                          style: TextStyle(color: DesktopTheme.textSecondary),
                        ),
                      )
                    : _TrackListView(tracks: _tracks, appState: appState),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Shared detail header widget
class _DetailHeader extends StatelessWidget {
  final VoidCallback onBack;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String? year;
  final int? trackCount;
  final bool isCircular;
  final VoidCallback? onPlay;
  final VoidCallback? onShuffle;

  const _DetailHeader({
    required this.onBack,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.year,
    this.trackCount,
    this.isCircular = false,
    this.onPlay,
    this.onShuffle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(DesktopTheme.spacingLg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.primary.withOpacity(0.15),
            DesktopTheme.backgroundPrimary,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          DesktopIconButton(
            icon: Icons.arrow_back_rounded,
            onPressed: onBack,
            tooltip: l10n.back,
          ),
          const SizedBox(height: DesktopTheme.spacingMd),
          // Content row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Image
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    isCircular ? 90 : DesktopTheme.radiusMd,
                  ),
                  color: DesktopTheme.backgroundElevated,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: imageUrl != null
                    ? buildSmartImage(
                        imageUrl: imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: () => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
              const SizedBox(width: DesktopTheme.spacingLg),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: DesktopTheme.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: DesktopTheme.spacingSm),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 16,
                          color: DesktopTheme.textSecondary,
                        ),
                      ),
                    ],
                    if (year != null || trackCount != null) ...[
                      const SizedBox(height: DesktopTheme.spacingSm),
                      Text(
                        [
                          if (year != null) year,
                          if (trackCount != null) '$trackCount ${l10n.songs}',
                        ].join(' • '),
                        style: TextStyle(
                          fontSize: 14,
                          color: DesktopTheme.textTertiary,
                        ),
                      ),
                    ],
                    const SizedBox(height: DesktopTheme.spacingLg),
                    // Action buttons
                    Row(
                      children: [
                        if (onPlay != null)
                          DesktopPlayButton(
                            isPlaying: false,
                            onPressed: onPlay!,
                          ),
                        const SizedBox(width: DesktopTheme.spacingMd),
                        if (onShuffle != null)
                          DesktopGlassButton(
                            onPressed: onShuffle!,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.shuffle_rounded, size: 18),
                                const SizedBox(width: 8),
                                Text(l10n.shuffle),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: DesktopTheme.backgroundTertiary,
      child: Icon(
        isCircular ? Icons.person_rounded : Icons.album_rounded,
        size: 64,
        color: DesktopTheme.textTertiary,
      ),
    );
  }
}

/// Tab chip for switching between views
class _TabChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_TabChip> createState() => _TabChipState();
}

class _TabChipState extends State<_TabChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: DesktopTheme.durationFast,
          padding: const EdgeInsets.symmetric(
            horizontal: DesktopTheme.spacingMd,
            vertical: DesktopTheme.spacingSm,
          ),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? theme.colorScheme.primary
                : _isHovered
                ? DesktopTheme.glassOverlay
                : Colors.transparent,
            borderRadius: BorderRadius.circular(DesktopTheme.radiusRound),
            border: Border.all(
              color: widget.isSelected
                  ? Colors.transparent
                  : DesktopTheme.glassBorder,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: widget.isSelected
                  ? Colors.white
                  : DesktopTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Track list view widget
class _TrackListView extends StatelessWidget {
  final List<Track> tracks;
  final AppState appState;
  final bool showTrackNumber;

  const _TrackListView({
    required this.tracks,
    required this.appState,
    this.showTrackNumber = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: DesktopTheme.spacingLg,
        vertical: DesktopTheme.spacingSm,
      ),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        return _TrackRow(
          track: track,
          index: index,
          showTrackNumber: showTrackNumber,
          onTap: () => appState.playPlaylist(tracks, index),
          onAddToQueue: () => appState.addToQueue(track),
        );
      },
    );
  }
}

/// Single track row widget
class _TrackRow extends StatefulWidget {
  final Track track;
  final int index;
  final bool showTrackNumber;
  final VoidCallback onTap;
  final VoidCallback onAddToQueue;

  const _TrackRow({
    required this.track,
    required this.index,
    required this.showTrackNumber,
    required this.onTap,
    required this.onAddToQueue,
  });

  @override
  State<_TrackRow> createState() => _TrackRowState();
}

class _TrackRowState extends State<_TrackRow> {
  bool _isHovered = false;

  String _formatDuration(int? durationMs) {
    if (durationMs == null) return '--:--';
    final totalSeconds = durationMs ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _handleDownload(BuildContext context) async {
    final appState = context.read<AppState>();
    final downloadService = appState.downloadService;
    final isDownloaded = downloadService.isTrackDownloaded(widget.track.id);
    final status = downloadService.getDownloadStatus(widget.track.id);

    if (isDownloaded) {
      // Show options for downloaded track
      _showDownloadedOptions(context, appState);
      return;
    }

    if (status == DownloadStatus.downloading) {
      // Already downloading - show cancel option
      _showDownloadingOptions(context, appState);
      return;
    }

    // Start download
    try {
      await downloadService.downloadTrack(widget.track);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Started downloading "${widget.track.name}"'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start download: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showDownloadedOptions(BuildContext context, AppState appState) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Downloaded'),
        content: Text('"${widget.track.name}" is already downloaded.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.ok),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              appState.downloadService.deleteDownload(widget.track.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Deleted download for "${widget.track.name}"'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.deleteDownload),
          ),
        ],
      ),
    );
  }

  void _showDownloadingOptions(BuildContext context, AppState appState) {
    final l10n = AppLocalizations.of(context);
    final progress = appState.downloadService.getDownloadProgress(widget.track.id);
    final progressPercent = (progress * 100).toInt();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.downloading),
        content: Text('"${widget.track.name}" is downloading ($progressPercent%)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.ok),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              appState.downloadService.cancelDownload(widget.track.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Cancelled download for "${widget.track.name}"'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.cancelDownload),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final imageUrl = widget.track.imageUrl != null
        ? appState.getImageUrl(widget.track.imageUrl!)
        : null;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: DesktopTheme.durationFast,
          padding: const EdgeInsets.symmetric(
            horizontal: DesktopTheme.spacingMd,
            vertical: DesktopTheme.spacingSm,
          ),
          decoration: BoxDecoration(
            color: _isHovered ? DesktopTheme.glassOverlay : Colors.transparent,
            borderRadius: BorderRadius.circular(DesktopTheme.radiusSm),
          ),
          child: Row(
            children: [
              // Track number or play icon
              SizedBox(
                width: 40,
                child: Center(
                  child: _isHovered
                      ? const Icon(
                          Icons.play_arrow_rounded,
                          color: DesktopTheme.textPrimary,
                          size: 20,
                        )
                      : Text(
                          widget.showTrackNumber
                              ? '${widget.track.trackNumber ?? widget.index + 1}'
                              : '${widget.index + 1}',
                          style: TextStyle(
                            fontSize: 14,
                            color: DesktopTheme.textTertiary,
                          ),
                        ),
                ),
              ),
              // Album art
              Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(right: DesktopTheme.spacingMd),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: DesktopTheme.backgroundElevated,
                ),
                clipBehavior: Clip.antiAlias,
                child: imageUrl != null
                    ? buildSmartImage(
                        imageUrl: imageUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: () => const Icon(
                          Icons.music_note_rounded,
                          size: 20,
                          color: DesktopTheme.textTertiary,
                        ),
                      )
                    : const Icon(
                        Icons.music_note_rounded,
                        size: 20,
                        color: DesktopTheme.textTertiary,
                      ),
              ),
              // Track info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.track.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: DesktopTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.track.artistName ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: DesktopTheme.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Album name
              if (widget.track.albumName != null)
                Expanded(
                  child: Text(
                    widget.track.albumName!,
                    style: TextStyle(
                      fontSize: 14,
                      color: DesktopTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              // Duration
              SizedBox(
                width: 60,
                child: Text(
                  _formatDuration(widget.track.duration),
                  style: TextStyle(
                    fontSize: 14,
                    color: DesktopTheme.textTertiary,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              // More button
              if (_isHovered)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: DesktopTheme.textSecondary,
                    size: 20,
                  ),
                  onSelected: (value) {
                    if (value == 'queue') {
                      widget.onAddToQueue();
                    } else if (value == 'playlist') {
                      DesktopLayout.showAddToPlaylistDialog(
                        context,
                        widget.track,
                      );
                    } else if (value == 'download') {
                      _handleDownload(context);
                    }
                  },
                  itemBuilder: (context) {
                    final l10n = AppLocalizations.of(context);
                    final appState = context.read<AppState>();
                    final downloadService = appState.downloadService;
                    final isDownloaded = downloadService.isTrackDownloaded(widget.track.id);
                    final status = downloadService.getDownloadStatus(widget.track.id);
                    final isDownloading = status == DownloadStatus.downloading;

                    IconData downloadIcon;
                    String downloadLabel;
                    if (isDownloaded) {
                      downloadIcon = Icons.download_done_rounded;
                      downloadLabel = 'Downloaded';
                    } else if (isDownloading) {
                      downloadIcon = Icons.downloading_rounded;
                      downloadLabel = l10n.downloading;
                    } else {
                      downloadIcon = Icons.download_rounded;
                      downloadLabel = l10n.download;
                    }

                    return [
                      PopupMenuItem(
                        value: 'queue',
                        child: Row(
                          children: [
                            const Icon(Icons.queue_music_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text(l10n.addToQueue),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'playlist',
                        child: Row(
                          children: [
                            const Icon(Icons.playlist_add_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text(l10n.addToPlaylist),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'download',
                        child: Row(
                          children: [
                            Icon(downloadIcon, size: 20),
                            const SizedBox(width: 8),
                            Text(downloadLabel),
                          ],
                        ),
                      ),
                    ];
                  },
                )
              else
                const SizedBox(width: 40),
            ],
          ),
        ),
      ),
    );
  }
}

/// Album grid view widget
class _AlbumGridView extends StatelessWidget {
  final List<Album> albums;
  final AppState appState;
  final Function(Album) onAlbumTap;

  const _AlbumGridView({
    required this.albums,
    required this.appState,
    required this.onAlbumTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minCardWidth = 160.0;
        final crossAxisCount = (constraints.maxWidth / minCardWidth)
            .floor()
            .clamp(2, 6);

        return GridView.builder(
          padding: const EdgeInsets.all(DesktopTheme.spacingLg),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.8,
            crossAxisSpacing: DesktopTheme.spacingMd,
            mainAxisSpacing: DesktopTheme.spacingMd,
          ),
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            return _AlbumCard(
              album: album,
              imageUrl: album.imageUrl != null
                  ? appState.getImageUrl(album.imageUrl!)
                  : null,
              onTap: () => onAlbumTap(album),
            );
          },
        );
      },
    );
  }
}

/// Album card widget
class _AlbumCard extends StatefulWidget {
  final Album album;
  final String? imageUrl;
  final VoidCallback onTap;

  const _AlbumCard({
    required this.album,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  State<_AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<_AlbumCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: _isHovered
                ? DesktopTheme.backgroundElevated
                : DesktopTheme.backgroundSecondary,
            borderRadius: BorderRadius.circular(DesktopTheme.radiusMd),
          ),
          padding: const EdgeInsets.all(DesktopTheme.spacingSm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Album art
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          DesktopTheme.radiusSm,
                        ),
                        color: DesktopTheme.backgroundTertiary,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: widget.imageUrl != null
                          ? buildSmartImage(
                              imageUrl: widget.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: () => const Center(
                                child: Icon(
                                  Icons.album_rounded,
                                  size: 48,
                                  color: DesktopTheme.textTertiary,
                                ),
                              ),
                            )
                          : const Center(
                              child: Icon(
                                Icons.album_rounded,
                                size: 48,
                                color: DesktopTheme.textTertiary,
                              ),
                            ),
                    ),
                    // Play button overlay
                    if (_isHovered)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: DesktopTheme.spacingSm),
              // Album name
              Text(
                widget.album.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: DesktopTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // Artist name
              Text(
                widget.album.artistName ?? '',
                style: TextStyle(
                  fontSize: 12,
                  color: DesktopTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
