import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'album_detail_screen.dart';
import 'artist_detail_screen.dart';
import 'playlist_detail_screen.dart';
import 'all_albums_screen.dart';
import 'all_artists_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Album>? _shuffledRecentAlbums;
  List<Album>? _shuffledMadeForYou;

  void _initializeShuffledLists(List<Album> albums, List<Track> favorites) {
    if (_shuffledRecentAlbums == null) {
      // Recently added - sort by date
      final sortedByDate = List<Album>.from(albums);
      sortedByDate.sort((a, b) {
        if (a.dateCreated != null && b.dateCreated != null) {
          return b.dateCreated!.compareTo(a.dateCreated!);
        }
        if (a.dateCreated != null) return -1;
        if (b.dateCreated != null) return 1;
        return 0;
      });
      _shuffledRecentAlbums = sortedByDate.take(20).toList();

      // Made for you - albums from favorite artists
      final favoriteArtists = favorites
          .where((t) => t.artistName != null)
          .map((t) => t.artistName!)
          .toSet();
      
      final madeForYou = albums
          .where((a) => a.artistName != null && favoriteArtists.contains(a.artistName))
          .toList()
        ..shuffle();
      _shuffledMadeForYou = madeForYou.take(20).toList();
      
      if (_shuffledMadeForYou!.isEmpty) {
        _shuffledMadeForYou = (List<Album>.from(albums)..shuffle()).take(20).toList();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final albums = appState.albums;
        final artists = appState.artists;
        final playlists = appState.playlists;
        final favorites = appState.favoriteTracks;
        
        _initializeShuffledLists(albums, favorites);

        return CupertinoPageScaffold(
          backgroundColor: AppTheme.background(context),
          child: CustomScrollView(
            slivers: [
              // Navigation bar
              CupertinoSliverNavigationBar(
                largeTitle: const Text('Listen Now'),
                backgroundColor: AppTheme.background(context),
                border: null,
              ),

              // Shuffle buttons
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingL),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ShuffleButton(
                          icon: CupertinoIcons.shuffle,
                          label: 'Shuffle All',
                          onTap: () => appState.shuffleAllTracks(),
                          color: AppTheme.accentPink,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingM),
                      Expanded(
                        child: _ShuffleButton(
                          icon: CupertinoIcons.heart_fill,
                          label: 'Favorites',
                          onTap: () {
                            if (favorites.isNotEmpty) {
                              appState.shuffleFavoriteTracks();
                            } else {
                              _showNoFavoritesAlert(context);
                            }
                          },
                          color: CupertinoColors.systemPink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Recently Added
              if (_shuffledRecentAlbums != null && _shuffledRecentAlbums!.isNotEmpty) ...[
                SliverSectionHeader(
                  title: 'Recently Added',
                  onSeeAll: () => _navigateToAllAlbums(context),
                ),
                SliverToBoxAdapter(
                  child: AlbumRow(
                    albums: _shuffledRecentAlbums!,
                    getImageUrl: appState.getImageUrl,
                    onAlbumTap: (album) => _navigateToAlbum(context, album),
                  ),
                ),
              ],

              // Made For You
              if (_shuffledMadeForYou != null && _shuffledMadeForYou!.isNotEmpty) ...[
                SliverSectionHeader(
                  title: 'Made For You',
                  onSeeAll: () => _navigateToAllAlbums(context),
                ),
                SliverToBoxAdapter(
                  child: AlbumRow(
                    albums: _shuffledMadeForYou!,
                    getImageUrl: appState.getImageUrl,
                    onAlbumTap: (album) => _navigateToAlbum(context, album),
                  ),
                ),
              ],

              // Top Artists
              if (artists.isNotEmpty) ...[
                SliverSectionHeader(
                  title: 'Your Artists',
                  onSeeAll: () => _navigateToAllArtists(context),
                ),
                SliverToBoxAdapter(
                  child: ArtistRow(
                    artists: artists.take(15).toList(),
                    getImageUrl: appState.getImageUrl,
                    onArtistTap: (artist) => _navigateToArtist(context, artist),
                  ),
                ),
              ],

              // Playlists
              if (playlists.isNotEmpty) ...[
                const SliverSectionHeader(title: 'Playlists'),
                SliverToBoxAdapter(
                  child: PlaylistRow(
                    playlists: playlists.take(10).toList(),
                    getImageUrl: appState.getImageUrl,
                    onPlaylistTap: (playlist) => _navigateToPlaylist(context, playlist),
                  ),
                ),
              ],

              // Bottom spacing for mini player and tab bar
              const SliverToBoxAdapter(
                child: SizedBox(height: 150),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showNoFavoritesAlert(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('No Favorites'),
        content: const Text('Add some songs to your favorites to shuffle them.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _navigateToAlbum(BuildContext context, Album album) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => AlbumDetailScreen(album: album),
      ),
    );
  }

  void _navigateToArtist(BuildContext context, Artist artist) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => ArtistDetailScreen(artist: artist),
      ),
    );
  }

  void _navigateToPlaylist(BuildContext context, Playlist playlist) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => PlaylistDetailScreen(playlist: playlist),
      ),
    );
  }

  void _navigateToAllAlbums(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => const AllAlbumsScreen(),
      ),
    );
  }

  void _navigateToAllArtists(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => const AllArtistsScreen(),
      ),
    );
  }
}

class _ShuffleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ShuffleButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppTheme.spacingM,
          horizontal: AppTheme.spacingL,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: AppTheme.spacingS),
            Text(
              label,
              style: TextStyle(
                fontSize: AppTheme.fontSizeBody,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
