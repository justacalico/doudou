import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
import '../partials/tracks/track_list_item.dart';
import '../artists/details/artist_detail.dart';
import '../albums/details/album_details.dart';
import '../playlists/playlists.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  // Search results by category
  List<Track> _trackResults = [];
  List<Album> _albumResults = [];
  List<Artist> _artistResults = [];
  List<Playlist> _playlistResults = [];
  
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(String query, AppState appState) async {
    if (query.trim().isEmpty) {
      setState(() {
        _trackResults = [];
        _albumResults = [];
        _artistResults = [];
        _playlistResults = [];
        _isSearching = false;
        _searchQuery = '';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchQuery = query;
    });

    try {
      final searchTerm = query.toLowerCase();
      
      // Search tracks
      final trackResults = appState.tracks.where((track) {
        final trackName = track.name.toLowerCase();
        final artistName = track.artistName?.toLowerCase() ?? '';
        final albumName = track.albumName?.toLowerCase() ?? '';
        
        return trackName.contains(searchTerm) ||
               artistName.contains(searchTerm) ||
               albumName.contains(searchTerm);
      }).toList();

      // Search albums
      final albumResults = appState.albums.where((album) {
        final albumName = album.name.toLowerCase();
        final artistName = album.artistName?.toLowerCase() ?? '';
        
        return albumName.contains(searchTerm) ||
               artistName.contains(searchTerm);
      }).toList();

      // Search artists
      final artistResults = appState.artists.where((artist) {
        final artistName = artist.name.toLowerCase();
        
        return artistName.contains(searchTerm);
      }).toList();

      // Search playlists
      final playlistResults = appState.playlists.where((playlist) {
        final playlistName = playlist.name.toLowerCase();
        
        return playlistName.contains(searchTerm);
      }).toList();

      setState(() {
        _trackResults = trackResults;
        _albumResults = albumResults;
        _artistResults = artistResults;
        _playlistResults = playlistResults;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _trackResults = [];
        _albumResults = [];
        _artistResults = [];
        _playlistResults = [];
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return CupertinoPageScaffold(
          backgroundColor: const Color(0xFF000000), // Pure black for OLED
          resizeToAvoidBottomInset: true,
          child: SafeArea(
            child: Column(
              children: [
                // Search Header
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Search',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFFFFFF),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Search Bar
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF000000),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF2C2C2E),
                            width: 1,
                          ),
                        ),
                        child: CupertinoSearchTextField(
                          controller: _searchController,
                          placeholder: 'Artists, albums, songs, or playlists',
                          style: const TextStyle(color: Color(0xFFFFFFFF)),
                          placeholderStyle: const TextStyle(color: CupertinoColors.systemGrey2),
                          backgroundColor: const Color(0x00000000),
                          onChanged: (value) => _performSearch(value, appState),
                          onSubmitted: (value) => _performSearch(value, appState),
                          autofocus: false,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Search Results
                Expanded(
                  child: _buildSearchContent(appState),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchContent(AppState appState) {
    if (_searchQuery.isEmpty) {
      return _buildSearchSuggestions(appState);
    }

    if (_isSearching) {
      return const Center(
        child: CupertinoActivityIndicator(
          color: Color(0xFFFFFFFF),
        ),
      );
    }

    // Check if we have any results
    final hasResults = _trackResults.isNotEmpty || 
                       _albumResults.isNotEmpty || 
                       _artistResults.isNotEmpty || 
                       _playlistResults.isNotEmpty;

    if (!hasResults) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.search,
              size: 64,
              color: CupertinoColors.systemGrey2,
            ),
            const SizedBox(height: 16),
            Text(
              'No results for "$_searchQuery"',
              style: const TextStyle(
                fontSize: 18,
                color: CupertinoColors.systemGrey2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try searching for something else',
              style: TextStyle(
                fontSize: 14,
                color: CupertinoColors.systemGrey2,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Top Results Section (show best matches first)
        if (_trackResults.isNotEmpty || _albumResults.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Top Results',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFFFFFF),
            ),
          ),
          const SizedBox(height: 12),
          
          // Show first track result if available
          if (_trackResults.isNotEmpty)
            _buildTopResultTrack(_trackResults.first, appState),
          
          // Show first album result if available
          if (_albumResults.isNotEmpty)
            _buildTopResultAlbum(_albumResults.first, appState),
        ],
        
        // Artists Section
        if (_artistResults.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Artists (${_artistResults.length})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFFFFFF),
            ),
          ),
          const SizedBox(height: 12),
          ..._artistResults.take(5).map((artist) => _buildArtistResultItem(artist, appState)),
          if (_artistResults.length > 5)
            _buildShowMoreButton('artists', _artistResults.length - 5),
        ],
        
        // Albums Section
        if (_albumResults.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Albums (${_albumResults.length})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFFFFFF),
            ),
          ),
          const SizedBox(height: 12),
          ..._albumResults.take(5).map((album) => _buildAlbumResultItem(album, appState)),
          if (_albumResults.length > 5)
            _buildShowMoreButton('albums', _albumResults.length - 5),
        ],
        
        // Playlists Section
        if (_playlistResults.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Playlists (${_playlistResults.length})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFFFFFF),
            ),
          ),
          const SizedBox(height: 12),
          ..._playlistResults.take(5).map((playlist) => _buildPlaylistResultItem(playlist, appState)),
          if (_playlistResults.length > 5)
            _buildShowMoreButton('playlists', _playlistResults.length - 5),
        ],
        
        // Songs Section
        if (_trackResults.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Songs (${_trackResults.length})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFFFFFF),
            ),
          ),
          const SizedBox(height: 12),
          ..._trackResults.take(10).map((track) => TrackListItem(
            track: track,
            onTap: () => appState.playTrack(track),
          )),
          if (_trackResults.length > 10)
            _buildShowMoreButton('songs', _trackResults.length - 10),
        ],
        
        const SizedBox(height: 150), // Bottom padding for mini player + nav bar
      ],
    );
  }

  Widget _buildSearchSuggestions(AppState appState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Browse',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFFFFFF),
            ),
          ),
          const SizedBox(height: 16),
          
          // Browse Categories
          _buildBrowseCategory(
            icon: CupertinoIcons.music_note_2,
            title: 'Recently Played',
            subtitle: 'Your recent tracks',
            color: const Color(0xFF007AFF),
            onTap: () {
              _showRecentlyPlayed(context, appState);
            },
          ),
          _buildBrowseCategory(
            icon: CupertinoIcons.heart_fill,
            title: 'Liked Songs',
            subtitle: 'Your favorite tracks',
            color: const Color(0xFFFF453A),
            onTap: () {
              _showFavorites(context, appState);
            },
          ),
          _buildBrowseCategory(
            icon: CupertinoIcons.music_albums,
            title: 'Albums',
            subtitle: 'Browse all albums',
            color: const Color(0xFF30D158),
            onTap: () {
              _showAlbums(context, appState);
            },
          ),
          _buildBrowseCategory(
            icon: CupertinoIcons.person_2,
            title: 'Artists',
            subtitle: 'Browse all artists',
            color: const Color(0xFFFF9F0A),
            onTap: () {
              _showArtists(context, appState);
            },
          ),
          _buildBrowseCategory(
            icon: CupertinoIcons.music_note_list,
            title: 'Playlists',
            subtitle: 'Browse all playlists',
            color: const Color(0xFFAF52DE),
            onTap: () {
              _showPlaylists(context, appState);
            },
          ),
          // Add bottom padding for keyboard space
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildBrowseCategory({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF000000),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF2C2C2E),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFFFFFFFF),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFFFFF),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.systemGrey2,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_right,
                color: CupertinoColors.systemGrey2,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRecentlyPlayed(BuildContext context, AppState appState) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Recently Played'),
        message: const Text('Your most recent tracks'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              // For now, just show a placeholder message
              showCupertinoDialog(
                context: context,
                builder: (context) => CupertinoAlertDialog(
                  title: const Text('Recently Played'),
                  content: const Text('This feature will show your recently played tracks. For now, you can use the search to find tracks.'),
                  actions: [
                    CupertinoDialogAction(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.clock, color: CupertinoColors.activeBlue),
                SizedBox(width: 8),
                Text('View Recent Tracks'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showFavorites(BuildContext context, AppState appState) {
    final favoritesTracks = appState.tracks.where((track) => track.isFavorite).toList();
    
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Color(0xFF000000),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Liked Songs',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFFFFF),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    child: const Icon(
                      CupertinoIcons.xmark,
                      color: CupertinoColors.systemGrey2,
                    ),
                  ),
                ],
              ),
            ),
            // Favorites List
            Expanded(
              child: favoritesTracks.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.heart,
                            size: 64,
                            color: CupertinoColors.systemGrey2,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No liked songs yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: CupertinoColors.systemGrey2,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Like songs by tapping the heart icon',
                            style: TextStyle(
                              fontSize: 14,
                              color: CupertinoColors.systemGrey2,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: favoritesTracks.length,
                      itemBuilder: (context, index) {
                        final track = favoritesTracks[index];
                        return TrackListItem(
                          track: track,
                          onTap: () => appState.playTrack(track),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAlbums(BuildContext context, AppState appState) {
    final albums = appState.albums;
    
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Color(0xFF000000),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Albums',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFFFFF),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    child: const Icon(
                      CupertinoIcons.xmark,
                      color: CupertinoColors.systemGrey2,
                    ),
                  ),
                ],
              ),
            ),
            // Albums Grid
            Expanded(
              child: albums.isEmpty
                  ? const Center(
                      child: Text(
                        'No albums found',
                        style: TextStyle(
                          fontSize: 18,
                          color: CupertinoColors.systemGrey2,
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: albums.length,
                      itemBuilder: (context, index) {
                        final album = albums[index];
                        return _buildAlbumTile(album, appState);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showArtists(BuildContext context, AppState appState) {
    final artists = appState.artists;
    
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Color(0xFF000000),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Artists',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFFFFF),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    child: const Icon(
                      CupertinoIcons.xmark,
                      color: CupertinoColors.systemGrey2,
                    ),
                  ),
                ],
              ),
            ),
            // Artists List
            Expanded(
              child: artists.isEmpty
                  ? const Center(
                      child: Text(
                        'No artists found',
                        style: TextStyle(
                          fontSize: 18,
                          color: CupertinoColors.systemGrey2,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: artists.length,
                      itemBuilder: (context, index) {
                        final artist = artists[index];
                        return _buildArtistTile(artist, appState);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlaylists(BuildContext context, AppState appState) {
    final playlists = appState.playlists;
    
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Color(0xFF000000),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Playlists',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFFFFF),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    child: const Icon(
                      CupertinoIcons.xmark,
                      color: CupertinoColors.systemGrey2,
                    ),
                  ),
                ],
              ),
            ),
            // Playlists List
            Expanded(
              child: playlists.isEmpty
                  ? const Center(
                      child: Text(
                        'No playlists found',
                        style: TextStyle(
                          fontSize: 18,
                          color: CupertinoColors.systemGrey2,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: playlists.length,
                      itemBuilder: (context, index) {
                        final playlist = playlists[index];
                        return _buildPlaylistTile(playlist, appState);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumTile(Album album, AppState appState) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => AlbumDetailScreen(album: album),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF000000),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF2C2C2E),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Album Art
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF000000),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    border: Border.all(
                      color: const Color(0xFF2C2C2E),
                      width: 1,
                    ),
                  ),
                  child: album.imageUrl != null
                      ? Image.network(
                          appState.jellyfinService.getImageUrl(
                            album.imageUrl!,
                            width: 200,
                            height: 200,
                          ),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              CupertinoIcons.music_albums,
                              color: CupertinoColors.systemGrey2,
                              size: 40,
                            );
                          },
                        )
                      : const Icon(
                          CupertinoIcons.music_albums,
                          color: CupertinoColors.systemGrey2,
                          size: 40,
                        ),
                ),
              ),
            ),
            // Album Info
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFFFFFF),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    album.artistName ?? 'Unknown Artist',
                    style: const TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey2,
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
    );
  }

  Widget _buildPlaylistTile(Playlist playlist, AppState appState) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => PlaylistDetailScreen(playlist: playlist),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF000000),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF2C2C2E),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Playlist Image
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: playlist.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          appState.jellyfinService.getImageUrl(
                            playlist.imageUrl!,
                            width: 100,
                            height: 100,
                          ),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              CupertinoIcons.music_note_list,
                              color: CupertinoColors.systemGrey2,
                              size: 20,
                            );
                          },
                        ),
                      )
                    : const Icon(
                        CupertinoIcons.music_note_list,
                        color: CupertinoColors.systemGrey2,
                        size: 20,
                      ),
              ),
              const SizedBox(width: 12),
              // Playlist Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFFFFF),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${playlist.trackCount} songs',
                      style: const TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.systemGrey2,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_right,
                color: CupertinoColors.systemGrey2,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArtistTile(Artist artist, AppState appState) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => ArtistDetailScreen(artist: artist),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF000000),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF2C2C2E),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Artist Image
              ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF000000),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: const Color(0xFF2C2C2E),
                      width: 1,
                    ),
                  ),
                  child: artist.imageUrl != null
                      ? Image.network(
                          appState.jellyfinService.getImageUrl(
                            artist.imageUrl!,
                            width: 100,
                            height: 100,
                          ),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              CupertinoIcons.person,
                              color: CupertinoColors.systemGrey2,
                              size: 20,
                            );
                          },
                        )
                      : const Icon(
                          CupertinoIcons.person,
                          color: CupertinoColors.systemGrey2,
                          size: 20,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Artist Info
              Expanded(
                child: Text(
                  artist.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFFFFFF),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              const Icon(
                CupertinoIcons.chevron_right,
                color: CupertinoColors.systemGrey2,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Top result widgets for featured display
  Widget _buildTopResultTrack(Track track, AppState appState) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2C2C2E),
          width: 1,
        ),
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => appState.playTrack(track),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                CupertinoIcons.music_note,
                color: Color(0xFFFFFFFF),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFFFFFF),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Song • ${track.artistName ?? 'Unknown Artist'}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.systemGrey2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.play_fill,
              color: Color(0xFF007AFF),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopResultAlbum(Album album, AppState appState) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2C2C2E),
          width: 1,
        ),
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => AlbumDetailScreen(album: album),
            ),
          );
        },
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF30D158),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                CupertinoIcons.music_albums,
                color: Color(0xFFFFFFFF),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFFFFFF),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Album • ${album.artistName ?? 'Unknown Artist'}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.systemGrey2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              color: CupertinoColors.systemGrey2,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtistResultItem(Artist artist, AppState appState) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => ArtistDetailScreen(artist: artist),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF000000),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF2C2C2E),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: artist.imageUrl != null
                      ? Image.network(
                          appState.jellyfinService.getImageUrl(
                            artist.imageUrl!,
                            width: 100,
                            height: 100,
                          ),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              CupertinoIcons.person,
                              color: CupertinoColors.systemGrey2,
                              size: 20,
                            );
                          },
                        )
                      : const Icon(
                          CupertinoIcons.person,
                          color: CupertinoColors.systemGrey2,
                          size: 20,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      artist.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFFFFF),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Artist',
                      style: TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.systemGrey2,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_right,
                color: CupertinoColors.systemGrey2,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumResultItem(Album album, AppState appState) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => AlbumDetailScreen(album: album),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF000000),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF2C2C2E),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: album.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          appState.jellyfinService.getImageUrl(
                            album.imageUrl!,
                            width: 100,
                            height: 100,
                          ),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              CupertinoIcons.music_albums,
                              color: CupertinoColors.systemGrey2,
                              size: 20,
                            );
                          },
                        ),
                      )
                    : const Icon(
                        CupertinoIcons.music_albums,
                        color: CupertinoColors.systemGrey2,
                        size: 20,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFFFFF),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Album • ${album.artistName ?? 'Unknown Artist'}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.systemGrey2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_right,
                color: CupertinoColors.systemGrey2,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistResultItem(Playlist playlist, AppState appState) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => PlaylistDetailScreen(playlist: playlist),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF000000),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF2C2C2E),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: playlist.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          appState.jellyfinService.getImageUrl(
                            playlist.imageUrl!,
                            width: 100,
                            height: 100,
                          ),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              CupertinoIcons.music_note_list,
                              color: CupertinoColors.systemGrey2,
                              size: 20,
                            );
                          },
                        ),
                      )
                    : const Icon(
                        CupertinoIcons.music_note_list,
                        color: CupertinoColors.systemGrey2,
                        size: 20,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFFFFF),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Playlist • ${playlist.trackCount} songs',
                      style: const TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.systemGrey2,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_right,
                color: CupertinoColors.systemGrey2,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShowMoreButton(String category, int remainingCount) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          _showAllResults(category);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF2C2C2E),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Show $remainingCount more $category',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF007AFF),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                CupertinoIcons.chevron_down,
                color: Color(0xFF007AFF),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAllResults(String category) {
    List<Widget> items = [];
    String title = '';
    
    switch (category) {
      case 'artists':
        title = 'All Artists (${_artistResults.length})';
        items = _artistResults.map((artist) => _buildArtistResultItem(artist, context.read<AppState>())).toList();
        break;
      case 'albums':
        title = 'All Albums (${_albumResults.length})';
        items = _albumResults.map((album) => _buildAlbumResultItem(album, context.read<AppState>())).toList();
        break;
      case 'playlists':
        title = 'All Playlists (${_playlistResults.length})';
        items = _playlistResults.map((playlist) => _buildPlaylistResultItem(playlist, context.read<AppState>())).toList();
        break;
      case 'songs':
        title = 'All Songs (${_trackResults.length})';
        items = _trackResults.map((track) => TrackListItem(
          track: track,
          onTap: () => context.read<AppState>().playTrack(track),
        )).toList();
        break;
    }

    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Color(0xFF000000),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFFFFF),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    child: const Icon(
                      CupertinoIcons.xmark,
                      color: CupertinoColors.systemGrey2,
                    ),
                  ),
                ],
              ),
            ),
            // Results List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: items,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
