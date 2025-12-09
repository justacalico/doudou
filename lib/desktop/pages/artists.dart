import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../templates/page_template.dart';
import '../../providers/app_state.dart';
import 'details/artist_details.dart';

class ArtistsPage extends StatefulWidget {
  const ArtistsPage({super.key});

  @override
  State<ArtistsPage> createState() => _ArtistsPageState();
}

class _ArtistsPageState extends State<ArtistsPage> {
  String _searchQuery = '';
  String _sortBy = 'name'; // name, albumCount
  bool _isAscending = true;
  String _viewMode = 'grid'; // grid, list
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      if (appState.artists.isEmpty) {
        appState.loadLibraryData();
      }
    });
  }

  String? _getImageUrl(AppState appState, String? imageId) {
    if (imageId == null) return null;
    return appState.getImageUrl(imageId);
  }

  List<dynamic> _getFilteredAndSortedArtists(AppState appState) {
    var artists = List.from(appState.artists);
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      artists = artists.where((artist) {
        return artist.name.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
    
    // Sort artists
    artists.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'name':
          comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case 'albumCount':
          // Get album count for each artist by counting albums
          final aAlbumCount = appState.albums.where((album) => album.artistName == a.name).length;
          final bAlbumCount = appState.albums.where((album) => album.artistName == b.name).length;
          comparison = aAlbumCount.compareTo(bAlbumCount);
          break;
      }
      return _isAscending ? comparison : -comparison;
    });
    
    return artists;
  }

  int _getArtistAlbumCount(AppState appState, String artistName) {
    return appState.albums.where((album) => album.artistName == artistName).length;
  }

  int _getArtistTrackCount(AppState appState, String artistName) {
    return appState.tracks.where((track) => track.artistName == artistName).length;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final filteredArtists = _getFilteredAndSortedArtists(appState);
        
        return PageTemplate(
          title: l10n.artists,
          actions: [
            // Search field
            SizedBox(
              width: 300,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: l10n.searchArtists,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            
            // View toggle buttons
            ToggleButtons(
              isSelected: [_viewMode == 'grid', _viewMode == 'list'],
              onPressed: (index) {
                setState(() {
                  _viewMode = index == 0 ? 'grid' : 'list';
                });
              },
              borderRadius: BorderRadius.circular(8),
              children: [
                Tooltip(
                  message: l10n.gridView,
                  child: const Icon(Icons.grid_view),
                ),
                Tooltip(
                  message: l10n.listView,
                  child: const Icon(Icons.list),
                ),
              ],
            ),
            
            const SizedBox(width: 16),
            
            // Refresh button
            IconButton(
              onPressed: () => appState.loadLibraryData(),
              icon: const Icon(Icons.refresh),
              tooltip: l10n.refreshArtists,
            ),
          ],
          child: Column(
            children: [
              // Filter and sort controls
              _buildFilterSortBar(appState, filteredArtists.length, l10n),
              
              const SizedBox(height: 16),
              
              // Content area
              Expanded(
                child: appState.isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(l10n.loadingArtists),
                          ],
                        ),
                      )
                    : filteredArtists.isEmpty
                        ? _buildEmptyState(l10n)
                        : _viewMode == 'grid'
                            ? _buildArtistsGrid(appState, filteredArtists, l10n)
                            : _buildArtistsList(appState, filteredArtists, l10n),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterSortBar(AppState appState, int filteredCount) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Results count
            Text(
              '$filteredCount artists',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            
            const SizedBox(width: 24),
            
            // Sort dropdown
            Text('Sort by:', style: theme.textTheme.bodyMedium),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _sortBy,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _sortBy = value;
                  });
                }
              },
              items: const [
                DropdownMenuItem(value: 'name', child: Text('Name')),
                DropdownMenuItem(value: 'albumCount', child: Text('Album Count')),
              ],
            ),
            
            const SizedBox(width: 8),
            
            // Sort direction toggle
            IconButton(
              onPressed: () {
                setState(() {
                  _isAscending = !_isAscending;
                });
              },
              icon: Icon(_isAscending ? Icons.arrow_upward : Icons.arrow_downward),
              tooltip: _isAscending ? 'Ascending' : 'Descending',
            ),
            
            const Spacer(),
            
            // Quick action buttons
            TextButton.icon(
              onPressed: filteredCount > 0 ? () {
                // Play all artists
              } : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play All'),
            ),
            
            const SizedBox(width: 8),
            
            TextButton.icon(
              onPressed: filteredCount > 0 ? () {
                // Shuffle all artists
              } : null,
              icon: const Icon(Icons.shuffle),
              label: const Text('Shuffle All'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_outline,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty 
                ? 'No artists found for "$_searchQuery"'
                : 'No artists found',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Your music library appears to be empty',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                });
              },
              child: const Text('Clear Search'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildArtistsGrid(AppState appState, List<dynamic> artists) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6, // 6 artists per row
        childAspectRatio: 0.8, // Slightly taller for artist info
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        return _buildArtistCard(appState, artist);
      },
    );
  }

  Widget _buildArtistsList(AppState appState, List<dynamic> artists) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        return _buildArtistListTile(appState, artist);
      },
    );
  }

  Widget _buildArtistCard(AppState appState, dynamic artist) {
    final theme = Theme.of(context);
    final albumCount = _getArtistAlbumCount(appState, artist.name);
    final trackCount = _getArtistTrackCount(appState, artist.name);
    
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ArtistDetailsPage(artist: artist),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Artist image
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    child: artist.imageUrl != null
                        ? ClipOval(
                            child: Image.network(
                              _getImageUrl(appState, artist.imageUrl)!,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildArtistPlaceholder(theme);
                              },
                            ),
                          )
                        : _buildArtistPlaceholder(theme),
                  ),
                  
                  // Overlay with play button (appears on hover)
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          // Play artist
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.play_circle_filled,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Artist info
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    artist.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$albumCount albums • $trackCount songs',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtistListTile(AppState appState, dynamic artist) {
    final theme = Theme.of(context);
    final albumCount = _getArtistAlbumCount(appState, artist.name);
    final trackCount = _getArtistTrackCount(appState, artist.name);
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant,
            shape: BoxShape.circle,
          ),
          child: artist.imageUrl != null
              ? ClipOval(
                  child: Image.network(
                    _getImageUrl(appState, artist.imageUrl)!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildArtistPlaceholder(theme);
                    },
                  ),
                )
              : _buildArtistPlaceholder(theme),
        ),
        title: Text(
          artist.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '$albumCount albums • $trackCount songs',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () {
                // Play artist
              },
              icon: const Icon(Icons.play_arrow),
              tooltip: 'Play All',
            ),
            IconButton(
              onPressed: () {
                // Shuffle artist
              },
              icon: const Icon(Icons.shuffle),
              tooltip: 'Shuffle',
            ),
            PopupMenuButton<String>(
              onSelected: (value) => _handleArtistAction(value, artist),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'play',
                  child: ListTile(
                    leading: Icon(Icons.play_arrow),
                    title: Text('Play All'),
                    dense: true,
                  ),
                ),
                const PopupMenuItem(
                  value: 'shuffle',
                  child: ListTile(
                    leading: Icon(Icons.shuffle),
                    title: Text('Shuffle'),
                    dense: true,
                  ),
                ),
                const PopupMenuItem(
                  value: 'albums',
                  child: ListTile(
                    leading: Icon(Icons.album),
                    title: Text('View Albums'),
                    dense: true,
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          // Navigate to artist details
        },
      ),
    );
  }

  Widget _buildArtistPlaceholder(ThemeData theme) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person,
        size: 32,
        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
      ),
    );
  }

  void _handleArtistAction(String action, dynamic artist) {
    switch (action) {
      case 'play':
        // Play all songs by this artist
        break;
      case 'shuffle':
        // Shuffle all songs by this artist
        break;
      case 'albums':
        // Navigate to albums by this artist
        break;
    }
  }
}
