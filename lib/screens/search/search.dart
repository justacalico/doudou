import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
import '../../widgets/track_list_item.dart';
import '../artists/details/artist_detail.dart';
import '../albums/details/album_details.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Track> _searchResults = [];
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
        _searchResults = [];
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
      // Search through all tracks for matches
      final allTracks = appState.tracks;
      final results = allTracks.where((track) {
        final trackName = track.name.toLowerCase();
        final artistName = track.artistName?.toLowerCase() ?? '';
        final albumName = track.albumName?.toLowerCase() ?? '';
        final searchTerm = query.toLowerCase();
        
        return trackName.contains(searchTerm) ||
               artistName.contains(searchTerm) ||
               albumName.contains(searchTerm);
      }).toList();

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
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
                          placeholder: 'Songs, artists, or albums',
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

    if (_searchResults.isEmpty) {
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

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final track = _searchResults[index];
        return TrackListItem(
          track: track,
          onTap: () => appState.playTrack(track),
        );
      },
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

  Widget _buildTrackTile(Track track, AppState appState) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () async {
          // Play the track
          await appState.playTrack(track);
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
              // Album Art
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF000000),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF2C2C2E),
                      width: 1,
                    ),
                  ),
                  child: track.imageUrl != null
                      ? Image.network(
                          appState.jellyfinService.getImageUrl(
                            track.imageUrl!,
                            width: 100,
                            height: 100,
                          ),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              CupertinoIcons.music_note,
                              color: CupertinoColors.systemGrey2,
                              size: 20,
                            );
                          },
                        )
                      : const Icon(
                          CupertinoIcons.music_note,
                          color: CupertinoColors.systemGrey2,
                          size: 20,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Track Info
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
                      '${track.artistName ?? "Unknown Artist"}${track.albumName != null ? " • ${track.albumName}" : ""}',
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
              
              // More Options
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  _showTrackOptions(context, track, appState);
                },
                child: const Icon(
                  CupertinoIcons.ellipsis,
                  color: CupertinoColors.systemGrey2,
                  size: 20,
                ),
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
                        return _buildTrackTile(track, appState);
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

  void _showTrackOptions(BuildContext context, Track track, AppState appState) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(
          track.name,
          style: const TextStyle(fontSize: 16),
        ),
        message: Text(
          track.artistName ?? 'Unknown Artist',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _showAddToPlaylistDialog(context, track, appState);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.add_circled, color: CupertinoColors.activeBlue),
                SizedBox(width: 8),
                Text('Add to Playlist'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              appState.toggleFavorite(track);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  track.isFavorite ? CupertinoIcons.heart_slash : CupertinoIcons.heart,
                  color: CupertinoColors.systemRed,
                ),
                const SizedBox(width: 8),
                Text(track.isFavorite ? 'Remove from Favorites' : 'Add to Favorites'),
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

  void _showAddToPlaylistDialog(BuildContext context, Track track, AppState appState) {
    final playlists = appState.playlists;
    
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Add to Playlist'),
        message: Text('Select a playlist to add "${track.name}" to:'),
        actions: [
          // Show existing playlists
          ...playlists.map((playlist) => CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(context);
              final success = await appState.addToPlaylist(playlist.id, track.id);
              if (context.mounted) {
                showCupertinoDialog(
                  context: context,
                  builder: (context) => CupertinoAlertDialog(
                    title: Text(success ? 'Success' : 'Error'),
                    content: Text(success 
                        ? 'Added "${track.name}" to "${playlist.name}"'
                        : 'Failed to add "${track.name}" to "${playlist.name}"'),
                    actions: [
                      CupertinoDialogAction(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.music_note_list, color: CupertinoColors.activeBlue),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    playlist.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )),
          // Create new playlist option
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _createNewPlaylist(context, track, appState);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.add_circled, color: CupertinoColors.activeBlue),
                SizedBox(width: 8),
                Text('Create New Playlist'),
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

  void _createNewPlaylist(BuildContext context, Track track, AppState appState) {
    final TextEditingController controller = TextEditingController();
    
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('New Playlist'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter a name for your new playlist:'),
            const SizedBox(height: 16),
            CupertinoTextField(
              controller: controller,
              placeholder: 'Playlist name',
              autofocus: true,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context);
                final success = await appState.createPlaylist(controller.text.trim());
                if (success && context.mounted) {
                  final newPlaylist = appState.playlists.firstWhere(
                    (p) => p.name == controller.text.trim(),
                  );
                  final addSuccess = await appState.addToPlaylist(newPlaylist.id, track.id);
                  if (context.mounted) {
                    showCupertinoDialog(
                      context: context,
                      builder: (context) => CupertinoAlertDialog(
                        title: Text(addSuccess ? 'Success' : 'Partial Success'),
                        content: Text(addSuccess 
                            ? 'Created playlist "${controller.text.trim()}" and added "${track.name}" to it.'
                            : 'Created playlist "${controller.text.trim()}" but failed to add the song.'),
                        actions: [
                          CupertinoDialogAction(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
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
}
