import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../templates/page_template.dart';
import '../templates/music_cards.dart';
import '../templates/desktop_theme.dart';
import '../../../providers/app_state.dart';
import '../services/navigation_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      // Load library data when page loads
      appState.loadLibraryData();
    });
  }

  String? _getImageUrl(AppState appState, String? imageId) {
    if (imageId == null) return null;
    // Use the jellyfinService's image URL construction logic
    return appState.getImageUrl(imageId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Consumer<AppState>(
      builder: (context, appState, child) {
        return PageTemplate(
          title: l10n.navHome,
          subtitle: _getGreeting(l10n),
          showGradientHeader: true,
          actions: [
            DesktopGlassButton(
              onPressed: () => appState.loadLibraryData(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.refresh_rounded, size: 18),
                  const SizedBox(width: DesktopTheme.spacingSm),
                  Text(l10n.refresh),
                ],
              ),
            ),
          ],
          child: appState.isLoading
              ? _buildLoadingState(theme)
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: DesktopTheme.spacingMd),

                      // Quick access cards
                      _buildQuickAccessSection(context, appState, l10n),

                      const SizedBox(height: DesktopTheme.spacingXl),

                      // Recently Added Albums
                      if (appState.albums.isNotEmpty) ...[
                        SectionHeader(
                          title: l10n.recentlyAddedAlbums,
                          subtitle: l10n.yourNewestAdditions,
                          useGradient: true,
                          onSeeAllPressed: () {},
                        ),
                        const SizedBox(height: DesktopTheme.spacingMd),
                        _buildAlbumRow(context, appState, l10n),

                        const SizedBox(height: DesktopTheme.spacingXl),
                      ],

                      // Your Artists
                      if (appState.artists.isNotEmpty) ...[
                        SectionHeader(
                          title: l10n.yourArtists,
                          subtitle: l10n.browseByArtist,
                          onSeeAllPressed: () {},
                        ),
                        const SizedBox(height: DesktopTheme.spacingMd),
                        _buildArtistRow(context, appState, l10n),

                        const SizedBox(height: DesktopTheme.spacingXl),
                      ],

                      // Recent Tracks
                      if (appState.tracks.isNotEmpty) ...[
                        SectionHeader(
                          title: l10n.recentTracks,
                          subtitle: l10n.yourMusicCollection,
                        ),
                        const SizedBox(height: DesktopTheme.spacingMd),
                        _buildRecentTracksList(context, appState, l10n),
                      ],

                      // Extra space for bottom player
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
        );
      },
    );
  }

  String _getGreeting(AppLocalizations l10n) {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: DesktopTheme.spacingMd),
          Text(
            'Loading your music...',
            style: TextStyle(fontSize: 16, color: DesktopTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessSection(
    BuildContext context,
    AppState appState,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: QuickAccessCard(
            title: l10n.likedSongs,
            subtitle: l10n.countSongs(
              appState.tracks.where((t) => t.isFavorite).length,
            ),
            icon: Icons.favorite_rounded,
            color: DesktopTheme.heartRed,
            onTap: () {
              // Navigate to favorites
            },
          ),
        ),
        const SizedBox(width: DesktopTheme.spacingMd),
        Expanded(
          child: QuickAccessCard(
            title: l10n.allAlbums,
            subtitle: l10n.countAlbums(appState.albums.length),
            icon: Icons.album_rounded,
            color: theme.colorScheme.primary,
            onTap: () {
              // Navigate to albums
            },
          ),
        ),
        const SizedBox(width: DesktopTheme.spacingMd),
        Expanded(
          child: QuickAccessCard(
            title: l10n.allArtists,
            subtitle: l10n.countArtists(appState.artists.length),
            icon: Icons.person_rounded,
            color: DesktopTheme.shufflePurple,
            onTap: () {
              // Navigate to artists
            },
          ),
        ),
        const SizedBox(width: DesktopTheme.spacingMd),
        Expanded(
          child: QuickAccessCard(
            title: 'Shuffle All',
            subtitle: 'Play random songs',
            icon: Icons.shuffle_rounded,
            color: DesktopTheme.playButtonGreen,
            onTap: () {
              appState.shuffleAllTracks();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAlbumRow(
    BuildContext context,
    AppState appState,
    AppLocalizations l10n,
  ) {
    return SizedBox(
      height: 230,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: appState.albums.length > 10 ? 10 : appState.albums.length,
        itemBuilder: (context, index) {
          final album = appState.albums[index];
          return Padding(
            padding: EdgeInsets.only(
              right: index < 9 ? DesktopTheme.spacingMd : 0,
            ),
            child: MusicCard(
              title: album.name,
              subtitle: album.artistName ?? l10n.unknownArtist,
              imageUrl: _getImageUrl(appState, album.imageUrl),
              size: 180,
              onTap: () {
                NavigationService().navigateToAlbum(album);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildArtistRow(
    BuildContext context,
    AppState appState,
    AppLocalizations l10n,
  ) {
    return SizedBox(
      height: 230,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: appState.artists.length > 10 ? 10 : appState.artists.length,
        itemBuilder: (context, index) {
          final artist = appState.artists[index];
          return Padding(
            padding: EdgeInsets.only(
              right: index < 9 ? DesktopTheme.spacingMd : 0,
            ),
            child: MusicCard(
              title: artist.name,
              subtitle: l10n.artist,
              imageUrl: _getImageUrl(appState, artist.imageUrl),
              size: 180,
              onTap: () {
                NavigationService().navigateToArtist(artist);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentTracksList(
    BuildContext context,
    AppState appState,
    AppLocalizations l10n,
  ) {
    return Column(
      children: appState.tracks
          .take(8)
          .map(
            (track) => Padding(
              padding: const EdgeInsets.only(bottom: DesktopTheme.spacingSm),
              child: MusicListTile(
                title: track.name,
                subtitle:
                    '${track.artistName ?? l10n.unknownArtist} • ${track.albumName ?? l10n.unknownAlbum}',
                imageUrl: _getImageUrl(appState, track.imageUrl),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (track.duration != null)
                      Text(
                        _formatDuration(track.duration!),
                        style: TextStyle(
                          fontSize: 12,
                          color: DesktopTheme.textTertiary,
                          fontFamily: 'monospace',
                        ),
                      ),
                    const SizedBox(width: DesktopTheme.spacingSm),
                    DesktopIconButton(
                      icon: Icons.more_horiz_rounded,
                      onPressed: () {},
                      size: 18,
                    ),
                  ],
                ),
                onTap: () {
                  // Play track
                  final trackIndex = appState.tracks.indexOf(track);
                  appState.playPlaylist(appState.tracks, trackIndex);
                },
              ),
            ),
          )
          .toList(),
    );
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
