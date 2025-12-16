// ignore_for_file: unused_element_parameter

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import '../../l10n/app_localizations.dart';
import '../pages/home.dart';
import '../services/navigation_service.dart';
import '../../providers/app_state.dart';
import '../pages/albums.dart';
import '../pages/playlists.dart';
import '../pages/artists.dart';
import '../pages/search.dart';
import '../pages/library.dart';
import '../pages/tracks.dart';
import '../pages/settings.dart';
import '../../services/desktop_lyrics_service.dart';
import '../../models/jellyfin_models.dart';
import '../../services/audio/base_audio_handler.dart' as base_handler;
import '../../widgets/apple_design/apple_theme.dart';
import 'desktop_theme.dart';

class DesktopLayout extends StatefulWidget {
  final Widget? child;
  final int? selectedIndex;
  final VoidCallback? onNavigationChanged;
  final bool showBackButton;
  final String? title;
  final Function(int)? onMainPageNavigation;

  const DesktopLayout({
    super.key,
    this.child,
    this.selectedIndex,
    this.onNavigationChanged,
    this.showBackButton = false,
    this.title,
    this.onMainPageNavigation,
  });

  @override
  State<DesktopLayout> createState() => _DesktopLayoutState();

  /// Shows a dialog to add a track to a playlist
  static Future<void> showAddToPlaylistDialog(
    BuildContext context,
    Track track,
  ) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        final l10n = AppLocalizations.of(context);
        return Consumer<AppState>(
          builder: (context, appState, child) {
            return _AddToPlaylistDialog(
              track: track,
              playlists: appState.playlists,
              onAddToPlaylist: (playlistId) async {
                final success = await appState.addToPlaylist(
                  playlistId,
                  track.id,
                );
                if (context.mounted) {
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.addedTrackToPlaylist(track.name)),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.failedToAddTrackToPlaylist),
                      ),
                    );
                  }
                }
              },
            );
          },
        );
      },
    );
  }
}

class _DesktopLayoutState extends State<DesktopLayout> {
  int _selectedIndex = 0;
  final NavigationService _navigationService = NavigationService();

  List<String> _getNavigationItems(AppLocalizations l10n) => [
    l10n.navHome,
    l10n.navSearch,
    l10n.navLibrary,
    l10n.navTracks,
    l10n.navPlaylists,
    l10n.navAlbums,
    l10n.navArtists,
    l10n.navSettings,
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex ?? 0;
  }

