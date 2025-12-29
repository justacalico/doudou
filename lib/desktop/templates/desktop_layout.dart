import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
import '../../services/audio/unified_audio_handler.dart';
import '../services/navigation_service.dart';
import '../pages/home.dart';
import '../pages/search.dart';
import '../pages/library.dart';
import '../pages/albums.dart';
import '../pages/artists.dart';
import '../pages/tracks.dart';
import '../pages/playlists.dart';
import '../pages/settings.dart';
import 'desktop_theme.dart';

/// Modern Desktop Layout - Spotify-inspired design
/// Optimized for performance with efficient widget rebuilds
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
      _navigateToPage(newIndex);
    }
  }

  void _onDetailPageChange() {
    // Trigger rebuild when detail page stack changes
    setState(() {});
  }

  void _navigateToPage(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    _pageController.jumpToPage(index);
    _navigationService.selectedPageIndex.value = index;
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
  ];

  List<Widget> get _pages => const [
    HomePage(),
    SearchPage(),
    LibraryPage(),
    AlbumsPage(),
    ArtistsPage(),
    TracksPage(),
    PlaylistsPage(),
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
                    onSettingsTap: () => _navigateToPage(7),
                  ),
                  // Page content
                  Expanded(
                    child: ClipRect(
                      child: detailPage ?? PageView(
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

          const Spacer(),

          // Settings
          _SidebarItem(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings_rounded,
            label: l10n.settings,
            isSelected: currentIndex == 7,
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
                  Expanded(flex: 1, child: _TrackInfo(mediaItem: mediaItem)),
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
              mediaItem: mediaItem,
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

  const _TrackInfo({required this.mediaItem});

  @override
  Widget build(BuildContext context) {
    if (mediaItem == null) {
      return const SizedBox.shrink();
    }

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
              ? Image.network(
                  mediaItem!.artUri.toString(),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildPlaceholder(),
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
          icon: Icons.favorite_border_rounded,
          tooltip: 'Add to favorites',
          onPressed: () {},
        ),
      ],
    );
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

  @override
  void initState() {
    super.initState();
    _volume = widget.audioHandler?.volume ?? 1.0;
    widget.audioHandler?.volumeStream?.listen((vol) {
      if (mounted) setState(() => _volume = vol);
    });
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
  final MediaItem? mediaItem;
  final AppState appState;
  final dynamic audioHandler;

  const _NowPlayingOverlay({
    required this.mediaItem,
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
      setState(() => _selectedTab = _tabController.index);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background with album art blur
          if (widget.mediaItem?.artUri != null)
            Positioned.fill(
              child: Image.network(
                widget.mediaItem!.artUri.toString(),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
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
                          mediaItem: widget.mediaItem,
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
                            color: DesktopTheme.backgroundDeep.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(
                              DesktopTheme.radiusMd,
                            ),
                            border: Border.all(color: DesktopTheme.glassBorder),
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
                                      onTap: () => _tabController.animateTo(0),
                                    ),
                                    const SizedBox(
                                      width: DesktopTheme.spacingMd,
                                    ),
                                    _TabButton(
                                      label: l10n.lyrics,
                                      isSelected: _selectedTab == 1,
                                      onTap: () => _tabController.animateTo(1),
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
                                        color: DesktopTheme.textTertiary,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        widget.mediaItem?.album ??
                                            l10n.unknownAlbum,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: DesktopTheme.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: DesktopTheme.spacingSm),
                              // Tab content
                              Expanded(
                                child: TabBarView(
                                  controller: _tabController,
                                  children: [
                                    _QueueList(
                                      appState: widget.appState,
                                      audioHandler: widget.audioHandler,
                                    ),
                                    _LyricsView(mediaItem: widget.mediaItem),
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

  @override
  Widget build(BuildContext context) {
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
                      ? Image.network(
                          mediaItem!.artUri.toString(),
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
          Text(
            mediaItem?.artist ?? '',
            style: TextStyle(fontSize: 16, color: DesktopTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DesktopTheme.spacingXl),
          // Progress
          _NowPlayingProgress(audioHandler: audioHandler),
          const SizedBox(height: DesktopTheme.spacingLg),
          // Controls
          _NowPlayingControls(appState: appState, audioHandler: audioHandler),
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

  const _NowPlayingControls({
    required this.appState,
    required this.audioHandler,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                    ? Image.network(
                        widget.track.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
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
                    ? Image.network(
                        widget.playlist.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
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
