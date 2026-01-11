import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'detail_screen.dart';
import 'all_albums_screen.dart';
import 'all_artists_screen.dart';
import 'all_songs_screen.dart';
import 'favorites_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return CupertinoPageScaffold(
          backgroundColor: AppTheme.background(context),
          child: CustomScrollView(
            slivers: [
              // Navigation bar
              CupertinoSliverNavigationBar(
                largeTitle: const Text('Library'),
                backgroundColor: AppTheme.background(context),
                border: null,
              ),

              // Library sections
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingL),
                  child: Column(
                    children: [
                      _LibrarySection(
                        icon: CupertinoIcons.music_note_list,
                        title: 'Playlists',
                        count: appState.playlists.length,
                        onTap: () => _navigateToPlaylists(context),
                      ),
                      _LibrarySection(
                        icon: CupertinoIcons.person_2_fill,
                        title: 'Artists',
                        count: appState.artists.length,
                        onTap: () => _navigateToArtists(context),
                      ),
                      _LibrarySection(
                        icon: CupertinoIcons.square_stack_fill,
                        title: 'Albums',
                        count: appState.albums.length,
                        onTap: () => _navigateToAlbums(context),
                      ),
                      _LibrarySection(
                        icon: CupertinoIcons.music_note,
                        title: 'Songs',
                        count: appState.tracks.length,
                        onTap: () => _navigateToSongs(context),
                      ),
                      _LibrarySection(
                        icon: CupertinoIcons.heart_fill,
                        title: 'Favorites',
                        count: appState.favoriteTracks.length,
                        onTap: () => _navigateToFavorites(context),
                        iconColor: CupertinoColors.systemPink,
                      ),
                      _LibrarySection(
                        icon: CupertinoIcons.arrow_down_circle_fill,
                        title: 'Downloaded',
                        count: appState.downloadService.downloadedTracks.length,
                        onTap: () => _navigateToDownloads(context),
                        iconColor: CupertinoColors.systemGreen,
                      ),
                    ],
                  ),
                ),
              ),

              // Recently played albums
              if (appState.albums.isNotEmpty) ...[
                const SliverSectionHeader(title: 'Recently Played'),
                SliverToBoxAdapter(
                  child: AlbumRow(
                    albums: appState.albums.take(10).toList(),
                    getImageUrl: appState.getImageUrl,
                    onAlbumTap: (album) => _navigateToAlbum(context, album),
                  ),
                ),
              ],

              // Bottom spacing
              const SliverToBoxAdapter(
                child: SizedBox(height: 150),
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToPlaylists(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => const AllPlaylistsScreen(),
      ),
    );
  }

  void _navigateToArtists(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => const AllArtistsScreen(),
      ),
    );
  }

  void _navigateToAlbums(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => const AllAlbumsScreen(),
      ),
    );
  }

  void _navigateToSongs(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => const AllSongsScreen(),
      ),
    );
  }

  void _navigateToFavorites(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => const FavoritesScreen(),
      ),
    );
  }

  void _navigateToDownloads(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => const DownloadsScreen(),
      ),
    );
  }

  void _navigateToAlbum(BuildContext context, Album album) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => DetailScreen.album(album: album),
      ),
    );
  }
}

class _LibrarySection extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final VoidCallback onTap;
  final Color? iconColor;

  const _LibrarySection({
    required this.icon,
    required this.title,
    required this.count,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppTheme.separator(context),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: iconColor ?? AppTheme.accentPink,
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: AppTheme.fontSizeBody,
                  color: AppTheme.textPrimary(context),
                ),
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                fontSize: AppTheme.fontSizeBody,
                color: AppTheme.textSecondary(context),
              ),
            ),
            const SizedBox(width: AppTheme.spacingS),
            Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: AppTheme.textSecondary(context),
            ),
          ],
        ),
      ),
    );
  }
}

class AllPlaylistsScreen extends StatelessWidget {
  const AllPlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return CupertinoPageScaffold(
          backgroundColor: AppTheme.background(context),
          navigationBar: CupertinoNavigationBar(
            middle: const Text('Playlists'),
            backgroundColor: AppTheme.background(context),
            border: null,
          ),
          child: SafeArea(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 150),
              itemCount: appState.playlists.length,
              itemBuilder: (context, index) {
                final playlist = appState.playlists[index];
                return PlaylistTile(
                  playlist: playlist,
                  getImageUrl: appState.getImageUrl,
                  onTap: () => Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => DetailScreen.playlist(playlist: playlist),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final downloadedTracksMap = appState.downloadService.downloadedTracks;
        // Convert downloaded tracks to a list of Track objects
        final downloadedTracks = appState.tracks
            .where((track) => downloadedTracksMap.containsKey(track.id))
            .toList();
        
        return CupertinoPageScaffold(
          backgroundColor: AppTheme.background(context),
          navigationBar: CupertinoNavigationBar(
            middle: const Text('Downloaded'),
            backgroundColor: AppTheme.background(context),
            border: null,
          ),
          child: SafeArea(
            child: downloadedTracks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.arrow_down_circle,
                          size: 64,
                          color: AppTheme.textSecondary(context),
                        ),
                        const SizedBox(height: AppTheme.spacingL),
                        Text(
                          'No Downloads',
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeTitle3,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingS),
                        Text(
                          'Downloaded songs will appear here',
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeBody,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  )
                : CustomScrollView(
                    slivers: [
                      TrackList(
                        tracks: downloadedTracks,
                        currentTrackId: appState.audioHandler?.currentTrack?.id,
                        downloadedTrackIds: downloadedTracksMap.keys.toSet(),
                        getImageUrl: appState.getImageUrl,
                        onTrackTap: (track, index) {
                          appState.audioHandler?.playPlaylist(downloadedTracks, index);
                        },
                        padding: const EdgeInsets.only(bottom: 150),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
