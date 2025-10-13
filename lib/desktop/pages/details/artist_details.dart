import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../templates/desktop_layout.dart';
import '../../../providers/app_state.dart';
import '../../../models/jellyfin_models.dart';
import 'album_details.dart';

class ArtistDetailsPage extends StatefulWidget {
  final Artist artist;

  const ArtistDetailsPage({
    super.key,
    required this.artist,
  });

  @override
  State<ArtistDetailsPage> createState() => _ArtistDetailsPageState();
}

class _ArtistDetailsPageState extends State<ArtistDetailsPage> {
  List<Album> _artistAlbums = [];
  List<Track> _popularTracks = [];
  bool _isLoading = true;
  String _selectedTab = 'albums'; // albums, songs

  @override
  void initState() {
    super.initState();
    _loadArtistData();
  }

  void _loadArtistData() async {
    final appState = context.read<AppState>();
    setState(() {
      _isLoading = true;
    });

    try {
      // Get albums by this artist
      _artistAlbums = appState.albums
          .where((album) => album.artistName == widget.artist.name)
          .toList();
      
      // Sort albums by year (newest first)
      _artistAlbums.sort((a, b) {
        final aYear = a.year ?? 0;
        final bYear = b.year ?? 0;
        return bYear.compareTo(aYear);
      });

      // Get popular tracks by this artist
      _popularTracks = appState.tracks
          .where((track) => track.artistName == widget.artist.name)
          .take(10)
          .toList();
    } catch (e) {
      // Handle error
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String? _getImageUrl(AppState appState, String? imageId) {
    if (imageId == null) return null;
    return appState.getImageUrl(imageId);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final theme = Theme.of(context);
        
        return DesktopLayout(
          showBackButton: true,
          title: widget.artist.name,
          selectedIndex: 5, // Artists page index
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Action buttons row
                _buildActionButtons(theme),
                
                const SizedBox(height: 24),
                
                // Artist header
                _buildArtistHeader(theme, appState),
                
                const SizedBox(height: 32),
                
                // Tab selector
                _buildTabSelector(theme),
                
                const SizedBox(height: 16),
                
                // Content based on selected tab
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildTabContent(theme, appState),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Row(
          children: [
            // Play all button
            ElevatedButton.icon(
              onPressed: _popularTracks.isNotEmpty ? () async {
                await appState.playPlaylist(_popularTracks, 0);
              } : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play All'),
            ),
            const SizedBox(width: 8),
            // Shuffle button
            OutlinedButton.icon(
              onPressed: _popularTracks.isNotEmpty ? () async {
                final shuffledTracks = List<Track>.from(_popularTracks)..shuffle();
                await appState.playPlaylist(shuffledTracks, 0);
              } : null,
              icon: const Icon(Icons.shuffle),
              label: const Text('Shuffle'),
            ),
            const SizedBox(width: 8),
            // Favorite button
            IconButton(
              onPressed: () {
                // Toggle favorite artist
              },
              icon: const Icon(Icons.favorite_border),
              tooltip: 'Add to favorites',
            ),
            // More options
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'follow':
                    // Follow/unfollow artist
                    break;
                  case 'share':
                    // Share artist
                    break;
                  case 'radio':
                    // Start artist radio
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'follow',
                  child: ListTile(
                    leading: Icon(Icons.person_add),
                    title: Text('Follow Artist'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'radio',
                  child: ListTile(
                    leading: Icon(Icons.radio),
                    title: Text('Start Radio'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'share',
                  child: ListTile(
                    leading: Icon(Icons.share),
                    title: Text('Share'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildArtistHeader(ThemeData theme, AppState appState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            // Artist image
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: widget.artist.imageUrl != null
                  ? ClipOval(
                      child: Image.network(
                        _getImageUrl(appState, widget.artist.imageUrl)!,
                        width: 200,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.person,
                            size: 80,
                            color: theme.colorScheme.onSurfaceVariant,
                          );
                        },
                      ),
                    )
                  : Icon(
                      Icons.person,
                      size: 80,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
            ),
            
            const SizedBox(width: 32),
            
            // Artist info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Artist',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.artist.name,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        '${_artistAlbums.length} albums',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '${_getTotalTracks()} songs',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            _buildTabButton('albums', 'Albums', theme),
            const SizedBox(width: 8),
            _buildTabButton('songs', 'Popular Songs', theme),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String tabId, String title, ThemeData theme) {
    final isSelected = _selectedTab == tabId;
    
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedTab = tabId;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primaryContainer : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(ThemeData theme, AppState appState) {
    switch (_selectedTab) {
      case 'albums':
        return _buildAlbumsTab(theme, appState);
      case 'songs':
        return _buildSongsTab(theme, appState);
      default:
        return _buildAlbumsTab(theme, appState);
    }
  }

  Widget _buildAlbumsTab(ThemeData theme, AppState appState) {
    if (_artistAlbums.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.album_outlined,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'No albums found',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'This artist doesn\'t have any albums yet',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.75,
          ),
          itemCount: _artistAlbums.length,
          itemBuilder: (context, index) {
            final album = _artistAlbums[index];
            return _buildAlbumCard(theme, appState, album);
          },
        ),
      ),
    );
  }

  Widget _buildAlbumCard(ThemeData theme, AppState appState, Album album) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AlbumDetailsPage(album: album),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Album artwork
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: album.imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _getImageUrl(appState, album.imageUrl)!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.album,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant,
                          );
                        },
                      ),
                    )
                  : Icon(
                      Icons.album,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Album name
          Text(
            album.name,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          
          // Release year
          if (album.year != null)
            Text(
              album.year.toString(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSongsTab(ThemeData theme, AppState appState) {
    if (_popularTracks.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.music_note_outlined,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'No songs found',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'This artist doesn\'t have any songs yet',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Popular Songs',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    // Show all songs
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Song list
          Expanded(
            child: ListView.builder(
              itemCount: _popularTracks.length,
              itemBuilder: (context, index) {
                final track = _popularTracks[index];
                return _buildTrackItem(theme, appState, track, index + 1);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackItem(ThemeData theme, AppState appState, Track track, int index) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: SizedBox(
        width: 40,
        child: Text(
          index.toString(),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
      title: Row(
        children: [
          // Track artwork
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(4),
            ),
            child: track.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      _getImageUrl(appState, track.imageUrl)!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.music_note,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        );
                      },
                    ),
                  )
                : Icon(
                    Icons.music_note,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
          ),
          
          // Track info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (track.albumName != null)
                  Text(
                    track.albumName!,
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (track.duration != null)
            Text(
              _formatDuration(track.duration!),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              // Play track
            },
            icon: const Icon(Icons.play_arrow),
            iconSize: 20,
          ),
        ],
      ),
      onTap: () {
        // Play track
      },
    );
  }

  int _getTotalTracks() {
    return _popularTracks.length;
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