  @override
  void didUpdateWidget(DesktopLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != null &&
        widget.selectedIndex != _selectedIndex) {
      setState(() {
        _selectedIndex = widget.selectedIndex!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final navigationItems = _getNavigationItems(l10n);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: DesktopTheme.backgroundDeep,
      body: Stack(
        children: [
          // Animated gradient background
          _buildAnimatedBackground(theme),
          
          // Main layout
          Column(
            children: [
              // Main content area with sidebar
              Expanded(
                child: Row(
                  children: [
                    // Modern Left Sidebar
                    _buildModernSidebar(theme, l10n, navigationItems, isDark),

                    // Main content area with glass effect
                    Expanded(
                      child: _buildMainContentArea(isDark),
                    ),
                  ],
                ),
              ),

              // Modern Bottom Player Bar
              _buildModernBottomPlayerBar(theme, l10n, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground(ThemeData theme) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final audioHandler = appState.audioHandler;
        
        return StreamBuilder<MediaItem?>(
          stream: audioHandler?.mediaItem,
          builder: (context, snapshot) {
            final currentTrack = snapshot.data;
            
            return AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    DesktopTheme.backgroundDeep,
                    currentTrack != null
                        ? theme.colorScheme.primary.withOpacity(0.08)
                        : const Color(0xFF0D0A18),
                    currentTrack != null
                        ? theme.colorScheme.secondary.withOpacity(0.05)
                        : const Color(0xFF0A0D18),
                    DesktopTheme.backgroundDeep,
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModernSidebar(
    ThemeData theme,
    AppLocalizations l10n,
    List<String> navigationItems,
    bool isDark,
  ) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: DesktopTheme.blurHeavy,
          sigmaY: DesktopTheme.blurHeavy,
        ),
        child: Container(
          width: DesktopTheme.sidebarWidth,
          decoration: BoxDecoration(
            color: DesktopTheme.backgroundSecondary.withOpacity(0.7),
            border: Border(
              right: BorderSide(
                color: DesktopTheme.glassBorder,
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              // Logo and app title
              _buildSidebarHeader(theme, l10n),
              
              // Navigation sections
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    vertical: DesktopTheme.spacingMd,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Main navigation
                      _buildNavSection(
                        theme,
                        l10n.navHome,
                        [
                          _buildNavItem(0, Icons.home_rounded, Icons.home_rounded, navigationItems[0], theme),
                          _buildNavItem(1, Icons.search_rounded, Icons.search_rounded, navigationItems[1], theme),
                        ],
                      ),
                      
                      const SizedBox(height: DesktopTheme.spacingLg),
                      
                      // Library section
                      _buildNavSection(
                        theme,
                        l10n.navLibrary,
                        [
                          _buildNavItem(2, Icons.library_music_outlined, Icons.library_music_rounded, navigationItems[2], theme),
                          _buildNavItem(3, Icons.music_note_outlined, Icons.music_note_rounded, navigationItems[3], theme),
                          _buildNavItem(4, Icons.queue_music_outlined, Icons.queue_music_rounded, navigationItems[4], theme),
                          _buildNavItem(5, Icons.album_outlined, Icons.album_rounded, navigationItems[5], theme),
                          _buildNavItem(6, Icons.person_outline_rounded, Icons.person_rounded, navigationItems[6], theme),
                        ],
                      ),
                      
                      const SizedBox(height: DesktopTheme.spacingLg),
                      
                      // Settings
                      _buildNavSection(
                        theme,
                        null,
                        [
                          _buildNavItem(7, Icons.settings_outlined, Icons.settings_rounded, navigationItems[7], theme),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // User info / quick actions
              _buildSidebarFooter(theme, l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarHeader(ThemeData theme, AppLocalizations l10n) {
    return Container(
      height: DesktopTheme.headerHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: DesktopTheme.spacingMd,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: DesktopTheme.glassBorder,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          if (widget.showBackButton) ...[
            DesktopIconButton(
              icon: Icons.arrow_back_rounded,
              onPressed: () => Navigator.pop(context),
              tooltip: l10n.back,
            ),
            const SizedBox(width: DesktopTheme.spacingSm),
          ],
          // App logo with gradient
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DesktopTheme.radiusMd),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withOpacity(0.7),
                ],
              ),
              boxShadow: DesktopTheme.shadowGlow(theme.colorScheme.primary),
            ),
            child: const Icon(
              Icons.music_note_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: DesktopTheme.spacingMd),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title ?? 'Doudou',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: DesktopTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Music Player',
                  style: TextStyle(
                    fontSize: 12,
                    color: DesktopTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavSection(ThemeData theme, String? title, List<Widget> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DesktopTheme.spacingSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.only(
                left: DesktopTheme.spacingMd,
                bottom: DesktopTheme.spacingSm,
              ),
              child: Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: DesktopTheme.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
          ...items,
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData selectedIcon, String label, ThemeData theme) {
    final currentSelectedIndex = widget.selectedIndex ?? _selectedIndex;
    final isSelected = index == currentSelectedIndex;
    
    return DesktopNavItem(
      icon: icon,
      selectedIcon: selectedIcon,
      label: label,
      isSelected: isSelected,
      accentColor: theme.colorScheme.primary,
      onTap: () {
        if (widget.child != null && widget.showBackButton) {
          Navigator.popUntil(context, (route) => route.isFirst);
          _navigationService.navigateToMainPage(index);
        } else {
          setState(() {
            _selectedIndex = index;
          });
          _navigationService.selectPage(index);
          widget.onNavigationChanged?.call();
        }
      },
    );
  }

  Widget _buildSidebarFooter(ThemeData theme, AppLocalizations l10n) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Container(
          padding: const EdgeInsets.all(DesktopTheme.spacingMd),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: DesktopTheme.glassBorder,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // User avatar
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(DesktopTheme.radiusSm),
                  color: DesktopTheme.backgroundElevated,
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: DesktopTheme.textSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: DesktopTheme.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      appState.jellyfinService.currentServer?.username ?? 'User',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: DesktopTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      l10n.countSongs(appState.tracks.length),
                      style: TextStyle(
                        fontSize: 11,
                        color: DesktopTheme.textTertiary,
                      ),
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

  Widget _buildMainContentArea(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: DesktopTheme.backgroundPrimary.withOpacity(0.5),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: DesktopTheme.blurLight,
            sigmaY: DesktopTheme.blurLight,
          ),
          child: widget.child ?? _buildMainContent(),
        ),
      ),
    );
  }

  Widget _buildModernBottomPlayerBar(ThemeData theme, AppLocalizations l10n, bool isDark) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final audioHandler = appState.audioHandler;

        return StreamBuilder<PlaybackState>(
          stream: audioHandler?.playbackState,
          builder: (context, playbackSnapshot) {
            return StreamBuilder<MediaItem?>(
              stream: audioHandler?.mediaItem,
              builder: (context, mediaSnapshot) {
                final currentTrack = mediaSnapshot.data;

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

                        return ClipRRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: DesktopTheme.blurHeavy,
                              sigmaY: DesktopTheme.blurHeavy,
                            ),
                            child: Container(
                              height: DesktopTheme.playerBarHeight,
                              decoration: BoxDecoration(
                                color: DesktopTheme.backgroundSecondary.withOpacity(0.85),
                                border: Border(
                                  top: BorderSide(
                                    color: DesktopTheme.glassBorder,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Column(
                                children: [
                                  // Progress bar at top
                                  _buildProgressBar(
                                    theme,
                                    progress,
                                    currentTrack,
                                    audioHandler,
                                    duration,
                                  ),

                                  // Main player content
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: DesktopTheme.spacingLg,
                                      ),
                                      child: Row(
                                        children: [
                                          // Track info (left)
                                          Expanded(
                                            flex: 3,
                                            child: _buildTrackInfo(
                                              theme,
                                              l10n,
                                              currentTrack,
                                              appState,
                                            ),
                                          ),

                                          // Player controls (center)
                                          Expanded(
                                            flex: 4,
                                            child: _buildPlayerControls(
                                              theme,
                                              l10n,
                                              appState,
                                              audioHandler,
                                              currentTrack,
                                              position,
                                              duration,
                                            ),
                                          ),

                                          // Right side controls
                                          Expanded(
                                            flex: 3,
                                            child: _buildRightControls(
                                              theme,
                                              l10n,
                                              appState,
                                              audioHandler,
                                              currentTrack,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
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

  Widget _buildProgressBar(
    ThemeData theme,
    double progress,
    MediaItem? currentTrack,
    dynamic audioHandler,
    Duration duration,
  ) {
    return SizedBox(
      height: 4,
      child: Stack(
        children: [
          // Background
          Container(
            color: DesktopTheme.backgroundElevated,
          ),
          // Progress
          AnimatedFractionallySizedBox(
            duration: DesktopTheme.durationFast,
            widthFactor: progress.clamp(0.0, 1.0),
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withOpacity(0.8),
                  ],
                ),
              ),
            ),
          ),
          // Interaction layer
          Positioned.fill(
            child: GestureDetector(
              onTapDown: currentTrack != null && audioHandler != null
                  ? (details) {
                      final box = context.findRenderObject() as RenderBox?;
                      if (box != null) {
                        final width = box.size.width;
                        final tapPosition = details.localPosition.dx;
                        final newProgress = (tapPosition / width).clamp(0.0, 1.0);
                        final newPosition = Duration(
                          milliseconds: (newProgress * duration.inMilliseconds).round(),
                        );
                        audioHandler.seek(newPosition);
                      }
                    }
                  : null,
              child: MouseRegion(
                cursor: currentTrack != null
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.basic,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackInfo(
    ThemeData theme,
    AppLocalizations l10n,
    MediaItem? currentTrack,
    AppState appState,
  ) {
    return GestureDetector(
      onTap: currentTrack != null
          ? () => _showNowPlayingDialog(context)
          : null,
      child: MouseRegion(
        cursor: currentTrack != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: Row(
          children: [
            // Album art
            _buildAlbumArt(currentTrack, theme),
            
            const SizedBox(width: DesktopTheme.spacingMd),
            
            // Track details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    currentTrack?.title ?? l10n.noTrackPlaying,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: DesktopTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    currentTrack?.artist ?? l10n.selectSongToPlay,
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
            
            // Favorite button
            if (currentTrack != null)
              _buildFavoriteButton(theme, l10n, currentTrack, appState),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumArt(MediaItem? currentTrack, ThemeData theme) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DesktopTheme.radiusSm),
        color: DesktopTheme.backgroundElevated,
        boxShadow: DesktopTheme.shadowMd,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DesktopTheme.radiusSm),
        child: currentTrack?.artUri != null
            ? Image.network(
                currentTrack!.artUri.toString(),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildAlbumArtPlaceholder(theme);
                },
              )
            : _buildAlbumArtPlaceholder(theme),
      ),
    );
  }

  Widget _buildAlbumArtPlaceholder(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            DesktopTheme.backgroundElevated,
            DesktopTheme.backgroundTertiary,
          ],
        ),
      ),
      child: Icon(
        Icons.music_note_rounded,
        color: DesktopTheme.textMuted,
        size: 24,
      ),
    );
  }

  Widget _buildFavoriteButton(
    ThemeData theme,
    AppLocalizations l10n,
    MediaItem currentTrack,
    AppState appState,
  ) {
    final trackInState = appState.tracks.firstWhere(
      (t) => t.id == currentTrack.id,
      orElse: () => Track(
        id: currentTrack.id,
        name: currentTrack.title,
        albumName: currentTrack.album,
        artistName: currentTrack.artist,
        albumId: currentTrack.extras?['albumId'] as String? ?? '',
        duration: currentTrack.duration?.inSeconds ?? 0,
        trackNumber: null,
        imageUrl: null,
        isFavorite: false,
      ),
    );

    final isFavorite = trackInState.isFavorite;

    return DesktopIconButton(
      icon: isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      onPressed: () => appState.toggleFavorite(trackInState),
      isActive: isFavorite,
      activeColor: DesktopTheme.heartRed,
      tooltip: isFavorite ? l10n.removeFromFavorites : l10n.addToFavorites,
    );
  }

  Widget _buildPlayerControls(
    ThemeData theme,
    AppLocalizations l10n,
    AppState appState,
    dynamic audioHandler,
    MediaItem? currentTrack,
    Duration position,
    Duration duration,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Main controls row
        StreamBuilder<PlaybackState>(
          stream: audioHandler?.playbackState,
          builder: (context, playbackSnapshot) {
            final playbackState = playbackSnapshot.data;
            final isPlaying = playbackState?.playing == true;
            final isBuffering = playbackState?.processingState ==
                AudioProcessingState.buffering;
            final isShuffled = audioHandler?.isShuffled ?? false;
            final repeatMode = audioHandler?.repeatMode ?? base_handler.RepeatMode.none;

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Shuffle
                DesktopIconButton(
                  icon: Icons.shuffle_rounded,
                  onPressed: audioHandler != null
                      ? () => audioHandler.setShuffleMode(!isShuffled)
                      : null,
                  isActive: isShuffled,
                  size: 18,
                ),
                
                const SizedBox(width: DesktopTheme.spacingMd),
                
                // Previous
                DesktopIconButton(
                  icon: Icons.skip_previous_rounded,
                  onPressed: audioHandler != null && audioHandler.hasPrevious
                      ? () => appState.skipToPrevious()
                      : null,
                  size: 24,
                ),
                
                const SizedBox(width: DesktopTheme.spacingSm),
                
                // Play/Pause
                DesktopPlayButton(
                  isPlaying: isPlaying,
                  isBuffering: isBuffering,
                  onPressed: audioHandler != null && currentTrack != null && !isBuffering
                      ? () => appState.playPause()
                      : null,
                  accentColor: theme.colorScheme.primary,
                  size: 48,
                ),
                
                const SizedBox(width: DesktopTheme.spacingSm),
                
                // Next
                DesktopIconButton(
                  icon: Icons.skip_next_rounded,
                  onPressed: audioHandler != null && audioHandler.hasNext
                      ? () => appState.skipToNext()
                      : null,
                  size: 24,
                ),
                
                const SizedBox(width: DesktopTheme.spacingMd),
                
                // Repeat
                DesktopIconButton(
                  icon: repeatMode == base_handler.RepeatMode.one
                      ? Icons.repeat_one_rounded
                      : Icons.repeat_rounded,
                  onPressed: audioHandler != null
                      ? () {
                          switch (repeatMode) {
                            case base_handler.RepeatMode.none:
                              audioHandler.setRepeatMode(base_handler.RepeatMode.all);
                              break;
                            case base_handler.RepeatMode.all:
                              audioHandler.setRepeatMode(base_handler.RepeatMode.one);
                              break;
                            case base_handler.RepeatMode.one:
                              audioHandler.setRepeatMode(base_handler.RepeatMode.none);
                              break;
                          }
                        }
                      : null,
                  isActive: repeatMode != base_handler.RepeatMode.none,
                  size: 18,
                ),
              ],
            );
          },
        ),
        
        const SizedBox(height: DesktopTheme.spacingXs),
        
        // Time display
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _formatDuration(position),
              style: TextStyle(
                fontSize: 11,
                color: DesktopTheme.textTertiary,
                fontFamily: 'monospace',
              ),
            ),
            Text(
              ' / ',
              style: TextStyle(
                fontSize: 11,
                color: DesktopTheme.textMuted,
              ),
            ),
            Text(
              _formatDuration(duration),
              style: TextStyle(
                fontSize: 11,
                color: DesktopTheme.textTertiary,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRightControls(
    ThemeData theme,
    AppLocalizations l10n,
    AppState appState,
    dynamic audioHandler,
    MediaItem? currentTrack,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Volume control
        StreamBuilder<double>(
          stream: audioHandler?.volumeStream,
          builder: (context, volumeSnapshot) {
            final currentVolume = volumeSnapshot.data ?? 1.0;

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DesktopIconButton(
                  icon: currentVolume == 0.0
                      ? Icons.volume_off_rounded
                      : currentVolume < 0.5
                          ? Icons.volume_down_rounded
                          : Icons.volume_up_rounded,
                  onPressed: () {
                    if (audioHandler != null) {
                      audioHandler.setVolume(currentVolume == 0.0 ? 1.0 : 0.0);
                    }
                  },
                  size: 18,
                ),
                const SizedBox(width: DesktopTheme.spacingSm),
                SizedBox(
                  width: 100,
                  child: DesktopProgressSlider(
                    value: currentVolume,
                    onChanged: audioHandler != null
                        ? (value) => audioHandler.setVolume(value)
                        : null,
                    activeColor: theme.colorScheme.primary,
                  ),
                ),
              ],
            );
          },
        ),
        
        const SizedBox(width: DesktopTheme.spacingLg),
        
        // Queue button
        DesktopIconButton(
          icon: Icons.queue_music_rounded,
          onPressed: () => _showNowPlayingDialog(context),
          tooltip: l10n.queue,
        ),
        
        const SizedBox(width: DesktopTheme.spacingSm),
        
        // Expand button
        DesktopIconButton(
          icon: Icons.open_in_full_rounded,
          onPressed: () => _showNowPlayingDialog(context),
          tooltip: l10n.nowPlaying,
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    switch (_selectedIndex) {
      case 0:
        return const HomePage();
      case 1:
        return const SearchPage();
      case 2:
        return const LibraryPage();
      case 3:
        return const TracksPage();
      case 4:
        return const PlaylistsPage();
      case 5:
        return const AlbumsPage();
      case 6:
        return const ArtistsPage();
      case 7:
        return const SettingsPage();
      default:
        return const HomePage();
    }
  }

  void _showNowPlayingDialog(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        fullscreenDialog: true,
        pageBuilder: (context, animation, secondaryAnimation) =>
            _ModernNowPlaying(navigationService: _navigationService),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: animation.drive(
              Tween(
                begin: const Offset(0.0, 1.0),
                end: Offset.zero,
              ).chain(CurveTween(curve: Curves.easeOutCubic)),
            ),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return '${duration.inHours}:$twoDigitMinutes:$twoDigitSeconds';
    } else {
      return '$twoDigitMinutes:$twoDigitSeconds';
    }
  }
}

// Modern Now Playing Screen with liquid glass styling
class _ModernNowPlaying extends StatefulWidget {
  final NavigationService navigationService;

  const _ModernNowPlaying({required this.navigationService});

  @override
  State<_ModernNowPlaying> createState() =>
      _ModernNowPlayingState();
}

class _ModernNowPlayingState extends State<_ModernNowPlaying>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showLyrics = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Request focus after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event, AppState appState, MediaItem? currentTrack) {
    if (event is! KeyDownEvent) return;

    final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

    // Shift+N - Skip to next song
    if (isShiftPressed && event.logicalKey == LogicalKeyboardKey.keyN) {
      appState.skipToNext();
      return;
    }

    // Space - Play/Pause
    if (event.logicalKey == LogicalKeyboardKey.space) {
      appState.playPause();
      return;
    }

    // F - Toggle favorite
    if (event.logicalKey == LogicalKeyboardKey.keyF && currentTrack != null) {
      final trackInState = appState.tracks.firstWhere(
        (t) => t.id == currentTrack.id,
        orElse: () => Track(
          id: currentTrack.id,
          name: currentTrack.title,
          albumName: currentTrack.album,
          artistName: currentTrack.artist,
          albumId: currentTrack.extras?['albumId'] as String? ?? '',
          duration: currentTrack.duration?.inSeconds ?? 0,
          trackNumber: null,
          imageUrl: null,
          isFavorite: false,
        ),
      );
      appState.toggleFavorite(trackInState);
      return;
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return '${duration.inHours}:$twoDigitMinutes:$twoDigitSeconds';
    } else {
      return '$twoDigitMinutes:$twoDigitSeconds';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final audioHandler = appState.audioHandler;

        return StreamBuilder<MediaItem?>(
          stream: audioHandler?.mediaItem,
          builder: (context, mediaItemSnapshot) {
            final currentTrack = mediaItemSnapshot.data;

            return KeyboardListener(
              focusNode: _focusNode,
              autofocus: true,
              onKeyEvent: (event) => _handleKeyEvent(event, appState, currentTrack),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Hide sidebar when width is less than 700px
                  final showSidebar = constraints.maxWidth >= 700;
                  
                  return Scaffold(
                    backgroundColor: DesktopTheme.backgroundDeep,
                    body: Row(
                      children: [
                        // Main content area (left side - like YouTube Music video area)
                        Expanded(
                          flex: 3,
                          child: Stack(
                            children: [
                              // Background with album art blur
                              if (currentTrack?.artUri != null)
                                Positioned.fill(
                                  child: Image.network(
                                    currentTrack!.artUri.toString(),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: DesktopTheme.backgroundDeep,
                                    );
                                  },
                                ),
                              ),

                        // Dark overlay gradient
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  DesktopTheme.backgroundDeep.withOpacity(0.3),
                                  DesktopTheme.backgroundDeep.withOpacity(0.7),
                                  DesktopTheme.backgroundDeep.withOpacity(0.95),
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            ),
                          ),
                        ),

                        // Main content
                        Column(
                          children: [
                            // Top bar with close button and Song/Video toggle
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  // Close button
                                  DesktopIconButton(
                                    icon: Icons.keyboard_arrow_down_rounded,
                                    onPressed: () => Navigator.pop(context),
                                    size: 28,
                                  ),

                                  const Spacer(),

                                  // More options button
                                  DesktopIconButton(
                                    icon: Icons.more_vert_rounded,
                                    onPressed: () {
                                      // Show options menu
                                    },
                                  ),
                                ],
                              ),
                            ),

                            // Center content area
                            Expanded(
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Album art or lyrics
                                    if (_showLyrics)
                                      Expanded(
                                        child: _YouTubeMusicLyrics(
                                          audioHandler: audioHandler,
                                          queue: appState.queue,
                                          currentIndex: audioHandler?.currentIndex,
                                        ),
                                      )
                                    else
                                      Expanded(
                                        child: Center(
                                          child: _buildAlbumArt(currentTrack),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            // Track info and controls at bottom
                            _buildBottomSection(
                              context,
                              appState,
                              audioHandler,
                              currentTrack,
                              AppLocalizations.of(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Right sidebar - Up Next queue (like YouTube Music)
                  // Animated slide in/out based on window width
                  AnimatedSlide(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    offset: showSidebar ? Offset.zero : const Offset(1, 0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      width: showSidebar ? 350 : 0,
                      child: showSidebar
                          ? Container(
                              width: 350,
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: DesktopTheme.glassBorder,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Stack(
                                children: [
                                  // Background image fading from left (flipped horizontally)
                                  if (currentTrack?.artUri != null)
                                    Positioned.fill(
                                      child: ShaderMask(
                                        shaderCallback: (Rect bounds) {
                                          return LinearGradient(
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                            colors: [
                                              Colors.white.withOpacity(0.3),
                                              Colors.white.withOpacity(0.1),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.3, 0.7],
                                ).createShader(bounds);
                              },
                              blendMode: BlendMode.dstIn,
                              child: Transform.flip(
                                flipX: true,
                                child: Image.network(
                                  currentTrack!.artUri.toString(),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ),
                            ),
                          ),

                        // Dark overlay for readability
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  DesktopTheme.glassSurface.withOpacity(0.7),
                                  DesktopTheme.glassSurface.withOpacity(0.95),
                                  DesktopTheme.glassSurface,
                                ],
                                stops: const [0.0, 0.4, 1.0],
                              ),
                            ),
                          ),
                        ),

                        // Content
                        Column(
                          children: [
                            // Tabs header
                            Container(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  _buildSidebarTab(AppLocalizations.of(context).upNext, 0),
                                  const SizedBox(width: 24),
                                  _buildSidebarTab(AppLocalizations.of(context).lyrics, 1),
                                ],
                              ),
                            ),

                            // Playing from indicator
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  Text(
                                    AppLocalizations.of(context).playingFrom,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 12,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      currentTrack?.album ?? AppLocalizations.of(context).unknownAlbum,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Content based on selected tab
                            Expanded(
                              child: TabBarView(
                                controller: _tabController,
                                children: [
                                  // UP NEXT tab - Queue list
                                  _buildQueueList(appState, audioHandler),
                                  // LYRICS tab
                                  _buildSidebarLyrics(audioHandler),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
              );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSidebarTab(String label, int index) {
    final isSelected = _tabController.index == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _tabController.animateTo(index);
        });
      },
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: isSelected ? DesktopTheme.textPrimary : DesktopTheme.textTertiary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          if (isSelected)
            Container(
              width: label.length * 6.0,
              height: 2,
              decoration: BoxDecoration(
                gradient: DesktopTheme.accentGradient,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAlbumArt(MediaItem? currentTrack) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 400),
      margin: const EdgeInsets.all(32),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 40,
                spreadRadius: 8,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: currentTrack?.artUri != null
                ? Image.network(
                    currentTrack!.artUri.toString(),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildPlaceholderArt();
                    },
                  )
                : _buildPlaceholderArt(),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderArt() {
    return Container(
      color: const Color(0xFF282828),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 100,
          color: Colors.white.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _buildBottomSection(
    BuildContext context,
    AppState appState,
    dynamic audioHandler,
    MediaItem? currentTrack,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        children: [
          // Track info row
          Row(
            children: [
              // Track details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.youAreListeningTo,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentTrack?.title ?? l10n.noTrackPlaying,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          l10n.byArtist,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 14,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            currentTrack?.artist ?? l10n.unknownArtist,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          l10n.fromAlbum,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 14,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            currentTrack?.album ?? l10n.unknownAlbum,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action buttons
              Row(
                children: [
                  // Favorite/Like button
                  Consumer<AppState>(
                    builder: (context, appState, child) {
                      if (currentTrack == null) {
                        return const SizedBox.shrink();
                      }
                      final trackInState = appState.tracks.firstWhere(
                        (t) => t.id == currentTrack.id,
                        orElse: () => Track(
                          id: currentTrack.id,
                          name: currentTrack.title,
                          albumName: currentTrack.album,
                          artistName: currentTrack.artist,
                          albumId:
                              currentTrack.extras?['albumId'] as String? ?? '',
                          duration: currentTrack.duration?.inSeconds ?? 0,
                          trackNumber: null,
                          imageUrl: null,
                          isFavorite: false,
                        ),
                      );
                      final isFavorite = trackInState.isFavorite;

                      return IconButton(
                        onPressed: () => appState.toggleFavorite(trackInState),
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                        ),
                        color: isFavorite
                            ? Colors.red
                            : Colors.white.withOpacity(0.7),
                        iconSize: 24,
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  // Lyrics toggle
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showLyrics = !_showLyrics;
                      });
                    },
                    icon: Icon(
                      _showLyrics ? Icons.lyrics : Icons.lyrics_outlined,
                    ),
                    color: _showLyrics
                        ? Colors.white
                        : Colors.white.withOpacity(0.7),
                    iconSize: 24,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Progress bar
          StreamBuilder<Duration>(
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
                      // Progress slider
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12,
                          ),
                          activeTrackColor: Colors.white,
                          inactiveTrackColor: Colors.white.withOpacity(0.2),
                          thumbColor: Colors.white,
                          overlayColor: Colors.white.withOpacity(0.2),
                        ),
                        child: Slider(
                          value: progress.clamp(0.0, 1.0),
                          onChanged:
                              currentTrack != null && audioHandler != null
                              ? (value) {
                                  final newPosition = Duration(
                                    milliseconds:
                                        (value * duration.inMilliseconds)
                                            .round(),
                                  );
                                  audioHandler.seek(newPosition);
                                }
                              : null,
                          min: 0.0,
                          max: 1.0,
                        ),
                      ),

                      // Time labels
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(position),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                            Text(
                              _formatDuration(duration),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                                fontFamily: 'monospace',
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
          ),

          const SizedBox(height: 8),

          // Playback controls
          StreamBuilder<PlaybackState>(
            stream: audioHandler?.playbackState,
            builder: (context, playbackSnapshot) {
              final playbackState = playbackSnapshot.data;
              final isPlaying = playbackState?.playing == true;
              final isBuffering =
                  playbackState?.processingState ==
                  AudioProcessingState.buffering;
              // Use the audioHandler's direct properties for shuffle/repeat state
              final isShuffled = audioHandler?.isShuffled ?? false;
              final repeatMode = audioHandler?.repeatMode ?? base_handler.RepeatMode.none;

              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Shuffle
                  IconButton(
                    onPressed: audioHandler != null
                        ? () => audioHandler.setShuffleMode(!isShuffled)
                        : null,
                    icon: const Icon(Icons.shuffle_rounded),
                    color: isShuffled
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                    iconSize: 24,
                  ),

                  const SizedBox(width: 16),

                  // Previous
                  IconButton(
                    onPressed: audioHandler != null && audioHandler.hasPrevious
                        ? () => appState.skipToPrevious()
                        : null,
                    icon: const Icon(Icons.skip_previous_rounded),
                    color: audioHandler?.hasPrevious == true
                        ? Colors.white
                        : Colors.white.withOpacity(0.3),
                    iconSize: 36,
                  ),

                  const SizedBox(width: 16),

                  // Play/Pause
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(32),
                        onTap: audioHandler != null && currentTrack != null
                            ? () => appState.playPause()
                            : null,
                        child: Center(
                          child: isBuffering
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : Icon(
                                  isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.black,
                                  size: 36,
                                ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Next
                  IconButton(
                    onPressed: audioHandler != null && audioHandler.hasNext
                        ? () => appState.skipToNext()
                        : null,
                    icon: const Icon(Icons.skip_next_rounded),
                    color: audioHandler?.hasNext == true
                        ? Colors.white
                        : Colors.white.withOpacity(0.3),
                    iconSize: 36,
                  ),

                  const SizedBox(width: 16),

                  // Repeat
                  IconButton(
                    onPressed: audioHandler != null
                        ? () {
                            switch (repeatMode) {
                              case base_handler.RepeatMode.none:
                                audioHandler.setRepeatMode(
                                  base_handler.RepeatMode.all,
                                );
                                break;
                              case base_handler.RepeatMode.all:
                                audioHandler.setRepeatMode(
                                  base_handler.RepeatMode.one,
                                );
                                break;
                              case base_handler.RepeatMode.one:
                                audioHandler.setRepeatMode(
                                  base_handler.RepeatMode.none,
                                );
                                break;
                            }
                          }
                        : null,
                    icon: Icon(
                      repeatMode == base_handler.RepeatMode.one
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                    ),
                    color: repeatMode != base_handler.RepeatMode.none
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                    iconSize: 24,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQueueList(AppState appState, dynamic audioHandler) {
    final queue = appState.queue;

    if (queue.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.queue_music,
              size: 48,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No songs in queue',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<MediaItem?>(
      stream: audioHandler?.mediaItem,
      builder: (context, mediaSnapshot) {
        final currentMediaItem = mediaSnapshot.data;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          itemCount: queue.length,
          itemBuilder: (context, index) {
            final track = queue[index];
            final isCurrentTrack = currentMediaItem?.id == track.id;

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: isCurrentTrack
                    ? Colors.white.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                leading: Stack(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF282828),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: track.imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                appState.getImageUrl(track.imageUrl!),
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.music_note,
                                    color: Colors.white.withOpacity(0.3),
                                    size: 24,
                                  );
                                },
                              ),
                            )
                          : Icon(
                              Icons.music_note,
                              color: Colors.white.withOpacity(0.3),
                              size: 24,
                            ),
                    ),
                    if (isCurrentTrack)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                title: Text(
                  track.name,
                  style: TextStyle(
                    color: isCurrentTrack
                        ? Colors.white
                        : Colors.white.withOpacity(0.9),
                    fontWeight: isCurrentTrack
                        ? FontWeight.w600
                        : FontWeight.normal,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  track.artistName ?? 'Unknown Artist',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  _formatDuration(Duration(seconds: track.duration ?? 0)),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                onTap: () {
                  appState.skipToIndex(index);
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSidebarLyrics(dynamic audioHandler) {
    final appState = Provider.of<AppState>(context, listen: false);
    return _YouTubeMusicLyrics(
      audioHandler: audioHandler,
      queue: appState.queue,
      currentIndex: audioHandler?.currentIndex,
    );
  }
}

// Global lyrics cache for preloading
class _LyricsCache {
  static final Map<String, Future<DesktopLyrics?>> _cache = {};

  static Future<DesktopLyrics?> getLyrics({
    required String trackId,
    required String trackName,
    required String artistName,
    String? albumName,
    int? durationSeconds,
  }) {
    if (_cache.containsKey(trackId)) {
      return _cache[trackId]!;
    }

    final future = DesktopLyricsService.fetchLyrics(
      trackName: trackName,
      artistName: artistName,
      albumName: albumName,
      durationSeconds: durationSeconds,
    );
    _cache[trackId] = future;

    // Limit cache size to prevent memory issues
    if (_cache.length > 10) {
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
    }

    return future;
  }

  static void preloadLyrics({
    required String trackId,
    required String trackName,
    required String artistName,
    String? albumName,
    int? durationSeconds,
  }) {
    if (!_cache.containsKey(trackId)) {
      _cache[trackId] = DesktopLyricsService.fetchLyrics(
        trackName: trackName,
        artistName: artistName,
        albumName: albumName,
        durationSeconds: durationSeconds,
      );
    }
  }
}

// YouTube Music-style Lyrics Widget
class _YouTubeMusicLyrics extends StatefulWidget {
  final dynamic audioHandler;
  final List<Track>? queue;
  final int? currentIndex;

  const _YouTubeMusicLyrics({
    required this.audioHandler,
    this.queue,
    this.currentIndex,
  });

  @override
  State<_YouTubeMusicLyrics> createState() => _YouTubeMusicLyricsState();
}

class _YouTubeMusicLyricsState extends State<_YouTubeMusicLyrics> {
  String? _cachedTrackId;
  Future<DesktopLyrics?>? _cachedLyricsFuture;
  final ScrollController _scrollController = ScrollController();
  int _previousCurrentLine = -1;

  void _preloadNextTrackLyrics() {
    final queue = widget.queue;
    final currentIndex = widget.currentIndex;
    
    if (queue == null || currentIndex == null) return;
    
    // Preload next track's lyrics
    final nextIndex = currentIndex + 1;
    if (nextIndex < queue.length) {
      final nextTrack = queue[nextIndex];
      _LyricsCache.preloadLyrics(
        trackId: nextTrack.id,
        trackName: nextTrack.name,
        artistName: nextTrack.artistName ?? 'Unknown Artist',
        albumName: nextTrack.albumName,
        durationSeconds: nextTrack.duration,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int _getCurrentLyricLineIndex(
    List<DesktopLyricsLine> lines,
    Duration position,
  ) {
    if (lines.isEmpty) return -1;

    for (int i = lines.length - 1; i >= 0; i--) {
      if (position >= lines[i].time) {
        return i;
      }
    }
    return -1;
  }

  void _scrollToCurrentLine(int currentLineIndex) {
    if (currentLineIndex >= 0 &&
        currentLineIndex != _previousCurrentLine &&
        _scrollController.hasClients) {
      _previousCurrentLine = currentLineIndex;

      const itemHeight = 60.0;
      final targetOffset =
          (currentLineIndex * itemHeight) -
          (_scrollController.position.viewportDimension / 2) +
          (itemHeight / 2);

      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: widget.audioHandler?.mediaItem,
      builder: (context, snapshot) {
        final currentTrack = snapshot.data;

        if (currentTrack == null) {
          return _buildEmptyState('No track playing');
        }

        final trackId = currentTrack.id;

        if (_cachedTrackId != trackId) {
          _cachedTrackId = trackId;
          _previousCurrentLine = -1;
          // Use the global cache for lyrics
          _cachedLyricsFuture = _LyricsCache.getLyrics(
            trackId: trackId,
            trackName: currentTrack.title,
            artistName: currentTrack.artist ?? 'Unknown Artist',
            albumName: currentTrack.album,
            durationSeconds: currentTrack.duration?.inSeconds,
          );
          // Preload next track's lyrics
          _preloadNextTrackLyrics();
        }

        return FutureBuilder<DesktopLyrics?>(
          future: _cachedLyricsFuture,
          builder: (context, lyricsSnapshot) {
            if (lyricsSnapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingState();
            }

            final lyrics = lyricsSnapshot.data;
            if (lyrics == null) {
              return _buildEmptyState('Lyrics not found');
            }

            if (lyrics.isTimeSynced && lyrics.syncedLines.isNotEmpty) {
              return _buildSyncedLyrics(lyrics.syncedLines);
            }

            if (lyrics.plainText != null) {
              return _buildPlainLyrics(lyrics.plainText!);
            }

            return _buildEmptyState('No lyrics available');
          },
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 16),
          Text(
            'Loading lyrics...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lyrics_outlined,
            size: 64,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlainLyrics(String lyrics) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Text(
        lyrics,
        style: TextStyle(
          color: Colors.white.withOpacity(0.8),
          fontSize: 20,
          height: 1.8,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildSyncedLyrics(List<DesktopLyricsLine> lines) {
    return StreamBuilder<Duration>(
      stream: widget.audioHandler?.positionStream,
      builder: (context, positionSnapshot) {
        final position = positionSnapshot.data ?? Duration.zero;
        final currentLineIndex = _getCurrentLyricLineIndex(lines, position);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToCurrentLine(currentLineIndex);
        });

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          itemCount: lines.length,
          itemBuilder: (context, index) {
            final line = lines[index];
            final isCurrentLine = index == currentLineIndex;
            final isPastLine = index < currentLineIndex;

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                line.text,
                style: TextStyle(
                  color: isCurrentLine
                      ? Colors.white
                      : isPastLine
                      ? Colors.white.withOpacity(0.4)
                      : Colors.white.withOpacity(0.6),
                  fontSize: isCurrentLine ? 28 : 22,
                  fontWeight: isCurrentLine
                      ? FontWeight.bold
                      : FontWeight.normal,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            );
          },
        );
      },
    );
  }
}

class _NowPlayingTabs extends StatefulWidget {
  final dynamic audioHandler;

  const _NowPlayingTabs({required this.audioHandler});

  @override
  State<_NowPlayingTabs> createState() => _NowPlayingTabsState();
}

class _NowPlayingTabsState extends State<_NowPlayingTabs>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  StreamSubscription<MediaItem?>? _mediaItemSubscription;

  // Cache for lyrics to prevent constant reloading
  String? _cachedTrackId;
  Future<DesktopLyrics?>? _cachedLyricsFuture;

  @override
  void initState() {
    super.initState();
    // Always start with lyrics tab (index 0) as the default
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);

    // Listen to track changes and automatically switch to lyrics tab
    _mediaItemSubscription = widget.audioHandler?.mediaItem?.listen((
      mediaItem,
    ) {
      if (mediaItem != null && mounted && _tabController.index != 0) {
        // Switch to lyrics tab when a new track starts
        _tabController.animateTo(0);
      }
    });
  }

  @override
  void dispose() {
    _mediaItemSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Tab bar
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: theme.colorScheme.onPrimary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.normal,
              ),
              tabs: [
                Tab(
                  text: 'Lyrics',
                  icon: Stack(
                    children: [
                      const Icon(Icons.lyrics),
                      // Add a small indicator dot to show this is the primary tab
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                  iconMargin: const EdgeInsets.only(bottom: 4),
                ),
                Tab(
                  text: 'Queue',
                  icon: const Icon(Icons.queue_music),
                  iconMargin: const EdgeInsets.only(bottom: 4),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildLyricsTab(), _buildQueueTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsTab() {
    return StreamBuilder<MediaItem?>(
      stream: widget.audioHandler?.mediaItem,
      builder: (context, snapshot) {
        final currentTrack = snapshot.data;

        if (currentTrack == null) {
          // Reset cache when no track is playing
          _cachedTrackId = null;
          _cachedLyricsFuture = null;
          return _buildLyricsEmptyState('No track playing');
        }

        // Use track ID as cache key (fallback to title if ID not available)
        final trackId = currentTrack.id;

        // Only fetch lyrics if the track has changed
        if (_cachedTrackId != trackId) {
          _cachedTrackId = trackId;
          _cachedLyricsFuture = DesktopLyricsService.fetchLyrics(
            trackName: currentTrack.title,
            artistName: currentTrack.artist ?? 'Unknown Artist',
            albumName: currentTrack.album,
            durationSeconds: currentTrack.duration?.inSeconds,
          );
        }

        return FutureBuilder<DesktopLyrics?>(
          future: _cachedLyricsFuture,
          builder: (context, lyricsSnapshot) {
            if (lyricsSnapshot.connectionState == ConnectionState.waiting) {
              return _buildLyricsLoadingState();
            }

            final lyrics = lyricsSnapshot.data;
            if (lyrics == null) {
              return _buildLyricsEmptyState('Lyrics not found');
            }

            // Show synced lyrics if available
            if (lyrics.isTimeSynced && lyrics.syncedLines.isNotEmpty) {
              return _buildSyncedLyricsView(lyrics.syncedLines);
            }

            // Fall back to plain lyrics
            if (lyrics.plainText != null) {
              return _buildPlainLyricsView(lyrics.plainText!);
            }

            return _buildLyricsEmptyState('No lyrics available');
          },
        );
      },
    );
  }

  Widget _buildLyricsLoadingState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading lyrics...',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lyrics,
            size: 64,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lyrics powered by LRCLib.net • Desktop Enhanced',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPlainLyricsView(String lyrics) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.lyrics,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Lyrics',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Lyrics content
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                lyrics,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncedLyricsView(List<DesktopLyricsLine> lyricsLines) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.lyrics,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Synced Lyrics',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'LIVE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Synced lyrics content
          Expanded(
            child: _SyncedLyricsContent(
              audioHandler: widget.audioHandler,
              lyricsLines: lyricsLines,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueTab() {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final queue = appState.queue;
        final audioHandler = appState.audioHandler;

        if (queue.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.queue_music,
                  size: 64,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No songs in queue',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add songs to your queue to see them here',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: StreamBuilder<MediaItem?>(
            stream: audioHandler?.mediaItem,
            builder: (context, mediaSnapshot) {
              final currentMediaItem = mediaSnapshot.data;

              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: queue.length,
                itemBuilder: (context, index) {
                  final track = queue[index];
                  final isCurrentTrack = currentMediaItem?.id == track.id;

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: isCurrentTrack
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.1)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      border: isCurrentTrack
                          ? Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.3),
                            )
                          : null,
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: track.imageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(
                                  appState.getImageUrl(track.imageUrl!),
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.music_note,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      size: 20,
                                    );
                                  },
                                ),
                              )
                            : Icon(
                                Icons.music_note,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                size: 20,
                              ),
                      ),
                      title: Text(
                        track.name,
                        style: TextStyle(
                          color: isCurrentTrack
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: isCurrentTrack
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${track.artistName} • ${track.albumName}',
                        style: TextStyle(
                          color: isCurrentTrack
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.7)
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: isCurrentTrack
                          ? Icon(
                              Icons.play_arrow,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: () {
                        // Play the selected track
                        appState.skipToIndex(index);
                      },
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _SyncedLyricsContent extends StatefulWidget {
  final dynamic audioHandler;
  final List<DesktopLyricsLine> lyricsLines;

  const _SyncedLyricsContent({
    required this.audioHandler,
    required this.lyricsLines,
  });

  @override
  State<_SyncedLyricsContent> createState() => _SyncedLyricsContentState();
}

class _SyncedLyricsContentState extends State<_SyncedLyricsContent> {
  final ScrollController _scrollController = ScrollController();
  int _previousCurrentLine = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int _getCurrentLyricLineIndex(
    List<DesktopLyricsLine> lines,
    Duration position,
  ) {
    if (lines.isEmpty) return -1;

    for (int i = lines.length - 1; i >= 0; i--) {
      if (position >= lines[i].time) {
        return i;
      }
    }

    return -1; // Before first line
  }

  void _scrollToCurrentLine(int currentLineIndex) {
    if (currentLineIndex >= 0 &&
        currentLineIndex != _previousCurrentLine &&
        _scrollController.hasClients) {
      _previousCurrentLine = currentLineIndex;

      // Calculate the position to scroll to (center the current line)
      const itemHeight = 56.0; // Approximate height of each lyrics line item
      final targetOffset =
          (currentLineIndex * itemHeight) -
          (_scrollController.position.viewportDimension / 2) +
          (itemHeight / 2);

      // Animate to the target position
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: widget.audioHandler?.positionStream,
      builder: (context, positionSnapshot) {
        final position = positionSnapshot.data ?? Duration.zero;
        final currentLineIndex = _getCurrentLyricLineIndex(
          widget.lyricsLines,
          position,
        );

        // Auto-scroll to current line
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToCurrentLine(currentLineIndex);
        });

        return ListView.builder(
          controller: _scrollController,
          itemCount: widget.lyricsLines.length,
          itemBuilder: (context, index) {
            final line = widget.lyricsLines[index];
            final isCurrentLine = index == currentLineIndex;
            final isPastLine = index < currentLineIndex;

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isCurrentLine
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                    : null,
                borderRadius: BorderRadius.circular(8),
                border: isCurrentLine
                    ? Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.3),
                      )
                    : null,
              ),
              child: Text(
                line.text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isCurrentLine
                      ? Theme.of(context).colorScheme.primary
                      : isPastLine
                      ? Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withOpacity(0.6)
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: isCurrentLine
                      ? FontWeight.w600
                      : FontWeight.normal,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            );
          },
        );
      },
    );
  }
}

class AnimatedDialog extends StatefulWidget {
  final Widget child;

  const AnimatedDialog({super.key, required this.child});

  @override
  State<AnimatedDialog> createState() => _AnimatedDialogState();
}

class _AnimatedDialogState extends State<AnimatedDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> closeDialog() async {
    await _controller.reverse();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await closeDialog();
        return false;
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}

class _AddToPlaylistDialog extends StatefulWidget {
  final Track track;
  final List<Playlist> playlists;
  final Function(String playlistId) onAddToPlaylist;

  const _AddToPlaylistDialog({
    required this.track,
    required this.playlists,
    required this.onAddToPlaylist,
  });

  @override
  State<_AddToPlaylistDialog> createState() => _AddToPlaylistDialogState();
}

class _AddToPlaylistDialogState extends State<_AddToPlaylistDialog> {
  String? _selectedPlaylistId;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.playlist_add),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Add to Playlist', style: theme.textTheme.titleLarge),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Track info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.music_note,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.track.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${widget.track.artistName} • ${widget.track.albumName}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Playlist selection
            Text('Select Playlist:', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),

            if (widget.playlists.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.playlist_remove,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'No playlists available',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = widget.playlists[index];
                    final isSelected = _selectedPlaylistId == playlist.id;

                    return ListTile(
                      dense: true,
                      leading: Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      title: Text(playlist.name),
                      subtitle: Text('${playlist.trackCount} tracks'),
                      selected: isSelected,
                      selectedTileColor: theme.colorScheme.primary.withOpacity(
                        0.1,
                      ),
                      onTap: () {
                        setState(() {
                          _selectedPlaylistId = playlist.id;
                        });
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed:
              _isLoading ||
                  _selectedPlaylistId == null ||
                  widget.playlists.isEmpty
              ? null
              : () async {
                  setState(() {
                    _isLoading = true;
                  });

                  await widget.onAddToPlaylist(_selectedPlaylistId!);

                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add to Playlist'),
        ),
      ],
    );
  }
}

// ============================================
// APPLE-STYLED HELPER WIDGETS
// ============================================

/// Apple-style sidebar navigation item with hover effects
class _AppleSidebarNavigationItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isDark;
  final Color primaryColor;
  final VoidCallback onTap;

  const _AppleSidebarNavigationItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  State<_AppleSidebarNavigationItem> createState() =>
      _AppleSidebarNavigationItemState();
}

class _AppleSidebarNavigationItemState
    extends State<_AppleSidebarNavigationItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppleDesignSystem.durationFast,
          curve: AppleDesignSystem.springCurve,
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(
            horizontal: AppleDesignSystem.spacing12,
            vertical: AppleDesignSystem.spacing8,
          ),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.primaryColor.withOpacity(widget.isDark ? 0.24 : 0.12)
                : _isHovering
                    ? (widget.isDark
                        ? AppleColors.fillPrimaryDark
                        : AppleColors.fillPrimary)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(AppleDesignSystem.radiusSmall),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: widget.isSelected
                    ? widget.primaryColor
                    : widget.isDark
                        ? AppleColors.labelSecondaryDark
                        : AppleColors.labelSecondary,
                size: 20,
              ),
              const SizedBox(width: AppleDesignSystem.spacing12),
              Expanded(
                child: Text(
                  widget.label,
                  style: AppleTextStyles.subheadline(
                    color: widget.isSelected
                        ? widget.primaryColor
                        : widget.isDark
                            ? AppleColors.labelPrimaryDark
                            : AppleColors.labelPrimary,
                  ).copyWith(
                    fontWeight: widget.isSelected
                        ? AppleDesignSystem.weightSemiBold
                        : AppleDesignSystem.weightRegular,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Apple-style icon button with hover and press effects
class _AppleIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isDark;
  final Color? color;
  final String? tooltip;
  final double size;

  const _AppleIconButton({
    required this.icon,
    this.onPressed,
    required this.isDark,
    this.color,
    this.tooltip,
    this.size = 20, // ignore: unused_element
  });

  @override
  State<_AppleIconButton> createState() => _AppleIconButtonState();
}

class _AppleIconButtonState extends State<_AppleIconButton> {
  bool _isHovering = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null;
    final iconColor = widget.color ??
        (isDisabled
            ? (widget.isDark
                ? AppleColors.labelTertiaryDark
                : AppleColors.labelTertiary)
            : (widget.isDark
                ? AppleColors.labelSecondaryDark
                : AppleColors.labelSecondary));

    final button = MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: AppleDesignSystem.durationFast,
          curve: AppleDesignSystem.springCurve,
          padding: const EdgeInsets.all(AppleDesignSystem.spacing8),
          decoration: BoxDecoration(
            color: _isPressed
                ? (widget.isDark
                    ? AppleColors.fillSecondaryDark
                    : AppleColors.fillSecondary)
                : _isHovering
                    ? (widget.isDark
                        ? AppleColors.fillTertiaryDark
                        : AppleColors.fillTertiary)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(AppleDesignSystem.radiusSmall),
          ),
          child: AnimatedScale(
            scale: _isPressed ? AppleDesignSystem.pressScale : 1.0,
            duration: AppleDesignSystem.durationFast,
            curve: AppleDesignSystem.interactiveCurve,
            child: Icon(
              widget.icon,
              color: iconColor,
              size: widget.size,
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip!,
        child: button,
      );
    }

    return button;
  }
}

/// Apple-style album art with hover effect
class _AppleAlbumArt extends StatefulWidget {
  final String? imageUrl;
  final VoidCallback? onTap;
  final bool isDark;
  final double size;

  const _AppleAlbumArt({
    this.imageUrl,
    this.onTap,
    required this.isDark,
    this.size = 56, // ignore: unused_element
  });

  @override
  State<_AppleAlbumArt> createState() => _AppleAlbumArtState();
}

class _AppleAlbumArtState extends State<_AppleAlbumArt> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppleDesignSystem.durationFast,
          curve: AppleDesignSystem.springCurve,
          transform: Matrix4.identity()
            ..scale(_isHovering ? 1.02 : 1.0),
          transformAlignment: Alignment.center,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.isDark
                  ? AppleColors.elevatedSecondaryDark
                  : AppleColors.systemGray6,
              borderRadius: BorderRadius.circular(AppleDesignSystem.radiusMedium),
              boxShadow: AppleDesignSystem.shadowMedium(Colors.black),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppleDesignSystem.radiusMedium),
              child: widget.imageUrl != null
                  ? Image.network(
                      widget.imageUrl!,
                      width: widget.size,
                      height: widget.size,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholder();
                      },
                    )
                  : _buildPlaceholder(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Icon(
      Icons.music_note_rounded,
      color: widget.isDark
          ? AppleColors.labelTertiaryDark
          : AppleColors.labelTertiary,
      size: widget.size * 0.5,
    );
  }
}

/// Apple-style play button with spring animation
class _ApplePlayButton extends StatefulWidget {
  final bool isPlaying;
  final bool isBuffering;
  final Color primaryColor;
  final bool isDark;
  final VoidCallback? onPressed;

  const _ApplePlayButton({
    required this.isPlaying,
    required this.isBuffering,
    required this.primaryColor,
    required this.isDark,
    this.onPressed,
  });

  @override
  State<_ApplePlayButton> createState() => _ApplePlayButtonState();
}

class _ApplePlayButtonState extends State<_ApplePlayButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppleDesignSystem.durationFast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: AppleDesignSystem.pressScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppleDesignSystem.interactiveCurve,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed == null) return;
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onPressed == null) return;
    _controller.reverse();
  }

  void _handleTapCancel() {
    if (widget.onPressed == null) return;
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onPressed,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedContainer(
              duration: AppleDesignSystem.durationFast,
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: widget.onPressed == null
                    ? (widget.isDark
                        ? AppleColors.systemGray4Dark
                        : AppleColors.systemGray4)
                    : widget.primaryColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: widget.primaryColor.withOpacity(
                      widget.onPressed == null ? 0 : 0.3,
                    ),
                    offset: const Offset(0, 4),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: widget.isBuffering
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : Icon(
                      widget.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
            ),
          );
        },
      ),
    );
  }
}
