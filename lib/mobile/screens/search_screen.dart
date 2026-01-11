import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  
  List<Track> _trackResults = [];
  List<Album> _albumResults = [];
  List<Artist> _artistResults = [];
  List<Playlist> _playlistResults = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(String query, AppState appState) {
    if (query.trim().isEmpty) {
      setState(() {
        _query = '';
        _trackResults = [];
        _albumResults = [];
        _artistResults = [];
        _playlistResults = [];
      });
      return;
    }

    final searchTerm = query.toLowerCase();

    setState(() {
      _query = query;
      
      // Search tracks
      _trackResults = appState.tracks.where((track) {
        return track.name.toLowerCase().contains(searchTerm) ||
            (track.artistName?.toLowerCase().contains(searchTerm) ?? false) ||
            (track.albumName?.toLowerCase().contains(searchTerm) ?? false);
      }).take(20).toList();

      // Search albums
      _albumResults = appState.albums.where((album) {
        return album.name.toLowerCase().contains(searchTerm) ||
            (album.artistName?.toLowerCase().contains(searchTerm) ?? false);
      }).take(20).toList();

      // Search artists
      _artistResults = appState.artists.where((artist) {
        return artist.name.toLowerCase().contains(searchTerm);
      }).take(20).toList();

      // Search playlists
      _playlistResults = appState.playlists.where((playlist) {
        return playlist.name.toLowerCase().contains(searchTerm);
      }).take(20).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final hasResults = _trackResults.isNotEmpty ||
            _albumResults.isNotEmpty ||
            _artistResults.isNotEmpty ||
            _playlistResults.isNotEmpty;

        return CupertinoPageScaffold(
          backgroundColor: AppTheme.background(context),
          child: CustomScrollView(
            slivers: [
              // Navigation bar with search field
              CupertinoSliverNavigationBar(
                largeTitle: const Text('Search'),
                backgroundColor: AppTheme.background(context),
                border: null,
              ),

              // Search field
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingL),
                  child: CupertinoSearchTextField(
                    controller: _searchController,
                    placeholder: 'Artists, Songs, Albums',
                    onChanged: (value) => _performSearch(value, appState),
                    onSubmitted: (value) => _performSearch(value, appState),
                  ),
                ),
              ),

              // Results or browse categories
              if (_query.isEmpty)
                ..._buildBrowseCategories(context, appState)
              else if (!hasResults)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.search,
                          size: 64,
                          color: AppTheme.textSecondary(context),
                        ),
                        const SizedBox(height: AppTheme.spacingL),
                        Text(
                          'No Results',
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeTitle3,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingS),
                        Text(
                          'Try a different search',
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeBody,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._buildSearchResults(context, appState),

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

  List<Widget> _buildBrowseCategories(BuildContext context, AppState appState) {
    return [
      const SliverSectionHeader(title: 'Browse'),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
          child: Wrap(
            spacing: AppTheme.spacingM,
            runSpacing: AppTheme.spacingM,
            children: [
              _CategoryChip(
                label: 'All Albums',
                color: CupertinoColors.systemPurple,
                onTap: () => _searchController.text = '',
              ),
              _CategoryChip(
                label: 'All Artists',
                color: CupertinoColors.systemPink,
                onTap: () => _searchController.text = '',
              ),
              _CategoryChip(
                label: 'Playlists',
                color: CupertinoColors.systemGreen,
                onTap: () => _searchController.text = '',
              ),
            ],
          ),
        ),
      ),
      // Random albums to browse
      if (appState.albums.isNotEmpty) ...[
        const SliverSectionHeader(title: 'Explore'),
        SliverToBoxAdapter(
          child: AlbumRow(
            albums: (List<Album>.from(appState.albums)..shuffle()).take(10).toList(),
            getImageUrl: appState.getImageUrl,
            onAlbumTap: (album) => _navigateToAlbum(context, album),
          ),
        ),
      ],
    ];
  }

  List<Widget> _buildSearchResults(BuildContext context, AppState appState) {
    return [
      // Artists
      if (_artistResults.isNotEmpty) ...[
        const SliverSectionHeader(title: 'Artists'),
        SliverToBoxAdapter(
          child: ArtistRow(
            artists: _artistResults,
            getImageUrl: appState.getImageUrl,
            onArtistTap: (artist) => _navigateToArtist(context, artist),
          ),
        ),
      ],

      // Albums
      if (_albumResults.isNotEmpty) ...[
        const SliverSectionHeader(title: 'Albums'),
        SliverToBoxAdapter(
          child: AlbumRow(
            albums: _albumResults,
            getImageUrl: appState.getImageUrl,
            onAlbumTap: (album) => _navigateToAlbum(context, album),
          ),
        ),
      ],

      // Playlists
      if (_playlistResults.isNotEmpty) ...[
        const SliverSectionHeader(title: 'Playlists'),
        SliverToBoxAdapter(
          child: PlaylistRow(
            playlists: _playlistResults,
            getImageUrl: appState.getImageUrl,
            onPlaylistTap: (playlist) => _navigateToPlaylist(context, playlist),
          ),
        ),
      ],

      // Songs
      if (_trackResults.isNotEmpty) ...[
        const SliverSectionHeader(title: 'Songs'),
        TrackList(
          tracks: _trackResults,
          currentTrackId: appState.audioHandler?.currentTrack?.id,
          getImageUrl: appState.getImageUrl,
          onTrackTap: (track, index) {
            appState.audioHandler?.playPlaylist(_trackResults, index);
          },
        ),
      ],
    ];
  }

  void _navigateToAlbum(BuildContext context, Album album) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => DetailScreen.album(album: album),
      ),
    );
  }

  void _navigateToArtist(BuildContext context, Artist artist) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => DetailScreen.artist(artist: artist),
      ),
    );
  }

  void _navigateToPlaylist(BuildContext context, Playlist playlist) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => DetailScreen.playlist(playlist: playlist),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingL,
          vertical: AppTheme.spacingM,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppTheme.fontSizeFootnote,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}
